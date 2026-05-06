import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; 
import 'result_page.dart'; 
import 'script_practice_page.dart';
import 'time_challenge_page.dart';

class ProgressPage extends StatefulWidget {
  final String userId;
  final VoidCallback onStartPractice; 

  const ProgressPage({
    super.key, 
    required this.userId,
    required this.onStartPractice,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  bool _isLoading = true;
  List<dynamic> _realSessions = [];
  Set<int> _activeDays = {}; 

  bool _isEnglishSelected = true;
  bool _isBarChart = true;

  bool _showPace = true;
  bool _showClarity = true;
  bool _showEnergy = true;

  int? _tooltipDayIndex;

  int _englishOverall = 0;
  List<Map<String, dynamic>> _englishSkills = [
    {'label': 'Pace', 'score': 0, 'value': 0.0},
    {'label': 'Clarity', 'score': 0, 'value': 0.0},
    {'label': 'Energy', 'score': 0, 'value': 0.0},
  ];

  int _filipinoOverall = 0;
  List<Map<String, dynamic>> _filipinoSkills = [
    {'label': 'Pace', 'score': 0, 'value': 0.0},
    {'label': 'Clarity', 'score': 0, 'value': 0.0},
    {'label': 'Energy', 'score': 0, 'value': 0.0},
  ];

  List<double?> _dailyScores = [null, null, null, null, null, null, null];
  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<double?> _paceScores    = [null, null, null, null, null, null, null];
  List<double?> _clarityScores = [null, null, null, null, null, null, null];
  List<double?> _energyScores  = [null, null, null, null, null, null, null];

  // Per-language daily chart data
  List<double?> _englishDailyScores = [null, null, null, null, null, null, null];
  List<double?> _englishPaceScores = [null, null, null, null, null, null, null];
  List<double?> _englishClarityScores = [null, null, null, null, null, null, null];
  List<double?> _englishEnergyScores = [null, null, null, null, null, null, null];

  List<double?> _filipinoDailyScores = [null, null, null, null, null, null, null];
  List<double?> _filipinoPaceScores = [null, null, null, null, null, null, null];
  List<double?> _filipinoClarityScores = [null, null, null, null, null, null, null];
  List<double?> _filipinoEnergyScores = [null, null, null, null, null, null, null];

  static const Color _paceColor    = Color(0xFF3F7CF4);
  static const Color _clarityColor = Color(0xFF4CAF50);
  static const Color _energyColor  = Color(0xFFF5A623);

  @override
  void initState() {
    super.initState();
    _fetchUserProgress();
  }

  Future<void> _fetchUserProgress() async {
    try {
      debugPrint('Progress: Fetching data for userId=${widget.userId} from ${ApiConfig.baseUrl}');
      final url = Uri.parse('${ApiConfig.baseUrl}/stats/${widget.userId}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      debugPrint('Progress: response status=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> sessions = data['sessions'] ?? [];

        // Split sessions by language ---
        final List<dynamic> englishSessions = sessions.where((s) => (s['language'] ?? 'English') == 'English').toList();
        final List<dynamic> filipinoSessions = sessions.where((s) => (s['language'] ?? 'English') == 'Filipino').toList();

        // Compute per-language skill averages ---
        _computeLanguageStats(englishSessions, isEnglish: true);
        _computeLanguageStats(filipinoSessions, isEnglish: false);

        // Compute weekly chart data (uses ALL sessions for activity dots, selected language for chart) ---
        Set<int> newActiveDays = {};
        DateTime now = DateTime.now();
        DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

        // Track active days from ALL sessions (both languages)
        for (var session in sessions) {
          if (session['createdAt'] != null) {
            DateTime date = DateTime.parse(session['createdAt']).toLocal();
            if (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek)) {
              newActiveDays.add(date.weekday);
            }
          }
        }

        // Compute daily chart data for EACH language separately
        final engDaily = _computeDailyData(englishSessions, startOfWeek);
        final filDaily = _computeDailyData(filipinoSessions, startOfWeek);

        setState(() {
          _activeDays = newActiveDays;
          _realSessions = sessions.reversed.toList();

          // Store both sets of daily data and show based on selected language
          _englishDailyScores = engDaily['overall']!;
          _englishPaceScores = engDaily['pace']!;
          _englishClarityScores = engDaily['clarity']!;
          _englishEnergyScores = engDaily['energy']!;

          _filipinoDailyScores = filDaily['overall']!;
          _filipinoPaceScores = filDaily['pace']!;
          _filipinoClarityScores = filDaily['clarity']!;
          _filipinoEnergyScores = filDaily['energy']!;

          _updateChartForSelectedLanguage();

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Progress ERROR: $e");
      debugPrint("Progress ERROR type: ${e.runtimeType}");
      setState(() => _isLoading = false);
    }
  }

  void _computeLanguageStats(List<dynamic> sessions, {required bool isEnglish}) {
    if (sessions.isEmpty) {
      if (isEnglish) {
        _englishOverall = 0;
        _englishSkills = [
          {'label': 'Pace', 'score': 0, 'value': 0.0},
          {'label': 'Clarity', 'score': 0, 'value': 0.0},
          {'label': 'Energy', 'score': 0, 'value': 0.0},
        ];
      } else {
        _filipinoOverall = 0;
        _filipinoSkills = [
          {'label': 'Pace', 'score': 0, 'value': 0.0},
          {'label': 'Clarity', 'score': 0, 'value': 0.0},
          {'label': 'Energy', 'score': 0, 'value': 0.0},
        ];
      }
      return;
    }

    double totalPace = 0, totalClarity = 0, totalEnergy = 0, totalOverall = 0;
    for (var session in sessions) {
      totalPace += (session['paceScore'] ?? 0).toDouble();
      totalClarity += (session['clarityScore'] ?? 0).toDouble();
      totalEnergy += (session['energyScore'] ?? 0).toDouble();
      totalOverall += (session['overallScore'] ?? 0).toDouble();
    }

    int avgPace = (totalPace / sessions.length).round();
    int avgClarity = (totalClarity / sessions.length).round();
    int avgEnergy = (totalEnergy / sessions.length).round();
    int avgOverall = (totalOverall / sessions.length).round();

    if (isEnglish) {
      _englishOverall = avgOverall;
      _englishSkills = [
        {'label': 'Pace', 'score': avgPace, 'value': avgPace / 100},
        {'label': 'Clarity', 'score': avgClarity, 'value': avgClarity / 100},
        {'label': 'Energy', 'score': avgEnergy, 'value': avgEnergy / 100},
      ];
    } else {
      _filipinoOverall = avgOverall;
      _filipinoSkills = [
        {'label': 'Pace', 'score': avgPace, 'value': avgPace / 100},
        {'label': 'Clarity', 'score': avgClarity, 'value': avgClarity / 100},
        {'label': 'Energy', 'score': avgEnergy, 'value': avgEnergy / 100},
      ];
    }
  }

  Map<String, List<double?>> _computeDailyData(List<dynamic> sessions, DateTime startOfWeek) {
    List<double?> weeklyAverages = [null, null, null, null, null, null, null];
    List<double?> weeklyPace = [null, null, null, null, null, null, null];
    List<double?> weeklyClarity = [null, null, null, null, null, null, null];
    List<double?> weeklyEnergy = [null, null, null, null, null, null, null];

    Map<int, List<double>> dayScores = {};
    Map<int, List<double>> dayPace = {};
    Map<int, List<double>> dayClarity = {};
    Map<int, List<double>> dayEnergy = {};

    for (var session in sessions) {
      if (session['createdAt'] != null) {
        DateTime date = DateTime.parse(session['createdAt']).toLocal();

        double pace = (session['paceScore'] ?? 0).toDouble();
        double clarity = (session['clarityScore'] ?? 0).toDouble();
        double energy = (session['energyScore'] ?? 0).toDouble();
        double overall = (session['overallScore'] ?? 0).toDouble();

        if (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek)) {
          int weekdayIndex = date.weekday - 1;

          dayScores.putIfAbsent(weekdayIndex, () => []).add(overall);
          dayPace.putIfAbsent(weekdayIndex, () => []).add(pace);
          dayClarity.putIfAbsent(weekdayIndex, () => []).add(clarity);
          dayEnergy.putIfAbsent(weekdayIndex, () => []).add(energy);
        }
      }
    }

    dayScores.forEach((day, scores) {
      weeklyAverages[day] = scores.reduce((a, b) => a + b) / scores.length;
      weeklyPace[day] = dayPace[day]!.reduce((a, b) => a + b) / dayPace[day]!.length;
      weeklyClarity[day] = dayClarity[day]!.reduce((a, b) => a + b) / dayClarity[day]!.length;
      weeklyEnergy[day] = dayEnergy[day]!.reduce((a, b) => a + b) / dayEnergy[day]!.length;
    });

    return {
      'overall': weeklyAverages,
      'pace': weeklyPace,
      'clarity': weeklyClarity,
      'energy': weeklyEnergy,
    };
  }

  void _updateChartForSelectedLanguage() {
    if (_isEnglishSelected) {
      _dailyScores = _englishDailyScores;
      _paceScores = _englishPaceScores;
      _clarityScores = _englishClarityScores;
      _energyScores = _englishEnergyScores;
    } else {
      _dailyScores = _filipinoDailyScores;
      _paceScores = _filipinoPaceScores;
      _clarityScores = _filipinoClarityScores;
      _energyScores = _filipinoEnergyScores;
    }
  }


  Color _barColor(double score) {
    if (score == 0) return Colors.grey.shade400; 
    if (score >= 85) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFFFFC107);
    if (score >= 50) return const Color(0xFFFF9800);
    return const Color(0xFFEF4444);
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return "Unknown Date";
    try {
      final date = DateTime.parse(isoDate).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return "Recent";
    }
  }

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
void _routeToSpecificPractice(BuildContext context, Map<String, dynamic> session) {
  // Now this will work because backend populates the objects!
  final challengeData = session['challengeId']; 
  if (challengeData != null && challengeData is Map) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TimedChallengePage(challenge: challengeData, userId: widget.userId)
    ));
    return;
  }
  
