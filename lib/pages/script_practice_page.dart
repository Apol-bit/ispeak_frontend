import 'dart:async';
import 'package:flutter/material.dart';

// ─── Script Detail Page (NOW POWERED BY MONGODB JSON) ─────────────────────────

class ScriptDetailPage extends StatelessWidget {
  // Changed from `ScriptData` to `dynamic` to accept the backend JSON map
  final dynamic script;
  const ScriptDetailPage({super.key, required this.script});

  @override
  Widget build(BuildContext context) {
    // Extract full content securely
    final String fullContent = script['content'] ?? 'No content available for this script.';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
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
                            // Pass the exact same JSON map into the practice page
                            builder: (_) => ScriptPracticePage(script: script),
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
    // Pulling header data directly from backend keys
    final title = script['title'] ?? 'Practice Script';
    final duration = '${script['estimatedMinutes'] ?? 0} min';
    final level = script['difficulty'] ?? 'Beginner';
    final language = script['language'] ?? 'English';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      color: const Color(0xFF3F7CF4),
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
    // Cast the JSON array into a Flutter List
    final List<dynamic> tips = script['tips'] ?? [];

    // Don't render the box if there are no tips
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
  // Accepts the backend JSON map
  final dynamic script;
  const ScriptPracticePage({super.key, required this.script});

  @override
  State<ScriptPracticePage> createState() => _ScriptPracticePageState();
}

class _ScriptPracticePageState extends State<ScriptPracticePage> {
  PracticeStatus _status = PracticeStatus.ready;
  int _seconds = 0;
  Timer? _timer;

  void _toggleState() {
    setState(() {
      if (_status == PracticeStatus.ready || _status == PracticeStatus.paused) {
        _status = PracticeStatus.recording;
        _timer = Timer.periodic(
          const Duration(seconds: 1),
          (t) => setState(() => _seconds++),
        );
      } else {
        _status = PracticeStatus.paused;
        _timer?.cancel();
      }
    });
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract data for the practice card
    final title = widget.script['title'] ?? 'Practice Script';
    final level = widget.script['difficulty'] ?? 'Beginner';
    final language = widget.script['language'] ?? 'English';
    final content = widget.script['content'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
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
                      onTap: _toggleState,
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
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionResultsPage(
                                script: widget.script,
                                duration: _formatTime(_seconds),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Finish & View Results',
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
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, color: Colors.black87, size: 20),
                      Text('Back', style: TextStyle(color: Colors.black87, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Script Practice',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.script['description'] ?? 'Practice reading aloud.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
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

// ─── Session Results Page ─────────────────────────────────────────────────────

class SessionResultsPage extends StatelessWidget {
  // Accepts the dynamic script map
  final dynamic script;
  final String duration;

  const SessionResultsPage({
    super.key,
    required this.script,
    required this.duration,
  });

  String _monthName(int m) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[m];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year} • $duration duration';

    // Note: The scores and metrics below are currently hardcoded for the UI design.
    // Eventually, we will wire these up to the Python FastAPI worker!
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            // ── Blue Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              color: const Color(0xFF3F7CF4),
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
                  const SizedBox(height: 12),
                  const Text(
                    'Session Results',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: [
                    // ── Overall Score Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '85',
                            style: TextStyle(fontSize: 58, fontWeight: FontWeight.bold, color: Color(0xFF3FBD7A)),
                          ),
                          const Text(
                            'Overall Score',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDFF5E8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Excellent 🎉',
                              style: TextStyle(color: Color(0xFF3FBD7A), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Performance Breakdown Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Performance Breakdown',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 18),

                          const _MetricRow(
                            icon: Icons.speed_outlined, iconBg: Color(0xFFFFF3E0), iconColor: Color(0xFFFF9800),
                            label: 'Pace', score: 82, scoreColor: Color(0xFFFF9800),
                            subtitle: '139 words per minute', barColor: Color(0xFFFF9800),
                            feedback: 'Good pacing. Try to maintain consistency throughout.',
                          ),
                          Divider(height: 28, color: Colors.grey.shade100),

                          const _MetricRow(
                            icon: Icons.chat_bubble_outline, iconBg: Color(0xFFE8F5E9), iconColor: Color(0xFF3FBD7A),
                            label: 'Clarity', score: 93, scoreColor: Color(0xFF3FBD7A),
                            subtitle: '2 filler words detected', barColor: Color(0xFF3FBD7A),
                            feedback: 'Minimal filler words. Watch for "um" and "uh".',
                          ),
                          Divider(height: 28, color: Colors.grey.shade100),

                          const _MetricRow(
                            icon: Icons.bolt_outlined, iconBg: Color(0xFFFFF8E1), iconColor: Color(0xFFFFC107),
                            label: 'Energy', score: 79, scoreColor: Color(0xFFFFC107),
                            subtitle: 'Strong vocal projection', barColor: Color(0xFFFFC107),
                            feedback: 'Good energy level.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Practice Again ──
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

                    // ── Back to Home ──
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
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF3F7CF4),
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Practice'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progress'),
        ],
      ),
    );
  }
}

// ─── Metric Row Widget (UNCHANGED) ────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final int score;
  final Color scoreColor;
  final String subtitle;
  final Color barColor;
  final String feedback;

  const _MetricRow({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.label, required this.score, required this.scoreColor,
    required this.subtitle, required this.barColor, required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
                      Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scoreColor)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100, backgroundColor: Colors.grey.shade100, color: barColor, minHeight: 7,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check, size: 13, color: barColor),
            const SizedBox(width: 5),
            Expanded(child: Text(feedback, style: const TextStyle(fontSize: 11, color: Colors.black54))),
          ],
        ),
      ],
    );
  }
}