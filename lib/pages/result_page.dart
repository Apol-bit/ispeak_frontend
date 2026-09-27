import '../widgets/feedback_tips.dart';
import '../widgets/fixed_back_layout.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResultPage extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onBackToHome;
  final VoidCallback? onPracticeAgain;
  final Map<String, dynamic>? sessionData;

  const ResultPage({
    super.key,
    this.onBack,
    this.onBackToHome,
    this.onPracticeAgain,
    this.sessionData,
  });

  Color _getScoreColor(num score) {
    if (score == 0) return Colors.grey;
    if (score >= 90) return const Color(0xFF3FBD7A);
    if (score >= 75) return const Color(0xFF3F7CF4);
    if (score >= 60) return const Color(0xFFF5A623);
    return const Color(0xFFEF4444);
  }

  String _getScoreLabel(num score) {
    if (score == 0) return 'Needs Work';
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Work';
  }

  Object _feedback(String metric, String fallback) {
    final feedback = sessionData?['analysisFeedback'];
    final value = feedback is Map ? feedback[metric] : null;
    return value is List && value.isNotEmpty ||
            value is String && value.trim().isNotEmpty
        ? value as Object
        : fallback;
  }

  Object _getPaceFeedback(int score, int wpm) => _feedback(
    'pace',
    'Recorded pace: $wpm words per minute. Detailed findings are unavailable for this saved session.',
  );

  Object _getClarityFeedback(
    int score,
    int fillers,
    bool available,
  ) => _feedback(
    'clarity',
    available
        ? '$fillers filler spans were detected. Detailed clarity findings are unavailable for this saved session.'
        : 'Filler-word analysis was unavailable for this session.',
  );

  Object _getEnergyFeedback(int score) => _feedback(
    'energy',
    'Detailed energy and pitch findings are unavailable for this saved session.',
  );

  // Format date and time from ISO string
  String _formatDateTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) {
      return 'Date Unknown';
    }
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[dateTime.month - 1];
      final day = dateTime.day;
      final year = dateTime.year;

      // Format time as HH:MM AM/PM
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = (hour > 12) ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$month $day, $year • $displayHour:$minute $period';
    } catch (e) {
      return 'Date Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = sessionData ?? {};

    final int wpmDisplay = (data['wpmScore'] ?? 0).toInt();
    final int fillerDisplay = (data['fillerWordCount'] ?? 0).toInt();
    final bool fillerAnalysisAvailable =
        data['fillerAnalysisAvailable'] ?? false;
    final int overallScore = (data['overallScore'] ?? 0).toInt();
    final int paceScore = (data['paceScore'] ?? 0).toInt();
    final int clarityScore = (data['clarityScore'] ?? 0).toInt();
    final int energyScore = (data['energyScore'] ?? 0).toInt();
    final String createdAt = data['createdAt'] ?? '';
    final availability = data['analysisAvailability'];
    final isPartial =
        availability is! Map ||
        availability['pitch'] != true ||
        availability['pronunciation'] != true ||
        availability['fillers'] != true;
    final transcript = data['transcription']?.toString().trim() ?? '';
    final invalidRecording =
        data['analysisValid'] == false ||
        (data['wpmScore'] as num? ?? 0) <= 0 ||
        transcript.isEmpty ||
        transcript == 'No transcription available.';
    if (invalidRecording) {
      return Scaffold(
        body: FixedBackLayout(
          onBack: onBack ?? onPracticeAgain ?? onBackToHome,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recording not evaluated',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This recording does not contain enough usable speech for a reliable assessment. Please record a short sentence and try again.',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onPracticeAgain ?? onBackToHome,
                  child: const Text('Practice Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Color overallColor = _getScoreColor(overallScore);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: FixedBackLayout(
        onBack: onBack ?? onPracticeAgain ?? onBackToHome,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF3F7CF4),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // --- Date and Time Display ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDateTime(createdAt),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                overallScore.toString(),
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: overallColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Overall Score',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              if (isPartial)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Partial assessment: some analysis components are unavailable.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: overallColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getScoreLabel(overallScore),
                                  style: TextStyle(
                                    color: overallColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildMetricCard(
                      icon: Icons.volume_up_outlined,
                      title: 'Pace',
                      subtitle: '$wpmDisplay words per minute',
                      score: paceScore,
                      feedback: _getPaceFeedback(
                        paceScore,
                        wpmDisplay,
                      ), // <-- UPDATED
                    ),
                    const SizedBox(height: 16),

                    _buildMetricCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'Clarity',
                      subtitle: fillerAnalysisAvailable
                          ? '$fillerDisplay filler words detected'
                          : 'Filler-word analysis unavailable',
                      score: clarityScore,
                      feedback: _getClarityFeedback(
                        clarityScore,
                        fillerDisplay,
                        fillerAnalysisAvailable,
                      ), // <-- UPDATED
                    ),
                    const SizedBox(height: 16),

                    _buildMetricCard(
                      icon: Icons.bolt,
                      title: 'Energy',
                      subtitle: 'Speech volume and vocal intensity',
                      score: energyScore,
                      feedback: _getEnergyFeedback(energyScore), // <-- UPDATED
                    ),

                    if (data['tips'] != null) ...[
                      const SizedBox(height: 16),
                      FeedbackTips(tips: data['tips']),
                    ],
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: AppTheme.backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: onPracticeAgain ?? onBackToHome,
                        child: const Text(
                          'Practice Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int score,
    required Object feedback,
  }) {
    final Color scoreColor = _getScoreColor(score);
    final double progressValue = (score / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scoreColor.withValues(alpha: 0.15),
                child: Icon(icon, color: scoreColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                score.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 12),
          FeedbackTips(tips: feedback),
        ],
      ),
    );
  }
}
