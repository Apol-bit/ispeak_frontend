import 'package:flutter/material.dart';
import '../theme/app_theme.dart';  

class ResultPage extends StatelessWidget {
  final VoidCallback? onBackToHome;
  final VoidCallback? onPracticeAgain;
  final Map<String, dynamic>? sessionData; 

  const ResultPage({
    super.key,
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
    if (score == 0) return 'Pending AI Analysis ⏳';
    if (score >= 90) return 'Excellent 🎉';
    if (score >= 75) return 'Good 👍';
    if (score >= 60) return 'Fair 😐';
    return 'Needs Work 📈';
  }

  // --- Format date and time from ISO string ---
  String _formatDateTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) {
      return 'Date Unknown';
    }
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
    final int overallScore = (data['overallScore'] ?? 0).toInt();
    final int paceScore = (data['paceScore'] ?? 0).toInt();
    final int clarityScore = (data['clarityScore'] ?? 0).toInt();
    final int energyScore = (data['energyScore'] ?? 0).toInt();
    final String createdAt = data['createdAt'] ?? '';

    final Color overallColor = _getScoreColor(overallScore);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
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
                  GestureDetector(
                    onTap: onPracticeAgain ?? onBackToHome,
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                        Text('Back', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- Date and Time Display ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(createdAt),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
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
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        Text(
                          overallScore.toString(),
                          style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: overallColor),
                        ),
                        const SizedBox(height: 4),
                        const Text('Overall Score', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: overallColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getScoreLabel(overallScore),
                            style: TextStyle(color: overallColor, fontWeight: FontWeight.bold, fontSize: 14),
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
                  const Text('Performance Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 16),

                  _buildMetricCard(
                    icon: Icons.volume_up_outlined,
                    title: 'Pace',
                    subtitle: '$wpmDisplay words per minute',
                    score: paceScore,
                    feedback: paceScore == 0 ? 'Awaiting AI Analysis...' : 'Good pacing. Try to maintain consistency.',
                  ),
                  const SizedBox(height: 16),

                  _buildMetricCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'Clarity',
                    subtitle: '$fillerDisplay filler words detected',
                    score: clarityScore,
                    feedback: clarityScore == 0 ? 'Awaiting AI Analysis...' : 'Minimal filler words. Keep it up.',
                  ),
                  const SizedBox(height: 16),

                  _buildMetricCard(
                    icon: Icons.bolt,
                    title: 'Energy',
                    subtitle: 'Vocal projection and emotion',
                    score: energyScore,
                    feedback: energyScore == 0 ? 'Awaiting AI Analysis...' : 'Good energy level.',
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: AppTheme.backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: onPracticeAgain ?? onBackToHome, 
                      child: const Text('Practice Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3F7CF4), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: onBackToHome,
                      child: const Text('Back to Home', style: TextStyle(color: Color(0xFF3F7CF4), fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int score,
    required String feedback,
  }) {
    final Color scoreColor = _getScoreColor(score);
    final double progressValue = (score / 100.0).clamp(0.0, 1.0); 

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scoreColor.withOpacity(0.15),
                child: Icon(icon, color: scoreColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                score.toString(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scoreColor),
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
          Row(
            children: [
              Icon(score == 0 ? Icons.hourglass_empty : Icons.check, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(child: Text(feedback, style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }
}