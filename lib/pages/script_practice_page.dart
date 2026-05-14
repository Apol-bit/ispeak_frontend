import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'result_page.dart'; // Unified Result Page

class ScriptDetailPage extends StatelessWidget {
  final dynamic script;
  final String? userId; 

  const ScriptDetailPage({super.key, required this.script, this.userId});

  @override
  Widget build(BuildContext context) {
    // Use transcript first, fall back to content for backward compat
    final String fullContent = script['transcript'] ?? script['content'] ?? 'No content available for this script.';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3), // Matched PracticePage background
      body: SafeArea(
        top: false, 
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Full Script',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Text(
                        fullContent,
                        style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTipsSection(),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F7CF4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.mic, color: Colors.white, size: 18),
                        label: const Text(
                          'Practice with this Script',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScriptPracticePage(script: script, userId: userId),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = script['title'] ?? 'Practice Script';
    final duration = '${script['estimatedMinutes'] ?? 0} min';
    final level = script['difficulty'] ?? 'Beginner';
    final language = script['language'] ?? 'English';
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 20),
      decoration: const BoxDecoration(color: Color(0xFF3F7CF4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 20),
                Text('Back', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$duration • $level • $language', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    final List<dynamic> tips = script['tips'] ?? [];
    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF3F7CF4)),
              SizedBox(width: 8),
              Text('Tips', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F7CF4))),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $tip', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          )),
        ],
      ),
    );
  }
}

enum PracticeStatus { ready, recording, paused }

class ScriptPracticePage extends StatefulWidget {
  final dynamic script;
  final String? userId;
  
  const ScriptPracticePage({super.key, required this.script, this.userId});

  @override
  State<ScriptPracticePage> createState() => _ScriptPracticePageState();
}

