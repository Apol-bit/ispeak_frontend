"""Real-audio, staged HTTP benchmark. Run with the Python V2 virtual environment.

Requires installed httpx, psutil, librosa and torch. No fake inference, retries,
transcripts, bearer tokens or recording contents are written to the report.
"""
import argparse
import asyncio
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import time

import httpx
import psutil


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    return round(ordered[round((len(ordered) - 1) * fraction)], 3)


async def run(args):
    import librosa
    import torch
    recordings = []
    for filename in args.audio:
        path = Path(filename).resolve(strict=True)
        signal, rate = librosa.load(path, sr=None, mono=True)
        duration = len(signal) / rate
        if duration < 1:
            raise ValueError('Use representative speech recordings of at least one second')
        recordings.append((path, path.read_bytes(), {
            'name': path.name, 'bytes': path.stat().st_size,
            'duration_seconds': duration,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        }))
    levels = [int(value) for value in args.levels.split(',')]
    if not levels or any(value < 1 or value > 100 for value in levels):
        raise ValueError('Concurrency levels must be between 1 and 100')
    tokens = json.loads(Path(args.tokens_file).read_text()) if args.tokens_file else []
    if args.node_url and (len(tokens) < max(levels) or len(set(tokens)) != len(tokens)):
        raise ValueError('Node mode needs at least one distinct user token per concurrent participant')
    target = args.node_url or args.python_url
    report = {
        'started_utc': datetime.now(timezone.utc).isoformat(),
        'mode': 'node-mongo-python' if args.node_url else 'python-only',
        'target': target, 'levels': levels, 'language': args.language,
        'recordings': [entry[2] for entry in recordings],
        'host': {'platform': platform.platform(), 'logical_cpus': psutil.cpu_count(),
                 'ram_bytes': psutil.virtual_memory().total,
                 'cuda_available': torch.cuda.is_available(),
                 'gpu_names': [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())]},
        'method': 'One unmeasured warmup, then one burst of N real requests per stage; no automatic retries. Drain before next stage.',
        'stages': [],
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    def save():
        output.write_text(json.dumps(report, indent=2), encoding='utf-8')

    async with httpx.AsyncClient(timeout=args.timeout, limits=httpx.Limits(max_connections=120, max_keepalive_connections=120), trust_env=False) as client:
        ready = await client.get(args.python_url + '/ready', timeout=10)
        ready.raise_for_status()
        report['readiness'] = ready.json()
        processes = {}
        metrics = (await client.get(args.python_url + '/metrics')).json()
        python_pid = args.python_pid or metrics.get('pid')
        if python_pid:
            processes['python'] = psutil.Process(python_pid)
        if args.node_pid:
            processes['node'] = psutil.Process(args.node_pid)
        for process in processes.values():
            process.cpu_percent()
        psutil.cpu_percent()

        async def submit(index):
            path, content, _ = recordings[index % len(recordings)]
            started = time.perf_counter()
            try:
                token = tokens[index % len(tokens)] if args.node_url else None
                response = await client.post(
                    target + ('/upload-audio' if args.node_url else '/transcribe'),
                    headers={'Authorization': f'Bearer {token}'} if token else {},
                    data={'language': args.language},
                    files={'audio' if args.node_url else 'file': (path.name, content)},
                )
                body = response.json()
                valid = response.status_code == 200 and (
                    body.get('analysisValid') is True if args.node_url else body.get('analysis_valid') is True
                )
                return {
                    'status': response.status_code, 'successful_analysis': valid,
                    'latency_ms': round((time.perf_counter() - started) * 1000, 3),
                    'queue_wait_ms': float(response.headers['x-analysis-queue-wait-ms']) if 'x-analysis-queue-wait-ms' in response.headers else None,
                    'processing_ms': float(response.headers['x-analysis-processing-ms']) if 'x-analysis-processing-ms' in response.headers else None,
                    'retry_after': response.headers.get('retry-after'),
                }
            except (httpx.HTTPError, ValueError) as exc:
                return {'status': 'client_timeout' if isinstance(exc, httpx.TimeoutException) else 'client_error',
                        'successful_analysis': False, 'latency_ms': round((time.perf_counter() - started) * 1000, 3),
                        'error_type': type(exc).__name__, 'queue_wait_ms': None}

        async def drain():
            deadline = time.monotonic() + args.timeout
            while True:
                current = (await client.get(args.python_url + '/metrics', timeout=10)).json()
                if current['admitted'] == 0:
                    return current
                if time.monotonic() > deadline:
                    raise TimeoutError('Python did not drain; stop rather than overlap stages')
                await asyncio.sleep(.5)

        report['warmup'] = await submit(0)
        save()
        if not report['warmup']['successful_analysis']:
            raise RuntimeError('Real-audio warmup failed; see report, do not measure failed setup as capacity')
        await drain()
        for concurrency in levels:
            before = await drain()
            samples = []
            done = asyncio.Event()

            async def sample():
                while not done.is_set():
                    sample_row = {'elapsed_seconds': round(time.perf_counter() - started, 3),
                                  'host_cpu_percent': psutil.cpu_percent(),
                                  'host_ram_used_bytes': psutil.virtual_memory().used}
                    for name, process in processes.items():
                        sample_row[name + '_cpu_percent'] = process.cpu_percent()
                        sample_row[name + '_rss_bytes'] = process.memory_info().rss
                    try:
                        sample_row['python'] = (await client.get(args.python_url + '/metrics', timeout=5)).json()
                    except httpx.HTTPError as exc:
                        sample_row['monitor_error'] = type(exc).__name__
                    samples.append(sample_row)
                    try:
                        await asyncio.wait_for(done.wait(), .5)
                    except TimeoutError:
                        pass

            started = time.perf_counter()
            monitoring = asyncio.create_task(sample())
            try:
                rows = await asyncio.gather(*(submit(i) for i in range(concurrency)))
                after = await drain()
            finally:
                done.set()
                await monitoring
            elapsed = time.perf_counter() - started
            successes = [row for row in rows if row['successful_analysis']]
            waits = [row['queue_wait_ms'] for row in rows if row.get('queue_wait_ms') is not None]
            stage = {
                'concurrency': concurrency, 'elapsed_seconds': round(elapsed, 3),
                'successful_analyses': len(successes), 'status_counts': dict(Counter(str(row['status']) for row in rows)),
                'successful_analyses_per_minute': round(len(successes) / elapsed * 60, 3),
                'success_latency_p50_ms': percentile([row['latency_ms'] for row in successes], .5),
                'success_latency_p95_ms': percentile([row['latency_ms'] for row in successes], .95),
                'queue_wait_p95_ms': percentile(waits, .95),
                'python_counter_delta': {key: after[key] - before[key] for key in ['completed', 'failed', 'rejected', 'timed_out']},
                'observed_peak_active': max((row.get('python', {}).get('active', 0) for row in samples), default=0),
                'requests': rows, 'samples': samples,
            }
            report['stages'].append(stage)
            save()
            print(json.dumps({key: value for key, value in stage.items() if key not in ['requests', 'samples']}), flush=True)
    report['finished_utc'] = datetime.now(timezone.utc).isoformat()
    save()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-url', default='http://127.0.0.1:8000')
    parser.add_argument('--node-url', help='Optional Node API URL including /api')
    parser.add_argument('--tokens-file', help='Private JSON array of distinct UAT user bearer tokens')
    parser.add_argument('--audio', nargs='+', required=True)
    parser.add_argument('--levels', default='1,2,5,10,20,50,100')
    parser.add_argument('--language', choices=['English', 'Filipino', 'Taglish'], default='English')
    parser.add_argument('--timeout', type=float, default=360)
    parser.add_argument('--python-pid', type=int)
    parser.add_argument('--node-pid', type=int)
    parser.add_argument('--output', default='benchmark-results/uat.json')
    asyncio.run(run(parser.parse_args()))
