import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'learning_resources_page.dart';
import '../config/api_config.dart'; 
import '../config/responsive.dart';
import 'profile_screen.dart';
import 'result_page.dart';
import 'script_practice_page.dart';
import 'time_challenge_page.dart';

class DashBoardPage extends StatefulWidget {
  final VoidCallback onStartPractice;
  final VoidCallback onLearningResources;
  final String userId;
  final int refreshKey;

  const DashBoardPage({
    super.key,
    required this.onStartPractice,
    required this.onLearningResources,
    required this.userId, 
    this.refreshKey = 0,
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

  // Level system state
  String _userLevel = 'Beginner';         // current/initial level
  int _practiceCount = 0;                  // total completed sessions
  bool _levelLocked = false;               // true once >= 10 practices done

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void didUpdateWidget(DashBoardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _fetchDashboardData();
    }
  }

  Color _getScoreColor(dynamic scoreValue) {
    final double score = double.tryParse(scoreValue.toString()) ?? 0;
    if (score == 0) return Colors.grey; 
    if (score >= 90) return const Color(0xFF3FBD7A); 
    if (score >= 75) return const Color(0xFF3F7CF4);
    if (score >= 60) return const Color(0xFFF5A623); 
    return const Color(0xFFEF4444);
  }

  // --- NEW: Format session creation time ---
  String _formatSessionTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Unknown Time';
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = (hour > 12) ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } catch (e) {
      return 'Unknown Time';
    }
  }

  Future<void> _fetchDashboardData() async {
    try {
      debugPrint('Dashboard: Fetching data for userId=${widget.userId} from ${ApiConfig.baseUrl}');
      final statsRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/stats/${widget.userId}')).timeout(const Duration(seconds: 10));
      final historyRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/sessions/${widget.userId}')).timeout(const Duration(seconds: 10));
      final profileRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/user/${widget.userId}')).timeout(const Duration(seconds: 10));
      debugPrint('Dashboard: statsRes=${statsRes.statusCode}, historyRes=${historyRes.statusCode}, profileRes=${profileRes.statusCode}');

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
        int totalSessions = overallStats['totalSessions'] ?? 0;
        
        _userStats = {
          'totalSessions': totalSessions,
          'avgScore': overallScore,
          'dayStreak': currentStreak, 
        };
        _practiceCount = totalSessions;
        debugPrint('Dashboard Stats: totalSessions=$totalSessions, avgScore=$overallScore, dayStreak=$currentStreak');
      }

      if (historyRes.statusCode == 200) {
        _recentSessionsList = jsonDecode(historyRes.body);
        debugPrint('Recent sessions count: ${_recentSessionsList.length}');
      }

      // Fetch level info from user profile
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        final int totalSessions = _userStats['totalSessions'] ?? 0;

        if (totalSessions >= 10) {
          // Official level based on average score
          _levelLocked = true;
          final int avgScore = _userStats['avgScore'] ?? 0;
          _userLevel = _scoreToLevel(avgScore);
        } else {
          // Use the demographic initial level stored in the backend
          _levelLocked = false;
          _userLevel = profileData['level'] ?? profileData['initialLevel'] ?? 'Beginner';
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Dashboard ERROR: $e");
      debugPrint("Dashboard ERROR type: ${e.runtimeType}");
      setState(() => _isLoading = false);
    }
  }

  /// Converts an average score to a level string
  String _scoreToLevel(int avgScore) {
    if (avgScore >= 80) return 'Advanced';
    if (avgScore >= 60) return 'Intermediate';
    return 'Beginner';
  }

  // --- FIXED SMART ROUTER ---
  void _routeToSpecificPractice(BuildContext context, Map<String, dynamic> session) {
    // Now this will work because backend populates the objects!
    final challengeData = session['challengeId']; 
    if (challengeData != null && challengeData is Map) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TimedChallengePage(challenge: challengeData, userId: widget.userId)
      )).then((_) => _fetchDashboardData());
      return;
    }
    
    final scriptData = session['resourceId'];
    if (scriptData != null && scriptData is Map) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScriptPracticePage(script: scriptData, userId: widget.userId)
      )).then((_) => _fetchDashboardData());
      return;
    }
    
    // Fallback
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
                SizedBox(height: Responsive(context).h(60)), 
                _levelStatusCard(context),
                SizedBox(height: Responsive(context).h(12)),
                _startPracticeButton(context),
                SizedBox(height: Responsive(context).h(12)),
                _learningResourcesButton(context),
                SizedBox(height: Responsive(context).h(20)),
                _recentSessions(context),
                SizedBox(height: Responsive(context).h(120)), 
              ],
            ),
          ),
        );
  }

  Widget _headerWithOverlappingCard(BuildContext context) {
    final r = Responsive(context);
    final double topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.22 + topPadding, 
          padding: EdgeInsets.fromLTRB(r.w(20), topPadding + r.h(15), r.w(20), r.h(20)),
          decoration: const BoxDecoration(color: Color(0xFF3F7CF4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('iSpeak', style: TextStyle(color: Colors.white, fontSize: r.sp(30), fontWeight: FontWeight.bold)),
                    SizedBox(height: r.h(4)),
                    Text('Improve your public speaking', style: TextStyle(color: Colors.white70, fontSize: r.sp(13))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId))),
                child: CircleAvatar(
                  radius: r.w(24),
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_outline, color: const Color(0xFF3F7CF4), size: r.icon(28)),
                ),
              ),
            ],
          ),
        ),
        
        Positioned(
          bottom: -r.h(40), 
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            padding: r.padHV(12, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: r.radius(16),
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

  // ─── Level Status Card (Phase 2) ────────────────────────────────────────────
  Widget _levelStatusCard(BuildContext context) {
    final r = Responsive(context);
    const int targetPractices = 10;
    final int done = _practiceCount.clamp(0, targetPractices);
    final double progress = done / targetPractices;

    Color levelColor;
    IconData levelIcon;
    switch (_userLevel) {
      case 'Advanced':
        levelColor = const Color(0xFFB45FD4);
        levelIcon = Icons.emoji_events_outlined;
        break;
      case 'Intermediate':
        levelColor = const Color(0xFF3F7CF4);
        levelIcon = Icons.trending_up;
        break;
      default:
        levelColor = const Color(0xFF3FBD7A);
        levelIcon = Icons.spa_outlined;
    }

    return Padding(
      padding: r.padH(20),
      child: Container(
        width: double.infinity,
        padding: r.pad(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: r.radius(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: _levelLocked
            ? _buildLockedLevel(context, levelColor, levelIcon)
            : _buildEvaluationProgress(context, done, targetPractices, progress, levelColor, levelIcon),
      ),
    );
  }

  Widget _buildLockedLevel(BuildContext context, Color levelColor, IconData levelIcon) {
    final r = Responsive(context);
    return Row(
      children: [
        Container(
          width: r.w(50),
          height: r.w(50),
          decoration: BoxDecoration(
            color: levelColor.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(levelIcon, color: levelColor, size: r.icon(26)),
        ),
        SizedBox(width: r.w(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Level', style: TextStyle(fontSize: r.sp(12), color: Colors.grey)),
              SizedBox(height: r.h(2)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _userLevel,
                  style: TextStyle(fontSize: r.sp(20), fontWeight: FontWeight.bold, color: levelColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationProgress(
    BuildContext context, int done, int total, double progress, Color levelColor, IconData levelIcon) {
    final r = Responsive(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: r.w(46),
              height: r.w(46),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top_rounded, color: const Color(0xFFF5A623), size: r.icon(24)),
            ),
            SizedBox(width: r.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Evaluating Level',
                        style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(fontSize: r.sp(14), fontWeight: FontWeight.bold, color: const Color(0xFFF5A623)),
                      ),
                    ],
                  ),
                  SizedBox(height: r.h(2)),
                  Text(
                    '$done/$total Practices Completed',
                    style: TextStyle(fontSize: r.sp(12), color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: r.h(12)),
        ClipRRect(
          borderRadius: r.radius(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: r.h(8),
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5A623)),
          ),
        ),
        SizedBox(height: r.h(10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: r.padOnly(top: 2),
              child: Icon(Icons.info_outline, size: r.icon(13), color: Colors.grey.shade400),
            ),
            SizedBox(width: r.w(6)),
            Expanded(
              child: Text(
                'Initial level: $_userLevel · Official level unlocks after $total practices',
                style: TextStyle(fontSize: r.sp(11.5), color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _startPracticeButton(BuildContext context) {
    final r = Responsive(context);
     return Padding(
      padding: r.padH(20),
      child: GestureDetector(
        onTap: () => widget.onStartPractice(),
        child: Container(
          width: double.infinity,
          padding: r.padHV(16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF3F7CF4),
            borderRadius: r.radius(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, color: Colors.white, size: r.icon(26)),
              SizedBox(width: r.w(10)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start Practice', style: TextStyle(color: Colors.white, fontSize: r.sp(16), fontWeight: FontWeight.bold)),
                  SizedBox(height: r.h(2)),
                  Text('English & Filipino supported', style: TextStyle(color: Colors.white70, fontSize: r.sp(12))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _learningResourcesButton(BuildContext context) {
    final r = Responsive(context);
     return Padding(
      padding: r.padH(20),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LearningResourcesScreen(
          userId: widget.userId,
          onBack: () => Navigator.of(context).pop()
        ))),
        child: Container(
          width: double.infinity,
          padding: r.padHV(16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: r.radius(16),
            border: Border.all(color: const Color(0xFF3F7CF4), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, color: const Color(0xFF3F7CF4), size: r.icon(20)),
              SizedBox(width: r.w(8)),
              Text('Learning Resources', style: TextStyle(color: const Color(0xFF3F7CF4), fontSize: r.sp(15), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentSessions(BuildContext context) {
    final r = Responsive(context);
    if (_recentSessionsList.isEmpty) {
      return Padding(
        padding: r.pad(40),
        child: Text("No sessions yet. Start practicing!", style: TextStyle(color: Colors.grey, fontSize: r.sp(13))),
      );
    }

    return Padding(
      padding: r.padH(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Sessions', style: TextStyle(fontSize: r.sp(18), fontWeight: FontWeight.bold)),
          SizedBox(height: r.h(12)),
          ..._recentSessionsList.map((session) {
            String rawDate = session['createdAt'] ?? '';
            String shortDate = rawDate.isNotEmpty ? rawDate.substring(0, 10) : 'Unknown Date';
            
            // NEW: Format the creation time
            String createdTime = _formatSessionTime(rawDate);
            
            int score = (session['overallScore'] ?? 0).toInt();

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ResultPage(
                    sessionData: session,
                    onBackToHome: () => Navigator.pop(context),
                    onPracticeAgain: () {
                      Navigator.pop(context);
                      _routeToSpecificPractice(context, session);
                    }
                  ))
                ).then((_) => _fetchDashboardData());
              },
              child: _SessionCard(
                date: shortDate,
                createdTime: createdTime,
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
  final String createdTime;  // NEW
  final String score;
  final String pace;
  final String clarity;
  final String energy;

  const _SessionCard({
    required this.date,
    required this.createdTime,  // NEW
    required this.score,
    required this.pace,
    required this.clarity,
    required this.energy,
  });
  
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
              Expanded(
                child: Column(  // NEW: Wrap date in column to add time below
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(createdTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
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