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
    if (score >= 90) return const Color(0xFF3FBD7A); 
    if (score >= 75) return const Color(0xFF3F7CF4); 
    if (score >= 60) return const Color(0xFFF5A623); 
    return const Color(0xFFEF4444);                  
  }

  String _getScoreLabel(num score) {
    if (score >= 90) return 'Excellent 🎉';
    if (score >= 75) return 'Good 👍';
    if (score >= 60) return 'Fair 😐';
    return 'Needs Work 📈';
  }

  @override
  Widget build(BuildContext context) {
    final data = sessionData ?? {};

    // Map exact variables from MongoDB Schema
    final int wpmDisplay = (data['wpmScore'] ?? 126).toInt();
    final int fillerDisplay = (data['fillerWordCount'] ?? 1).toInt();
    final int energyDisplay = (data['energyScore'] ?? 72).toInt();

    // Calculate a 1-100 score for WPM (Assuming ~150 is optimal)
    double wpmScoreVal = (data['wpmScore'] != null) ? (data['wpmScore'] / 2.0).clamp(0.0, 100.0) : 85.0;

    // TODO: Implement real clarity score calculation
    // double clarityVal = data['clarityScore'] != null ? data['clarityScore'].toDouble() : 0.0;
    // final int overallScore = ((wpmScoreVal + energyDisplay + clarityVal) / 3).round();
    
    // Overall average
    final int overallScore = ((wpmScoreVal + energyDisplay + 90.0) / 3).round();
    final Color overallColor = _getScoreColor(overallScore);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF3F7CF4),
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onBackToHome,
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                        Text('Back to Home', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
                    score: wpmScoreVal.toInt(),
                    feedback: 'Good pacing. Try to maintain consistency throughout.',
                  ),
                  const SizedBox(height: 16),

                  _buildMetricCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'Clarity',
                    subtitle: '$fillerDisplay filler words detected',
                    score: fillerDisplay <= 3 ? 95 : 70, // Logic: Fewer fillers = higher score
                    feedback: 'Minimal filler words. Watch for "um" and "uh".',
                  ),
                  const SizedBox(height: 16),

                  _buildMetricCard(
                    icon: Icons.bolt,
                    title: 'Energy',
                    subtitle: 'Vocal projection and emotion',
                    score: energyDisplay,
                    feedback: 'Good energy level.',
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
                      // If onPracticeAgain is null, act like "Back" just to prevent crash
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
              const Icon(Icons.check, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(child: Text(feedback, style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }
}