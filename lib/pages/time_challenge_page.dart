import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'result_page.dart'; // Unified Result Page

enum ChallengeDifficulty { beginner, intermediate, advanced }
enum _PracticeState { ready, recording, paused }

class TimedChallengePage extends StatefulWidget {
  final dynamic challenge;
  final String? userId; 
  final VoidCallback? onBack;
  final VoidCallback? onBackToHome;

  const TimedChallengePage({
    super.key,
    required this.challenge,
    this.userId, 
    this.onBack,
    this.onBackToHome,
  });

  @override
  State<TimedChallengePage> createState() => _TimedChallengePageState();
}

class _TimedChallengePageState extends State<TimedChallengePage> {
  _PracticeState _state = _PracticeState.ready;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isUploading = false;
  bool _isEnglish = true; 

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  int get _durationSeconds => widget.challenge['timeLimitSeconds'] ?? 60;
  int get _remainingSeconds => (_durationSeconds - _elapsedSeconds).clamp(0, _durationSeconds);

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        _timer?.cancel();
        
        if (_state == _PracticeState.ready) {
          _elapsedSeconds = 0;
          final Directory tempDir = await getTemporaryDirectory();
          _audioPath = '${tempDir.path}/ispeak_challenge_${DateTime.now().millisecondsSinceEpoch}.m4a';
          
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc), 
            path: _audioPath!,
          );
        } else if (_state == _PracticeState.paused) {
          await _audioRecorder.resume();
        }

        setState(() => _state = _PracticeState.recording);
        
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() {
            _elapsedSeconds++;
          });
          
          if (_elapsedSeconds >= _durationSeconds) {
            _timer?.cancel();
            _finishSession(); 
          }
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _pause() async {
    _timer?.cancel();
    await _audioRecorder.pause();
    setState(() => _state = _PracticeState.paused);
  }

  Future<void> _reset() async {
    _timer?.cancel();
    await _audioRecorder.stop();
    if (_audioPath != null) {
      final file = File(_audioPath!);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;

    setState(() {
      _state = _PracticeState.ready;
      _elapsedSeconds = 0;
      _audioPath = null;
    });
  }

  Future<void> _finishSession() async {
    _timer?.cancel();
    setState(() => _isUploading = true); 
    
    try {
      final finalPath = await _audioRecorder.stop();
      if (finalPath != null) {
        var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/upload-audio'));
        
        request.fields['userId'] = widget.userId ?? 'test_user';
        request.fields['language'] = _isEnglish ? 'English' : 'Filipino'; 
        request.fields['challengeId'] = widget.challenge['_id'] ?? 'unknown'; 
        
        request.files.add(await http.MultipartFile.fromPath('audio', finalPath));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resultData = jsonDecode(response.body);
          if (mounted) {
            // FIX APPLIED HERE: push instead of pushReplacement
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultPage(
                  sessionData: resultData,
                  onPracticeAgain: () {
                    Navigator.of(context).pop();
                    _reset();
                  },
                  onBackToHome: () {
                    Navigator.of(context).pop();
                    widget.onBackToHome?.call();
                    widget.onBack?.call();
                  },
                ),
              ),
            );
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Failed: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Error')));
    }
    setState(() => _isUploading = false);
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  ChallengeDifficulty get _difficulty {
    final diffStr = widget.challenge['difficulty'];
    if (diffStr == 'Intermediate') return ChallengeDifficulty.intermediate;
    if (diffStr == 'Advanced') return ChallengeDifficulty.advanced;
    return ChallengeDifficulty.beginner;
  }

  String get _diffLabel {
    switch (_difficulty) {
      case ChallengeDifficulty.beginner:     return 'Beginner';
      case ChallengeDifficulty.intermediate: return 'Intermediate';
      case ChallengeDifficulty.advanced:     return 'Advanced';
    }
  }

  Color get _diffColor {
    switch (_difficulty) {
      case ChallengeDifficulty.beginner:     return const Color(0xFF3FBD7A);
      case ChallengeDifficulty.intermediate: return const Color(0xFF3F7CF4);
      case ChallengeDifficulty.advanced:     return const Color(0xFFB45FD4);
    }
  }

  Color get _diffBg {
    switch (_difficulty) {
      case ChallengeDifficulty.beginner:     return const Color(0xFFDFF5E8);
      case ChallengeDifficulty.intermediate: return const Color(0xFFE6EEFF);
      case ChallengeDifficulty.advanced:     return const Color(0xFFF3E6FF);
    }
  }

  String get _durationLabel {
    final s = _durationSeconds;
    return s < 60 ? '${s}s limit' : '${s ~/ 60}min limit';
  }

  @override
  Widget build(BuildContext context) {
    final isReady     = _state == _PracticeState.ready;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3), // Matched Background
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: SafeArea(
          top: false, 
          bottom: true,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                  child: Column(
                    children: [
                      if (isReady) ...[
                        _buildChallengeInfoCard(),
                        const SizedBox(height: 16),
                      ],
                      
                      if (!isReady) ...[
                        _buildLanguageBanner(),
                        const SizedBox(height: 14),
                      ],
                      
                      // ── NEW CLEAN RECORD CARD ──
                      _buildRecordCard(),
                      
                      const SizedBox(height: 40),

                      if (_state == _PracticeState.paused) 
                        _buildFinishButton(),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard() {
    final isRecording = _state == _PracticeState.recording;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : () {
              if (_state == _PracticeState.ready) {
                _start();
              } else if (_state == _PracticeState.recording) _pause();
              else _start(); 
            },
            child: CircleAvatar(
              radius: 50,
              backgroundColor: isRecording ? Colors.redAccent : const Color(0xFF3F7CF4),
              child: Icon(isRecording ? Icons.pause : Icons.mic, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _state == _PracticeState.ready ? 'Ready to Record' : isRecording ? 'Recording...' : 'Paused',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          Text(
            _fmt(_elapsedSeconds),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF3F7CF4)),
          ),
          if (_state != _PracticeState.ready) ...[
            const SizedBox(height: 6),
            const Text('Time Remaining', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              _fmt(_remainingSeconds),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
          ],
          if (_state == _PracticeState.paused && !_isUploading) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: _reset, child: const Text('Reset Session', style: TextStyle(color: Colors.redAccent))),
          ],
        ],
      ),
    );
  }

  Widget _buildFinishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3F7CF4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        onPressed: _isUploading ? null : _finishSession, 
        child: _isUploading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Finish & Analyze Speech', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 18),
      decoration: const BoxDecoration(color: Color(0xFF3F7CF4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  _timer?.cancel();
                  widget.onBack?.call();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: Colors.white, size: 24),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              const Spacer(),
              _buildLanguageToggle(),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Timed Challenge', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.challenge['description'] ?? 'Test your skills', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8), 
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _state == _PracticeState.recording ? null : () => setState(() => _isEnglish = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isEnglish ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isEnglish ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
              ),
              child: Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isEnglish ? const Color(0xFF3F7CF4) : Colors.white70)),
            ),
          ),
          GestureDetector(
            onTap: _state == _PracticeState.recording ? null : () => setState(() => _isEnglish = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: !_isEnglish ? const Color(0xFFF5A623) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: !_isEnglish ? [BoxShadow(color: const Color(0xFFF5A623).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
              ),
              child: Text('FIL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: !_isEnglish ? Colors.white : Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBanner() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.language, size: 14, color: !_isEnglish ? const Color(0xFFF5A623) : const Color(0xFF3F7CF4)),
        const SizedBox(width: 6),
        Text(
          !_isEnglish ? 'Practicing in Filipino' : 'Practicing in English',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: !_isEnglish ? const Color(0xFFF5A623) : const Color(0xFF3F7CF4)),
        ),
      ],
    );
  }

  Widget _buildChallengeInfoCard() {
    final title = widget.challenge['title'] ?? 'Challenge';
    final prompt = widget.challenge['prompt'] ?? 'Start speaking clearly.';
    final List<dynamic> tips = widget.challenge['tips'] ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF3F7CF4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _pill(
                bg: Colors.white.withOpacity(0.20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Text(_durationLabel, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _pill(bg: _diffBg, child: Text(_diffLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _diffColor))),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Prompt:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 8),
                Text(prompt, style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A50), height: 1.5)),
              ],
            ),
          ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Tips:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 6), child: CircleAvatar(radius: 3, backgroundColor: Colors.white70)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _pill({required Color bg, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}