import '../services/temporary_recording.dart';
import '../services/recording_limits.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';

enum PracticeState { ready, recording, paused }

enum PracticeLanguage { english, filipino, taglish }

class PracticePage extends StatefulWidget {
  final String userId;
  final int resetVersion;
  final Function(Map<String, dynamic>)? onFinish;

  const PracticePage({
    super.key,
    required this.userId,
    this.onFinish,
    this.resetVersion = 0,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with WidgetsBindingObserver {
  PracticeState _state = PracticeState.ready;
  Timer? _timer;
  final RecordingDeadline _deadline = RecordingDeadline(maxRecordingSeconds);
  int _seconds = 0;
  bool _isUploading = false;
  bool _starting = false;
  bool _stopped = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed &&
        _state == PracticeState.recording &&
        !_isUploading) {
      unawaited(_pause());
    }
  }

  Future<void> _stopAtLimit() async {
    _timer?.cancel();
    _deadline.pause();
    _seconds = maxRecordingSeconds;
    _stopped = true;
    try {
      _audioPath = await _audioRecorder.stop() ?? _audioPath;
      if (!mounted) return;
      setState(() => _state = PracticeState.paused);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '5-minute limit reached. Analyze this recording or reset.',
          ),
        ),
      );
    } catch (_) {
      await _reset();
    }
  }

  PracticeLanguage _language = PracticeLanguage.english;

  String get _languageName => switch (_language) {
    PracticeLanguage.english => 'English',
    PracticeLanguage.filipino => 'Filipino',
    PracticeLanguage.taglish => 'Taglish',
  };

  Color get _languageColor => switch (_language) {
    PracticeLanguage.english => const Color(0xFF3F7CF4),
    PracticeLanguage.filipino => const Color(0xFFF5A623),
    PracticeLanguage.taglish => const Color(0xFF7B61FF),
  };

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  @override
  void didUpdateWidget(PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetVersion != widget.resetVersion) {
      _timer?.cancel();
      _deadline.reset();
      final path = _audioPath;
      _audioPath = null;
      _seconds = 0;
      _state = PracticeState.ready;
      _isUploading = false;
      unawaited(discardTemporaryRecording(path));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _deadline.pause();
    WidgetsBinding.instance.removeObserver(this);
    final path = _audioPath;
    unawaited(
      _audioRecorder.dispose().whenComplete(
        () => discardTemporaryRecording(path),
      ),
    );
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _isUploading || _seconds >= maxRecordingSeconds) return;
    _starting = true;
    try {
      if (await _audioRecorder.hasPermission()) {
        _timer?.cancel();
        if (_state == PracticeState.ready) {
          _deadline.reset();
          _seconds = 0;
          _stopped = false;
          final Directory tempDir = await getTemporaryDirectory();
          _audioPath =
              '${tempDir.path}/ispeak_${DateTime.now().millisecondsSinceEpoch}.wav';

          // Configured for Whisper AI
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: _audioPath!,
          );
        } else if (_state == PracticeState.paused) {
          await _audioRecorder.resume();
        }

        if (!mounted || !_active) {
          await _reset();
          return;
        }
        setState(() => _state = PracticeState.recording);
        _deadline.start(_stopAtLimit);
        final base = _seconds;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(
            () => _seconds = (base + timer.tick).clamp(0, maxRecordingSeconds),
          );
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
      await _reset();
    } finally {
      _starting = false;
    }
  }

  Future<void> _pause() async {
    if (_starting) return;
    _starting = true;
    _timer?.cancel();
    _deadline.pause();
    try {
      await _audioRecorder.pause();
      if (mounted) setState(() => _state = PracticeState.paused);
    } catch (_) {
      await _reset();
    } finally {
      _starting = false;
    }
  }

  Future<void> _reset() async {
    _timer?.cancel();
    _deadline.reset();
    try {
      await _audioRecorder.stop();
    } catch (_) {
      /* Already interrupted. */
    }
    await discardTemporaryRecording(_audioPath);
    if (!mounted) return;
    setState(() {
      _state = PracticeState.ready;
      _seconds = 0;
      _audioPath = null;
      _stopped = false;
    });
  }

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0F0F3),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {
                  const title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice Session',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Record your speech to get instant feedback',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 340) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 12),
                        _buildLanguageToggle(),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      _buildLanguageToggle(),
                    ],
                  );
                },
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language, size: 16, color: _languageColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Practicing in $_languageName',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _languageColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _recordCard(),

              const SizedBox(height: 40),

              // ---> CONDITION FIX: Changed to 10 seconds <---
              if (_state == PracticeState.paused && _seconds >= 10)
                _finishButton(),

              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: PracticeLanguage.values.map((language) {
          final isSelected = _language == language;
          final label = switch (language) {
            PracticeLanguage.english => 'EN',
            PracticeLanguage.filipino => 'FIL',
            PracticeLanguage.taglish => 'TAG',
          };
          final color = switch (language) {
            PracticeLanguage.english => const Color(0xFF3F7CF4),
            PracticeLanguage.filipino => const Color(0xFFF5A623),
            PracticeLanguage.taglish => const Color(0xFF7B61FF),
          };

          return GestureDetector(
            onTap: _state == PracticeState.recording
                ? null
                : () => setState(() => _language = language),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _recordCard() {
    final isRecording = _state == PracticeState.recording;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploading
                ? null
                : () {
                    if (_state == PracticeState.ready) {
                      _start();
                    } else if (_state == PracticeState.recording) {
                      _pause();
                    } else {
                      _start();
                    }
                  },
            child: CircleAvatar(
              radius: 50,
              backgroundColor: isRecording
                  ? Colors.redAccent
                  : const Color(0xFF3F7CF4),
              child: Icon(
                isRecording ? Icons.pause : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _state == PracticeState.ready
                ? 'Ready to Record'
                : _state == PracticeState.recording
                ? 'Recording...'
                : 'Paused',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            _time,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F7CF4),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Maximum recording: 05:00',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (_state == PracticeState.paused && !_isUploading)
            TextButton(
              onPressed: _reset,
              child: const Text(
                "Reset Session",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _finishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3F7CF4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        onPressed: _isUploading
            ? null
            : () async {
                if (_isUploading) return;
                _timer?.cancel();
                _deadline.pause();
                setState(() => _isUploading = true);

                try {
                  final finalPath = _stopped
                      ? _audioPath
                      : await _audioRecorder.stop();

                  if (finalPath != null) {
                    var request = http.MultipartRequest(
                      'POST',
                      Uri.parse('${ApiConfig.baseUrl}/upload-audio'),
                    );

                    request.fields['userId'] = widget.userId;
                    request.fields['language'] = _languageName;
                    request.fields['practiceMode'] = 'ordinary';
                    request.fields['durationSeconds'] = _seconds.toString();

                    request.files.add(
                      await http.MultipartFile.fromPath('audio', finalPath),
                    );

                    var response = await ApiClient.sendMultipart(request);

                    if (response.statusCode == 200 ||
                        response.statusCode == 201) {
                      final resultData = jsonDecode(response.body);
                      if (mounted) widget.onFinish?.call(resultData);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ApiClient.errorMessage(response)),
                          ),
                        );
                      }
                    }
                  }
                } catch (e) {
                  debugPrint("Error uploading: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connection Error')),
                    );
                  }
                }
                await discardTemporaryRecording(_audioPath);
                _audioPath = null;
                if (mounted) {
                  setState(() {
                    _isUploading = false;
                    _state = PracticeState.ready;
                    _seconds = 0;
                    _stopped = false;
                  });
                }
              },
        child: _isUploading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Finish & Analyze Speech',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