  final scriptData = session['resourceId'];
  if (scriptData != null && scriptData is Map) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScriptPracticePage(script: scriptData, userId: widget.userId)
    ));
    return;
  }
  
  // Fallback
  widget.onStartPractice(); // Fallback
}
 

  @override
  Widget build(BuildContext context) {
    final isEnglish = _isEnglishSelected;
    final overall = isEnglish ? _englishOverall : _filipinoOverall;
    final skills = isEnglish ? _englishSkills : _filipinoSkills;
    final accentColor = isEnglish ? const Color(0xFF3F7CF4) : const Color(0xFFF5A623);
    final bgColor = isEnglish ? const Color(0xFFF0F4FF) : const Color(0xFFFFF8EE);

    final double topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: GestureDetector(
          onTap: () => setState(() => _tooltipDayIndex = null),
          child: RefreshIndicator(
            onRefresh: _fetchUserProgress,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(24, topPadding + 20, 24, 32),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Progress', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            SizedBox(height: 8),
                            Text('Track your improvement over time', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
      
                      const SizedBox(height: 20),
                      _buildWeeklySummary(accentColor),
                      const SizedBox(height: 20),
      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Performance Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const SizedBox(height: 20),
                              _perfRow('Pace', _getTrendSubtitle('Pace', skills), (skills[0]['value'] as double), '${skills[0]['score']}%', accentColor), 
                              const SizedBox(height: 18),
                              _perfRow('Clarity', _getTrendSubtitle('Clarity', skills), (skills[1]['value'] as double), '${skills[1]['score']}%', accentColor),
                              const SizedBox(height: 18),
                              _perfRow('Energy', _getTrendSubtitle('Energy', skills), (skills[2]['value'] as double), '${skills[2]['score']}%', accentColor),
                            ],
                          ),
                        ),
                      ),
      
                      const SizedBox(height: 20),
                      _buildSkillsBreakdown(accentColor, bgColor, isEnglish, skills, overall),
                      const SizedBox(height: 20),
                      _buildDailyChart(accentColor),
                      const SizedBox(height: 20),
      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Session History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 14),
                            
                            if (_isLoading)
                              const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                            else if (_realSessions.isEmpty)
                              const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No sessions recorded yet.")))
                            else
                              
                            ..._realSessions.asMap().entries.map((entry) {
                              int index = entry.key;
                              var session = entry.value;
                              
                              int score = (session['overallScore'] ?? 0).toInt();
                              String dateStr = _formatDate(session['createdAt']);
                              String timeStr = _formatSessionTime(session['createdAt']);  // NEW

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _historyCard(
                                  'Session #${_realSessions.length - index}', 
                                  dateStr,
                                  timeStr,  // NEW: Pass the time
                                  '$score', 
                                  accentColor,
                                  () {
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
                                    ).then((_) => _fetchUserProgress());
                                  }
                                ),
                              );
                            }).toList(),  
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
    );
  }

  Widget _buildWeeklySummary(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activity This Week', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              '${_activeDays.length} Active Days',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: accentColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(7, (index) {
                const labels = ['M', 'T', 'W', 'TH', 'F', 'ST', 'S'];
                final bool done = _activeDays.contains(index + 1); 
                return Expanded(
                  child: Column(
                    children: [
                      Text(labels[index], style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: done ? accentColor : Colors.grey.shade100,
                        child: done ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsBreakdown(Color accentColor, Color bgColor, bool isEnglish, List skills, int overall) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Skills Breakdown', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _toggleBtn('English', _isEnglishSelected, const Color(0xFF3F7CF4), () => setState(() { _isEnglishSelected = true; _updateChartForSelectedLanguage(); })),
                      _toggleBtn('Filipino', !_isEnglishSelected, const Color(0xFFF5A623), () => setState(() { _isEnglishSelected = false; _updateChartForSelectedLanguage(); })),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars_rounded, color: accentColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isEnglish ? 'ENGLISH SCORE' : 'FILIPINO SCORE',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$overall%', style: TextStyle(color: accentColor, fontSize: 48, fontWeight: FontWeight.w900)),
                  const Text('Overall Performance', style: TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...skills.map((skill) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(skill['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${skill['score']}%', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _styledTooltip(
                      message: '${skill['label']}\nScore: ${skill['score']}%',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: skill['value'] as double,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          minHeight: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Performance Per Day', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _toggleBtn('Bar', _isBarChart, accentColor, () => setState(() { _isBarChart = true; _tooltipDayIndex = null; })),
                      _toggleBtn('Line', !_isBarChart, accentColor, () => setState(() => _isBarChart = false)),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isBarChart) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _metricChip('Pace', _showPace, _paceColor, () => setState(() => _showPace = !_showPace)),
                  const SizedBox(width: 8),
                  _metricChip('Clarity', _showClarity, _clarityColor, () => setState(() => _showClarity = !_showClarity)),
                  const SizedBox(width: 8),
                  _metricChip('Energy', _showEnergy, _energyColor, () => setState(() => _showEnergy = !_showEnergy)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: _isBarChart ? _buildBarChart() : _buildLineChart(),
            ),
            const SizedBox(height: 24),
            Text(
              _isBarChart ? 'Performance Rating' : 'Metrics',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _isBarChart
                ? Wrap(
                    spacing: 16, runSpacing: 8,
                    children: [
                      _legendItem(const Color(0xFF4CAF50), 'Excellent (85+)'),
                      _legendItem(const Color(0xFFFFC107), 'Good (70-84)'),
                      _legendItem(const Color(0xFFFF9800), 'Fair (50-69)'),
                      _legendItem(const Color(0xFFEF4444), 'Needs Work (<50)'),
                      _legendItem(Colors.grey.shade400, 'Pending Data'),
                    ],
                  )
                : Wrap(
                    spacing: 16, runSpacing: 8,
                    children: [
                      _legendItem(_paceColor, 'Pace'),
                      _legendItem(_clarityColor, 'Clarity'),
                      _legendItem(_energyColor, 'Energy'),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _styledTooltip({required String message, required Widget child}) {
    return Tooltip(
      message: message,
      preferBelow: false,
      verticalOffset: 14,
      triggerMode: TooltipTriggerMode.tap, 
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );
  }

  Widget _buildBarChart() {
    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['100', '75', '50', '25', '0'].map((e) => Text(e, style: const TextStyle(fontSize: 11, color: Colors.grey))).toList(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final score = _dailyScores[i];
              final hasSession = score != null;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _styledTooltip(
                      message: hasSession ? '${_dayLabels[i]}\nScore: ${score.toStringAsFixed(1)}' : '${_dayLabels[i]}\nNo Session',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: hasSession ? ((score == 0 ? 5 : score) / 100) * 140 : 10,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: hasSession ? _barColor(score) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_dayLabels[i], style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    final series = <_MetricSeries>[];
    if (_showPace)    series.add(_MetricSeries('Pace',    _paceScores,    _paceColor));
    if (_showClarity) series.add(_MetricSeries('Clarity', _clarityScores, _clarityColor));
    if (_showEnergy)  series.add(_MetricSeries('Energy',  _energyScores,  _energyColor));

    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['100', '75', '50', '25', '0'].map((e) => Text(e, style: const TextStyle(fontSize: 11, color: Colors.grey))).toList(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              const chartHeight = 140.0;
              const labelHeight = 22.0;
              final segmentWidth = chartWidth / 7;

              return SizedBox(
                height: chartHeight + labelHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0, left: 0, right: 0, height: chartHeight,
                      child: Stack(
                        children: List.generate(5, (i) {
                          final y = (i / 4) * chartHeight;
                          return Positioned(top: y, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade100));
                        }),
                      ),
                    ),
                    // LINE LAYER — draws connecting lines between data points
                    ...series.map((m) {
                      final pts = <MapEntry<int, double>>[];
                      for (int i = 0; i < m.scores.length; i++) {
                        if (m.scores[i] != null) pts.add(MapEntry(i, m.scores[i]!));
                      }
                      final offsets = pts.map((e) => Offset(e.key * segmentWidth + segmentWidth / 2, chartHeight - (e.value / 100) * chartHeight)).toList();
                      return Positioned(
                        top: 0, left: 0, width: chartWidth, height: chartHeight,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: Size(chartWidth, chartHeight),
                            painter: _MultiLinePainter(points: offsets, color: m.color),
                          ),
                        ),
                      );
                    }),
                    // DOT LAYER — draws circles on each data point (on top of lines)
                    ...series.map((m) {
                      final pts = <MapEntry<int, double>>[];
                      for (int i = 0; i < m.scores.length; i++) {
                        if (m.scores[i] != null) pts.add(MapEntry(i, m.scores[i]!));
                      }
                      return Positioned(
                        top: 0, left: 0, width: chartWidth, height: chartHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: pts.map((entry) {
                            final x = entry.key * segmentWidth + segmentWidth / 2;
                            final y = chartHeight - (entry.value / 100) * chartHeight;
                            return Positioned(
                              left: x - 6, top: y - 6,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: m.color, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                    ...List.generate(7, (i) {
                      final x = i * segmentWidth;
                      final isSelected = _tooltipDayIndex == i;
                      final entries = series.where((m) => m.scores[i] != null).map((m) => _TooltipEntry(m.label, m.color, m.scores[i]!)).toList();
                      const tooltipWidth = 130.0;
                      double tooltipLeft = x + segmentWidth / 2 - tooltipWidth / 2;
                      tooltipLeft = tooltipLeft.clamp(0.0, chartWidth - tooltipWidth);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0, left: x, width: segmentWidth, height: chartHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() { _tooltipDayIndex = isSelected ? null : i; }),
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          if (isSelected && entries.isNotEmpty)
                            Positioned(
                              top: -10, left: tooltipLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: tooltipWidth,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E2E),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_dayLabels[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      ...entries.map((e) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(
                                              children: [
                                                Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                                                const SizedBox(width: 6),
                                                Expanded(child: Text(e.label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                                Text(e.score.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                    Positioned(
                      top: chartHeight + 6, left: 0, width: chartWidth,
                      child: Row(
                        children: List.generate(7, (i) {
                          return SizedBox(
                            width: segmentWidth,
                            child: Center(
                              child: Text(_dayLabels[i], style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(4),
            border: color == Colors.grey.shade200 ? Border.all(color: Colors.grey.shade300) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _toggleBtn(String label, bool active, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getTrendSubtitle(String metric, List skills) {
    int index = metric == 'Pace' ? 0 : metric == 'Clarity' ? 1 : 2;
    int score = skills[index]['score'] as int;
    if (score == 0) return 'No data yet — start practicing!';
    if (score >= 85) return 'Excellent $metric performance';
    if (score >= 70) return 'Good $metric — keep improving';
    if (score >= 50) return '$metric needs more practice';
    return '$metric needs significant work';
  }

  Widget _perfRow(String title, String subtitle, double value, String change, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Text(change, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        _styledTooltip(
          message: '$title\nProgress: ${(value * 100).toInt()}%  $change',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value, backgroundColor: accentColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor), minHeight: 10,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _historyCard(String title, String date, String time, String score, Color accentColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(score, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: accentColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipEntry {
  final String label;
  final Color color;
  final double score;
  const _TooltipEntry(this.label, this.color, this.score);
}

class _MetricSeries {
  final String label;
  final List<double?> scores;
  final Color color;
  const _MetricSeries(this.label, this.scores, this.color);
}

class _MultiLinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  _MultiLinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      // Draw a filled circle for a single data point
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, 5, dotPaint);
      return;
    }

    // Use drawLine for each segment — more reliable on Impeller/Vulkan
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_MultiLinePainter old) => true;
}