class _ScriptPracticePageState extends State<ScriptPracticePage> {
  PracticeStatus _status = PracticeStatus.ready;
  int _seconds = 0;
  Timer? _timer;
  bool _isUploading = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  // ── KARAOKE TELEPROMPTER STATE ──────────────────────────────────
  List<String> _words = [];
  List<_WordTiming> _wordTimings = [];
  int _currentWordIndex = -1; // -1 means not started
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeKaraoke();
  }

  void _initializeKaraoke() {
    // Parse the script text into individual words
    final content = widget.script['transcript'] ?? widget.script['content'] ?? '';
    _words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Try to use word timestamps from reference audio if available
    final timestamps = widget.script['wordTimestamps'] ?? widget.script['word_timestamps'];
    if (timestamps != null && timestamps is List && timestamps.isNotEmpty) {
      _wordTimings = timestamps.map<_WordTiming>((t) => _WordTiming(
        word: t['word'] ?? '',
        start: (t['start'] ?? 0.0).toDouble(),
        end: (t['end'] ?? 0.0).toDouble(),
      )).toList();
    } else {
      // If no timestamps from reference audio, estimate based on average reading speed
      // ~150 WPM = ~2.5 words per second = ~0.4 seconds per word
      double currentTime = 0.0;
      const double avgWordDuration = 0.4;
      _wordTimings = _words.map((w) {
        final timing = _WordTiming(
          word: w,
          start: currentTime,
          end: currentTime + avgWordDuration,
        );
        currentTime += avgWordDuration;
        return timing;
      }).toList();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateKaraokePosition() {
    if (_wordTimings.isEmpty) return;

    final elapsed = _seconds.toDouble();
    int newIndex = -1;

    for (int i = 0; i < _wordTimings.length; i++) {
      if (elapsed >= _wordTimings[i].start && elapsed < _wordTimings[i].end + 0.5) {
        newIndex = i;
      }
    }

    // If past all timings, stay on last word
    if (newIndex == -1 && elapsed > 0 && _wordTimings.isNotEmpty) {
      if (elapsed >= _wordTimings.last.start) {
        newIndex = _wordTimings.length - 1;
      }
    }

    if (newIndex != _currentWordIndex) {
      setState(() => _currentWordIndex = newIndex);
      _autoScrollToCurrentWord();
    }
  }

  void _autoScrollToCurrentWord() {
    if (_currentWordIndex < 0 || !_scrollController.hasClients) return;

    // Estimate scroll position based on word index
    // Each word takes roughly 24px of height in the flow layout
    final wordsPerLine = 6; // approximate
    final lineHeight = 32.0;
    final targetLine = _currentWordIndex / wordsPerLine;
    final targetScroll = (targetLine * lineHeight) - 80; // offset to keep word centered

    _scrollController.animateTo(
      targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        _timer?.cancel();
        
        if (_status == PracticeStatus.ready) {
          _seconds = 0;
          _currentWordIndex = -1;
          final Directory tempDir = await getTemporaryDirectory();
          // ---> AUDIO FIX: Changed .m4a to .wav
          _audioPath = '${tempDir.path}/ispeak_script_${DateTime.now().millisecondsSinceEpoch}.wav';
          
          // Configured for Whisper AI
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ), 
            path: _audioPath!,
          );
        } else if (_status == PracticeStatus.paused) {
          await _audioRecorder.resume();
        }

        setState(() => _status = PracticeStatus.recording);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _seconds++);
            _updateKaraokePosition();
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
    setState(() => _status = PracticeStatus.paused);
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
      _status = PracticeStatus.ready;
      _seconds = 0;
      _audioPath = null;
      _currentWordIndex = -1;
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
        request.fields['language'] = widget.script['language'] ?? 'English'; 
        request.fields['resourceId'] = widget.script['_id'] ?? 'unknown'; 
        
        request.files.add(await http.MultipartFile.fromPath('audio', finalPath));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resultData = jsonDecode(response.body);
          if (mounted) {
            Navigator.of(context).push( 
              MaterialPageRoute(
                builder: (_) => ResultPage(
                  sessionData: resultData,
                  onBackToHome: () => Navigator.popUntil(context, (r) => r.isFirst),
                  onPracticeAgain: () {
                    Navigator.pop(context); 
                    _reset(); 
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

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.script['title'] ?? 'Practice Script';
    final level = widget.script['difficulty'] ?? 'Beginner';
    final language = widget.script['language'] ?? 'English';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3), 
      body: SafeArea(
        top: false, 
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: [
                    // ── KARAOKE TELEPROMPTER ──────────────────────
                    _buildKaraokeTeleprompter(title, level, language),

                    const SizedBox(height: 30),

                    _buildRecordCard(),

                    const SizedBox(height: 40),

                    // ---> CONDITION FIX: Changed to 10 seconds <---
                    if (_status == PracticeStatus.paused && _seconds >= 10) 
                      _buildFinishButton(),
                      
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── KARAOKE TELEPROMPTER WIDGET ──────────────────────────────────
  Widget _buildKaraokeTeleprompter(String title, String level, String language) {
    final isActive = _status == PracticeStatus.recording || _status == PracticeStatus.paused;
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        border: isActive 
          ? Border.all(color: const Color(0xFF3F7CF4).withOpacity(0.3), width: 2)
          : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and badges
          Row(
            children: [
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F7CF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A2E))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _badge(level, const Color(0xFFE6EEFF), const Color(0xFF3F7CF4)),
              _badge(language, Colors.grey.shade100, Colors.black54),
            ],
          ),
          const SizedBox(height: 14),
          
          // ── THE KARAOKE TEXT ──────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Wrap(
                spacing: 5,
                runSpacing: 8,
                children: List.generate(_words.length, (index) {
                  final bool isCurrent = index == _currentWordIndex;
                  final bool isPast = _currentWordIndex >= 0 && index < _currentWordIndex;
                  final bool isFuture = _currentWordIndex >= 0 && index > _currentWordIndex;
                  final bool isInactive = _currentWordIndex < 0;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: isCurrent 
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : EdgeInsets.zero,
                    decoration: isCurrent
                      ? BoxDecoration(
                          color: const Color(0xFF3F7CF4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF3F7CF4).withOpacity(0.4), width: 1.5),
                        )
                      : null,
                    child: Text(
                      _words[index],
                      style: TextStyle(
                        fontSize: isCurrent ? 15 : 13,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.normal,
                        color: isInactive
                          ? Colors.black87
                          : isCurrent
                            ? const Color(0xFF3F7CF4)
                            : isPast
                              ? Colors.grey.shade400
                              : isFuture
                                ? Colors.black87
                                : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          
          // Progress indicator
          if (_currentWordIndex >= 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _words.isEmpty ? 0 : (_currentWordIndex + 1) / _words.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3F7CF4)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_currentWordIndex + 1} / ${_words.length} words',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordCard() {
    final isRecording = _status == PracticeStatus.recording;
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
              if (_status == PracticeStatus.ready) {
                _start();
              } else if (_status == PracticeStatus.recording) _pause();
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
            _status == PracticeStatus.ready ? 'Ready to Record' : _status == PracticeStatus.recording ? 'Recording...' : 'Paused',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(_time, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF3F7CF4))),
          const SizedBox(height: 10),
          if (_status == PracticeStatus.paused && !_isUploading)
            TextButton(onPressed: _reset, child: const Text("Reset Session", style: TextStyle(color: Colors.redAccent))),
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
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  _timer?.cancel();
                  Navigator.pop(context);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: Colors.black87, size: 20),
                    Text('Back', style: TextStyle(color: Colors.black87, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Script Practice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(widget.script['description'] ?? 'Practice reading aloud.', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ── INTERNAL HELPER CLASS ──────────────────────────────────────────
class _WordTiming {
  final String word;
  final double start;
  final double end;

  _WordTiming({required this.word, required this.start, required this.end});
}