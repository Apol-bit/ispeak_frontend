import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'learning_resources_page.dart';
import '../config/api_config.dart'; 
import 'profile_screen.dart';
import 'result_page.dart';
import 'script_practice_page.dart';
import 'time_challenge_page.dart';

class DashBoardPage extends StatefulWidget {
  final VoidCallback onStartPractice;
  final VoidCallback onLearningResources;
  final String userId;

  const DashBoardPage({
    super.key,
    required this.onStartPractice,
    required this.onLearningResources,
    required this.userId, 
  });
  
  @override
  State<DashBoardPage> createState() => _DashBoardPageState();
}

class _DashBoardPageState extends State<DashBoardPage> {
  bool _isLoading = true;
  Map<String, dynamic> _userStats = {
    'totalSessions': 0,
    'avgScore': 0,
    'dayStreak': 0, 
  };
  List<dynamic> _recentSessionsList = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Color _getScoreColor(dynamic scoreValue) {
    final double score = double.tryParse(scoreValue.toString()) ?? 0;
    if (score == 0) return Colors.grey; 
    if (score >= 90) return const Color(0xFF3FBD7A); 
    if (score >= 75) return const Color(0xFF3F7CF4);
    if (score >= 60) return const Color(0xFFF5A623); 
    return const Color(0xFFEF4444);
  }

