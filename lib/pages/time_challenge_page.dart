import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

// We keep this enum because the learning_resources_page uses it for styling colors
enum ChallengeDifficulty { beginner, intermediate, advanced }

enum _PracticeState { ready, recording, paused }

class TimedChallengePage extends StatefulWidget {
  // Accepts MongoDB JSON map
  final dynamic challenge;
  final String? userId; // Added to pass to your backend
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
  
  // Consistent Language State (Matches your PracticePage!)
  bool _isEnglish = true; 

  // --- AUDIO RECORDING VARIABLES ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  // Visual UI placeholders for the recording screen
  double _paceWpm = 120;
  int _fillerCount = 0;
  double _energyLevel = 0.85;

  // Safely extract the time limit from backend JSON
  int get _durationSeconds => widget.challenge['timeLimitSeconds'] ?? 60;

  int get _remainingSeconds =>
      (_durationSeconds - _elapsedSeconds).clamp(0, _durationSeconds);

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
          _paceWpm = 120;
          _fillerCount = 0;
          _energyLevel = 0.85;
          
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
            // Simulate gradually shifting metrics for the live recording UI
            if (_elapsedSeconds >= 5) _paceWpm = 125;
            if (_elapsedSeconds == 7) _fillerCount = 1;
            if (_elapsedSeconds == 9) _fillerCount = 3;
          });
          
          // AUTO-FINISH when countdown hits zero
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
    setState(() {
      _state = _PracticeState.ready;
      _elapsedSeconds = 0;
      _fillerCount = 0;
      _paceWpm = 120;
      _audioPath = null;
    });
  }

  // ── YOUR UPLOAD LOGIC ──
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
          // Parse the real AI result data!
          final resultData = jsonDecode(response.body);
          debugPrint("AI Worker Response: $resultData"); 
          
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChallengeResultsPage(
                  challenge: widget.challenge,
                  durationSeconds: _elapsedSeconds,
                  sessionData: resultData, // Passing the real API data!
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Failed: ${response.body}')));
          }
        }
      }
    } catch (e) {
      debugPrint("Error uploading: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Error')));
    }
    setState(() => _isUploading = false);
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // ── Difficulty helpers pulling from JSON string ──
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
    final isRecording = _state == _PracticeState.recording;
    final isPaused    = _state == _PracticeState.paused;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: SafeArea(
          top: false, // Edge-to-Edge UI
          bottom: true,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
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
                      
                      _buildRecordCard(isReady, isRecording, isPaused),
                      
                      if (isRecording || isPaused) ...[
                        const SizedBox(height: 14),
                        _buildMetricCard(
                          icon: Icons.volume_up,
                          iconColor: const Color(0xFF3F7CF4),
                          iconBg: const Color(0xFFE6EEFF),
                          title: 'Pace',
                          value: '${_paceWpm.toInt()} WPM',
                          valueColor: const Color(0xFF3F7CF4),
                          progress: (_paceWpm / 150).clamp(0.0, 1.0),
                          barColor: const Color(0xFF3F7CF4),
                          helper: 'Optimal pace range: ${widget.challenge['targetMetric'] ?? '120-140 WPM'}',
                        ),
                        const SizedBox(height: 10),
                        _buildMetricCard(
                          icon: Icons.chat_bubble_outline,
                          iconColor: const Color(0xFF3F7CF4),
                          iconBg: const Color(0xFFE6EEFF),
                          title: 'Clarity',
                          value: _fillerCount == 0 ? '0 fillers' : '$_fillerCount fillers',
                          valueColor: _fillerCount == 0 ? const Color(0xFF3F7CF4) : const Color(0xFFF4913F),
                          progress: _fillerCount == 0 ? 1.0 : (1 - _fillerCount / 10).clamp(0.0, 1.0),
                          barColor: _fillerCount == 0 ? const Color(0xFF3F7CF4) : const Color(0xFFF4913F),
                          helper: _fillerCount == 0 ? 'Perfect! No filler words' : 'Detected: "um", "uh"',
                        ),
                        const SizedBox(height: 10),
                        _buildMetricCard(
                          icon: Icons.bolt,
                          iconColor: const Color(0xFF3F7CF4),
                          iconBg: const Color(0xFFE6EEFF),
                          title: 'Energy',
                          value: 'High',
                          valueColor: const Color(0xFF3F7CF4),
                          progress: _energyLevel,
                          barColor: const Color(0xFF3F7CF4),
                          helper: 'Strong vocal projection',
                        ),
                      ],
                      
                      if (isPaused) ...[
                        const SizedBox(height: 20),
                        _buildFinishButton(),
                      ],
                      const SizedBox(height: 20),
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

  Widget _buildHeader(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF3F7CF4),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
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
          const Text(
            'Timed Challenge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.challenge['description'] ?? 'Test your skills',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), 
        borderRadius: BorderRadius.circular(20),
      ),
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
                boxShadow: _isEnglish 
                    ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                'EN', 
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: _isEnglish ? const Color(0xFF3F7CF4) : Colors.white70
                ),
              ),
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
                boxShadow: !_isEnglish 
                    ? [BoxShadow(color: const Color(0xFFF5A623).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                'FIL', 
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: !_isEnglish ? Colors.white : Colors.white70
                ),
              ),
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: !_isEnglish ? const Color(0xFFF5A623) : const Color(0xFF3F7CF4),
          ),
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
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
              _pill(
                bg: _diffBg,
                child: Text(
                  _diffLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _diffColor),
                ),
              ),
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
                const Text(
                  'Your Prompt:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Text(
                  prompt,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A50), height: 1.5),
                ),
              ],
            ),
          ),
          
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Tips:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: CircleAvatar(radius: 3, backgroundColor: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  Widget _buildRecordCard(bool isReady, bool isRecording, bool isPaused) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : () {
              if (isReady) {
                _start();
              } else if (isRecording) {
                _pause();
              } else {
                _start(); // resume
              }
            },
            child: CircleAvatar(
              radius: 42,
              backgroundColor: isRecording ? Colors.redAccent : const Color(0xFF3F7CF4),
              child: Icon(
                isRecording ? Icons.pause : Icons.mic,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isReady ? 'Ready to Record' : isRecording ? 'Recording...' : 'Paused',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(_elapsedSeconds),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3F7CF4)),
          ),
          if (!isReady) ...[
            const SizedBox(height: 6),
            const Text('Time Remaining', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              _fmt(_remainingSeconds),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
          ],
          if (isPaused && !_isUploading) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _reset,
              child: const Text('Reset Session', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon, required Color iconColor, required Color iconBg,
    required String title, required String value, required Color valueColor,
    required double progress, required Color barColor, required String helper,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A2E))),
              const Spacer(),
              Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(barColor), minHeight: 7,
            ),
          ),
          const SizedBox(height: 6),
          Text(helper, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _isUploading ? null : _finishSession, 
        child: _isUploading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text(
              'Finish & Analyze Speech',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SESSION RESULTS PAGE (NOW 100% DYNAMIC!)
// ═════════════════════════════════════════════════════════════
class ChallengeResultsPage extends StatelessWidget {
  final dynamic challenge;
  final int durationSeconds;
  
  // Accept the JSON map from the AI analysis
  final Map<String, dynamic>? sessionData; 
  
  final VoidCallback? onPracticeAgain;
  final VoidCallback? onBackToHome;

  const ChallengeResultsPage({
    super.key,
    required this.challenge,
    required this.durationSeconds,
    this.sessionData,
    this.onPracticeAgain,
    this.onBackToHome,
  });

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String get _dateStr {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // ── YOUR EXACT DYNAMIC LOGIC FROM RESULT_PAGE.DART ──
  Color _getScoreColor(num score) {
    if (score == 0) return Colors.grey; 
    if (score >= 90) return const Color(0xFF3FBD7A); 
    if (score >= 75) return const Color(0xFF3F7CF4); 
    if (score >= 60) return const Color(0xFFF5A623); 
    return const Color(0xFFEF4444);                  
  }

  String _getScoreLabel(num score) {
    if (score == 0) return 'Pending AI Analysis ⏳';
    if (score >= 90) return 'Excellent 🎉';
    if (score >= 75) return 'Good 👍';
    if (score >= 60) return 'Fair 😐';
    return 'Needs Work 📈';
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract the metrics from the API payload
    // Handles { metrics: { ... } } or flat objects
    final data = sessionData?['metrics'] ?? sessionData ?? {};

    // Extract exactly like your global ResultPage
    final int wpmDisplay = (data['wpmScore'] ?? data['paceWpm'] ?? 0).toInt();
    final int fillerDisplay = (data['fillerWordCount'] ?? data['fillerCount'] ?? 0).toInt();
    final int overallScore = (data['overallScore'] ?? 0).toInt();
    final int paceScore = (data['paceScore'] ?? 0).toInt();
    final int clarityScore = (data['clarityScore'] ?? 0).toInt();
    final int energyScore = (data['energyScore'] ?? 0).toInt();

    final Color overallColor = _getScoreColor(overallScore);
    
    // Safely extract specific AI feedback if it exists
    final feedback = data['feedback'] ?? {};
    final String paceFb = feedback['pace'] ?? (paceScore == 0 ? 'Awaiting AI Analysis...' : 'Good pacing. Try to maintain consistency.');
    final String clarityFb = feedback['clarity'] ?? (clarityScore == 0 ? 'Awaiting AI Analysis...' : 'Watch for "um" and "uh".');
    final String energyFb = feedback['energy'] ?? (energyScore == 0 ? 'Awaiting AI Analysis...' : 'Good energy level.');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: SafeArea(
          top: false, // Edge-to-edge support
          bottom: true,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Overall Score Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            Text(
                              overallScore.toString(), 
                              style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: overallColor, height: 1)
                            ),
                            const SizedBox(height: 6),
                            const Text('Overall Score', style: TextStyle(fontSize: 15, color: Color(0xFF666680))),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(color: overallColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                _getScoreLabel(overallScore), 
                                style: TextStyle(color: overallColor, fontWeight: FontWeight.bold, fontSize: 13)
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Performance Breakdown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                      ),
                      const SizedBox(height: 12),

                      // ── Breakdown Cards (Dynamic Colors + Data) ──
                      _buildBreakdownCard(
                        icon: Icons.volume_up, iconColor: const Color(0xFF3F7CF4), iconBg: const Color(0xFFE6EEFF),
                        title: 'Pace', subtitle: '$wpmDisplay words per minute',
                        score: paceScore, scoreColor: _getScoreColor(paceScore),
                        progress: (paceScore / 100.0).clamp(0.0, 1.0), barColor: _getScoreColor(paceScore),
                        feedback: paceFb,
                      ),
                      const SizedBox(height: 10),
                      _buildBreakdownCard(
                        icon: Icons.chat_bubble_outline, iconColor: const Color(0xFF3F7CF4), iconBg: const Color(0xFFE6EEFF),
                        title: 'Clarity', subtitle: '$fillerDisplay filler words detected',
                        score: clarityScore, scoreColor: _getScoreColor(clarityScore),
                        progress: (clarityScore / 100.0).clamp(0.0, 1.0), barColor: _getScoreColor(clarityScore),
                        feedback: clarityFb,
                      ),
                      const SizedBox(height: 10),
                      _buildBreakdownCard(
                        icon: Icons.bolt, iconColor: Colors.orange, iconBg: const Color(0xFFFFF3E0),
                        title: 'Energy', subtitle: 'Vocal projection',
                        score: energyScore, scoreColor: _getScoreColor(energyScore),
                        progress: (energyScore / 100.0).clamp(0.0, 1.0), barColor: _getScoreColor(energyScore),
                        feedback: energyFb,
                      ),

                      const SizedBox(height: 24),
                      _buildPrimaryButton('Practice Again', onPracticeAgain),
                      const SizedBox(height: 10),
                      _buildSecondaryButton('Back to Home', onBackToHome),
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

  Widget _buildHeader(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF3F7CF4),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBackToHome,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 24),
                SizedBox(width: 4),
                Text('Back to Home', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Session Results', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$_dateStr • ${_fmt(durationSeconds)} duration', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard({
    required IconData icon, required Color iconColor, required Color iconBg,
    required String title, required String subtitle, required int score,
    required Color scoreColor, required double progress, required Color barColor, required String feedback,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text('$score', style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(barColor), minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(score == 0 ? Icons.hourglass_empty : Icons.check, size: 14, color: score == 0 ? Colors.grey : barColor),
              const SizedBox(width: 6),
              Expanded(child: Text(feedback, style: const TextStyle(fontSize: 12, color: Colors.grey))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3F7CF4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFF3F7CF4), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Color(0xFF3F7CF4), fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}