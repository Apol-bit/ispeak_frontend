import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

// ─── Script Detail Page (NOW POWERED BY MONGODB JSON) ─────────────────────────

class ScriptDetailPage extends StatelessWidget {
  final dynamic script;
  final String? userId; // Passed down to attach to the audio recording

  const ScriptDetailPage({super.key, required this.script, this.userId});

  @override
  Widget build(BuildContext context) {
    final String fullContent = script['content'] ?? 'No content available for this script.';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        top: false, // Edge-to-edge support
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        fullContent,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: Colors.black87,
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.mic, color: Colors.white, size: 18),
                        label: const Text(
                          'Practice with this Script',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScriptPracticePage(
                              script: script, 
                              userId: userId,
                            ),
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
      // Same padding style as the Dashboard/Resources header
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF3F7CF4),
        // MODIFICATION: Removed the curved corners (borderRadius property).
        // It now defaults to a straight rectangle, matching the Dashboard style.
      ),
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$duration • $level • $language',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    final List<dynamic> tips = script['tips'] ?? [];
    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF3F7CF4)),
              SizedBox(width: 8),
              Text(
                'Tips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F7CF4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $tip',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Script Practice Page ─────────────────────────────────────────────────────

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
        
        if (_status == PracticeStatus.ready) {
          _seconds = 0;
          final Directory tempDir = await getTemporaryDirectory();
          _audioPath = '${tempDir.path}/ispeak_script_${DateTime.now().millisecondsSinceEpoch}.m4a';
          
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc), 
            path: _audioPath!,
          );
        } else if (_status == PracticeStatus.paused) {
          await _audioRecorder.resume();
        }

        setState(() => _status = PracticeStatus.recording);
        
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
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
    
    // FIX: Safety check for async operation!
    if (!mounted) return; 

    setState(() {
      _status = PracticeStatus.ready;
      _seconds = 0;
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
        // Scripts have a fixed language, pass it directly to backend
        request.fields['language'] = widget.script['language'] ?? 'English'; 
        request.fields['resourceId'] = widget.script['_id'] ?? 'unknown'; 
        
        request.files.add(await http.MultipartFile.fromPath('audio', finalPath));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resultData = jsonDecode(response.body);
          debugPrint("AI Worker Response: $resultData"); 
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => SessionResultsPage(
                  script: widget.script,
                  duration: _formatTime(_seconds),
                  sessionData: resultData, // Real AI Data
                ),
              ),
            );
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Failed: ${response.body}')));
        }
      }
    } catch (e) {
      debugPrint("Error uploading: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Error')));
    }
    setState(() => _isUploading = false);
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.script['title'] ?? 'Practice Script';
    final level = widget.script['difficulty'] ?? 'Beginner';
    final language = widget.script['language'] ?? 'English';
    final content = widget.script['content'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        top: false, // Edge-to-edge UI
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    // ── Script Preview Card ──
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1A1A2E),
                            ),
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
                          Text(
                            content,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Record Button ──
                    GestureDetector(
                      onTap: _isUploading ? null : () {
                        if (_status == PracticeStatus.ready) _start();
                        else if (_status == PracticeStatus.recording) _pause();
                        else _start();
                      },
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: _status == PracticeStatus.recording
                              ? Colors.red.shade100
                              : const Color(0xFFDCEAFD),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _status == PracticeStatus.recording
                                  ? Colors.redAccent
                                  : const Color(0xFF3F7CF4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _status == PracticeStatus.recording ? Icons.pause : Icons.mic,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Status Text ──
                    Text(
                      _status == PracticeStatus.ready
                          ? 'Ready to Record'
                          : _status == PracticeStatus.recording
                              ? 'Recording...'
                              : 'Paused',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),

                    // ── Timer ──
                    Text(
                      _formatTime(_seconds),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F7CF4),
                      ),
                    ),

                    const Spacer(),

                    // ── Finish Button (paused only) ──
                    if (_status == PracticeStatus.paused) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F7CF4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isUploading ? null : _finishSession,
                          child: _isUploading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Finish & Analyze Speech',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 52),
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
          const Text(
            'Script Practice',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.script['description'] ?? 'Practice reading aloud.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Session Results Page (NOW DYNAMIC) ───────────────────────────────────────

class SessionResultsPage extends StatelessWidget {
  final dynamic script;
  final String duration;
  final Map<String, dynamic>? sessionData; 

  const SessionResultsPage({
    super.key,
    required this.script,
    required this.duration,
    this.sessionData,
  });

  String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }

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
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year} • $duration duration';

    // Safely extract data
    final data = sessionData?['metrics'] ?? sessionData ?? {};

    final int wpmDisplay = (data['wpmScore'] ?? data['paceWpm'] ?? 0).toInt();
    final int fillerDisplay = (data['fillerWordCount'] ?? data['fillerCount'] ?? 0).toInt();
    final int overallScore = (data['overallScore'] ?? 0).toInt();
    final int paceScore = (data['paceScore'] ?? 0).toInt();
    final int clarityScore = (data['clarityScore'] ?? 0).toInt();
    final int energyScore = (data['energyScore'] ?? 0).toInt();

    final Color overallColor = _getScoreColor(overallScore);
    
    final feedback = data['feedback'] ?? {};
    final String paceFb = feedback['pace'] ?? (paceScore == 0 ? 'Awaiting AI Analysis...' : 'Good pacing.');
    final String clarityFb = feedback['clarity'] ?? (clarityScore == 0 ? 'Awaiting AI Analysis...' : 'Minimal fillers.');
    final String energyFb = feedback['energy'] ?? (energyScore == 0 ? 'Awaiting AI Analysis...' : 'Good energy level.');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        top: false, // Edge-to-edge support
        child: Column(
          children: [
            // ── Blue Header ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 22),
              decoration: const BoxDecoration(
                color: Color(0xFF3F7CF4),
                // Corner rounding removed here as well for consistency.
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, color: Colors.white, size: 20),
                        Text('Back to Home', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Session Results',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Overall Score Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Column(
                        children: [
                          Text(
                            overallScore.toString(),
                            style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: overallColor, height: 1),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Overall Score',
                            style: TextStyle(color: Color(0xFF666680), fontSize: 15),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: overallColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getScoreLabel(overallScore),
                              style: TextStyle(color: overallColor, fontWeight: FontWeight.bold, fontSize: 13),
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

                    // ── Breakdown Cards ──
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

                    const SizedBox(height: 30),

                    // ── Action Buttons ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F7CF4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Practice Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                        child: const Text('Back to Home', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _buildBreakdownCard({
    required IconData icon, required Color iconColor, required Color iconBg,
    required String title, required String subtitle, required int score,
    required Color scoreColor, required double progress, required Color barColor, required String feedback,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E))),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text('$score', style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 24)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(barColor), minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(score == 0 ? Icons.hourglass_empty : Icons.check, size: 14, color: score == 0 ? Colors.grey : barColor),
              const SizedBox(width: 6),
              Expanded(child: Text(feedback, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
        ],
      ),
    );
  }
}