  Future<void> _fetchDashboardData() async {
    try {
      final statsRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/stats/${widget.userId}'));
      final historyRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/sessions/${widget.userId}'));

      if (statsRes.statusCode == 200) {
        final data = jsonDecode(statsRes.body);
        final overallStats = data['overallStats'] ?? {};
        final sessions = data['sessions'] as List<dynamic>? ?? [];
        
        Set<DateTime> uniqueDays = {};
        for (var s in sessions) {
          if (s['createdAt'] != null) {
            DateTime d = DateTime.parse(s['createdAt']).toLocal();
            uniqueDays.add(DateTime(d.year, d.month, d.day)); 
          }
        }

        List<DateTime> sortedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
        DateTime today = DateTime.now();
        today = DateTime(today.year, today.month, today.day);

        int currentStreak = 0;
        if (sortedDays.isNotEmpty) {
          DateTime lastActive = sortedDays.first;
          if (today.difference(lastActive).inDays <= 1) {
            currentStreak = 1;
            DateTime expectedDay = lastActive.subtract(const Duration(days: 1));

            for (int i = 1; i < sortedDays.length; i++) {
              if (sortedDays[i] == expectedDay) {
                currentStreak++;
                expectedDay = expectedDay.subtract(const Duration(days: 1));
              } else {
                break;
              }
            }
          }
        }

        int overallScore = (overallStats['avgScore'] ?? 0).toInt();
        _userStats = {
          'totalSessions': overallStats['totalSessions'] ?? 0,
          'avgScore': overallScore,
          'dayStreak': currentStreak, 
        };
      }

      if (historyRes.statusCode == 200) {
        _recentSessionsList = jsonDecode(historyRes.body);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error fetching data: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- SMART ROUTER ADDED HERE ---
  void _routeToSpecificPractice(BuildContext context, Map<String, dynamic> session) {
    // 1. Check if the session data contains a populated Challenge object
    final challengeData = session['challenge'] ?? session['challengeData'];
    if (challengeData != null && challengeData is Map) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TimedChallengePage(challenge: challengeData, userId: widget.userId)));
      return;
    }
    
    // 2. Check if the session data contains a populated Script object
    final scriptData = session['script'] ?? session['resource'] ?? session['scriptData'];
    if (scriptData != null && scriptData is Map) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ScriptPracticePage(script: scriptData, userId: widget.userId)));
      return;
    }
    
    // 3. Fallback: If it's a freestyle session or the backend didn't send the full object, go to main practice tab
    widget.onStartPractice();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading 
      ? const Center(child: CircularProgressIndicator()) 
      : RefreshIndicator(
          onRefresh: _fetchDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _headerWithOverlappingCard(context),
                const SizedBox(height: 60), 
                _startPracticeButton(),
                const SizedBox(height: 12),
                _learningResourcesButton(context),
                const SizedBox(height: 20),
                _recentSessions(),
                const SizedBox(height: 120), 
              ],
            ),
          ),
        );
  }

  Widget _headerWithOverlappingCard(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: double.infinity,
          height: 180 + topPadding, 
          padding: EdgeInsets.fromLTRB(20, topPadding + 15, 20, 20),
          decoration: const BoxDecoration(color: Color(0xFF3F7CF4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('iSpeak', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Improve your public speaking', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId))),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_outline, color: Color(0xFF3F7CF4), size: 28),
                ),
              ),
            ],
          ),
        ),
        
        Positioned(
          bottom: -40, 
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  value: _userStats['totalSessions'].toString(), 
                  label: 'Sessions',
                  valueColor: const Color(0xFF3F7CF4),
                ),
                const _VerticalDivider(),
                _StatItem(
                  value: (_userStats['avgScore'] ?? 0).toString(),
                  label: 'Avg Score',
                  valueColor: _getScoreColor(_userStats['avgScore'] ?? 0),
                ),
                const _VerticalDivider(),
                _StatItem(
                  value: (_userStats['dayStreak'] ?? 0).toString(), 
                  label: 'Day Streak',
                  valueColor: const Color(0xFF3F7CF4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _startPracticeButton() {
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => widget.onStartPractice(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF3F7CF4),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start Practice', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('English & Filipino supported', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _learningResourcesButton(BuildContext context) {
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LearningResourcesScreen(
          userId: widget.userId,
          onBack: () => Navigator.of(context).pop()
        ))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3F7CF4), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, color: Color(0xFF3F7CF4), size: 20),
              SizedBox(width: 8),
              Text('Learning Resources', style: TextStyle(color: Color(0xFF3F7CF4), fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentSessions() {
    if (_recentSessionsList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text("No sessions yet. Start practicing!", style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._recentSessionsList.map((session) {
            String rawDate = session['createdAt'] ?? '';
            String shortDate = rawDate.isNotEmpty ? rawDate.substring(0, 10) : 'Unknown Date';
            int score = (session['overallScore'] ?? 0).toInt();

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ResultPage(
                    sessionData: session,
                    onBackToHome: () => Navigator.pop(context),
                    onPracticeAgain: () {
                      Navigator.pop(context); // Pops the Result Page
                      _routeToSpecificPractice(context, session); // SMART ROUTER APPLIED HERE
                    }
                  ))
                ).then((_) => _fetchDashboardData());
              },
              child: _SessionCard(
                date: shortDate,
                score: score.toString(),
                pace: '${session['paceScore'] ?? 0}%', 
                clarity: '${session['clarityScore'] ?? 0}%',
                energy: '${session['energyScore'] ?? 0}%',
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _StatItem({required this.value, required this.label, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: valueColor)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();
  @override
  Widget build(BuildContext context) => Container(height: 40, width: 1, color: Colors.grey[300]);
}

class _SessionCard extends StatelessWidget {
  final String date;
  final String score;
  final String pace;
  final String clarity;
  final String energy;

  const _SessionCard({required this.date, required this.score, required this.pace, required this.clarity, required this.energy});
  
  Color get _scoreColor {
    final s = int.tryParse(score) ?? 0;
    if (s == 0) return Colors.grey;
    if (s >= 90) return const Color(0xFF3FBD7A);
    if (s >= 75) return const Color(0xFF3F7CF4);
    if (s >= 60) return const Color(0xFFF5A623);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54)),
              Text(score, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _scoreColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric(label: 'Pace', value: pace),
              _Metric(label: 'Clarity', value: clarity), 
              _Metric(label: 'Energy', value: energy),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}