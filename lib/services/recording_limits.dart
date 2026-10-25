import 'dart:async';

const maxRecordingSeconds = 300;

/// Monotonic active recording time retains fractions across pauses. The display
/// ticker is independent, so missed UI ticks cannot extend this deadline.
class RecordingDeadline {
  final int seconds;
  final Stopwatch _elapsed = Stopwatch();
  Timer? _timer;
  RecordingDeadline(this.seconds);

  void start(Future<void> Function() onLimit) {
    _timer?.cancel();
    _elapsed.start();
    final remaining = Duration(seconds: seconds) - _elapsed.elapsed;
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      pause();
      unawaited(onLimit());
    });
  }

  void pause() {
    _timer?.cancel();
    _elapsed.stop();
  }

  void reset() {
    pause();
    _elapsed.reset();
  }
}

int challengeRecordingLimit(Object? configured) =>
    configured is num && configured.isFinite && configured >= 1
    ? configured.floor().clamp(1, maxRecordingSeconds)
    : 60;
