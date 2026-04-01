import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ispeak/config/api_config.dart';
import 'package:ispeak/pages/time_challenge_page.dart';

enum _Tab { scripts, challenges, guidedTasks }

class LearningResourcesScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const LearningResourcesScreen({super.key, this.onBack});

  @override
  State<LearningResourcesScreen> createState() =>
      _LearningResourcesScreenState();
}

class _LearningResourcesScreenState extends State<LearningResourcesScreen> {
  _Tab _activeTab = _Tab.scripts;

  // --- BACKEND STATE VARIABLES ---
  bool _isLoading = true;
  List<dynamic> _scripts = [];
  List<dynamic> _challenges = [];
  List<dynamic> _guidedTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchResourcesFromBackend();
  }

  // --- THE BACKEND BRIDGE ---
  Future<void> _fetchResourcesFromBackend() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/resources');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> allResources = json.decode(response.body);

        setState(() {
          _scripts = allResources.where((r) => r['type'] == 'Script').toList();
          _challenges = allResources.where((r) => r['type'] == 'Challenge').toList();
          _guidedTasks = allResources.where((r) => r['type'] == 'GuidedTask').toList();
          _isLoading = false;
        });
      } else {
        print('Failed to load resources. Status: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error connecting to backend: $e');
      setState(() => _isLoading = false);
    }
  }

  // Helper to map Database string to your Flutter Enum
  ChallengeDifficulty _mapDifficulty(String? dbDifficulty) {
    if (dbDifficulty == 'Intermediate') return ChallengeDifficulty.intermediate;
    if (dbDifficulty == 'Advanced') return ChallengeDifficulty.advanced;
    return ChallengeDifficulty.beginner; // Default
  }

  // Helper to map Database icons
  IconData _mapIcon(String? iconName) {
    if (iconName == 'chat_bubble_outline') return Icons.chat_bubble_outline;
    if (iconName == 'access_time') return Icons.access_time;
    if (iconName == 'bolt') return Icons.bolt;
    if (iconName == 'person_outline') return Icons.person_outline;
    return Icons.volume_up; // Default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Material(
        color: const Color(0xFFF2F4F7),
        child: SafeArea(
          bottom: true,
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F7CF4)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _tabBar(),
                              const SizedBox(height: 20),
                              _subTitle(),
                              const SizedBox(height: 14),
                              
                              // Dynamically rendering from backend data
                              if (_activeTab == _Tab.scripts) ..._buildScriptCards(),
                              if (_activeTab == _Tab.challenges) ..._buildChallengeCards(),
                              if (_activeTab == _Tab.guidedTasks) ..._buildGuidedTaskCards(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
      decoration: const BoxDecoration(color: Color(0xFF3F7CF4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 20),
                Text('Back', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Learning Resources',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Improve your speaking skills',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          _tabItem('Scripts', _Tab.scripts),
          _tabItem('Challenges', _Tab.challenges),
          _tabItem('Guided Tasks', _Tab.guidedTasks),
        ],
      ),
    );
  }

  Widget _tabItem(String label, _Tab tab) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3F7CF4) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _subTitle() {
    switch (_activeTab) {
      case _Tab.scripts:
        return const Text('Choose a script to practice with', style: TextStyle(fontSize: 13, color: Colors.grey));
      case _Tab.challenges:
        return const Text('Test your skills with timed challenges', style: TextStyle(fontSize: 13, color: Colors.grey));
      case _Tab.guidedTasks:
        return const Text('Step-by-step exercises to improve your skills', style: TextStyle(fontSize: 13, color: Colors.grey));
    }
  }

  // ── DYNAMIC BUILDERS ──────────────────────────────────────────────────────────────

  List<Widget> _buildScriptCards() {
    if (_scripts.isEmpty) return [const Text("No scripts available.")];
    
    return _scripts.map((scriptData) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ScriptCard(
          title: scriptData['title'] ?? 'Unknown',
          description: scriptData['description'] ?? '',
          duration: '${scriptData['estimatedMinutes'] ?? 0} min',
          difficulty: _mapDifficulty(scriptData['difficulty']),
          language: scriptData['language'] ?? 'English',
          onTap: () {
            // TODO: Connect this to ScriptDetailPage later
            print("Tapped script: ${scriptData['title']}");
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildChallengeCards() {
    if (_challenges.isEmpty) return [const Text("No challenges available.")];

    return _challenges.map((challengeData) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ChallengeCard(
          title: challengeData['title'] ?? 'Unknown',
          description: challengeData['description'] ?? '',
          durationSeconds: challengeData['timeLimitSeconds'] ?? 60,
          difficulty: _mapDifficulty(challengeData['difficulty']),
          targetWpm: challengeData['targetMetric'] ?? '120 WPM',
          onTap: () {
            // TODO: Connect this to TimedChallengePage later
            print("Tapped challenge: ${challengeData['title']}");
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildGuidedTaskCards() {
    if (_guidedTasks.isEmpty) return [const Text("No tasks available.")];

    return _guidedTasks.map((taskData) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _GuidedTaskCard(
          title: taskData['title'] ?? 'Unknown',
          steps: (taskData['steps'] as List?)?.length ?? 0,
          durationMin: taskData['estimatedMinutes'] ?? 5,
          category: taskData['category'] ?? 'General',
          icon: _mapIcon(taskData['iconName']),
          onTap: () {
            // FINISHED: Opening the detail page and passing the MongoDB JSON!
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GuidedTaskDetailPage(task: taskData)),
            );
          },
        ),
      );
    }).toList();
  }
}

// ─── Script Card ──────────────────────────────────────────────────────────────
class _ScriptCard extends StatelessWidget {
  final String title;
  final String description;
  final String duration;
  final ChallengeDifficulty difficulty;
  final String language;
  final VoidCallback? onTap;

  const _ScriptCard({
    required this.title, required this.description, required this.duration,
    required this.difficulty, required this.language, this.onTap,
  });

  Color get _difficultyColor {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:     return const Color(0xFF3FBD7A);
      case ChallengeDifficulty.intermediate: return const Color(0xFF3F7CF4);
      case ChallengeDifficulty.advanced:     return const Color(0xFFB45FD4);
    }
  }

  Color get _difficultyBg {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:     return const Color(0xFFDFF5E8);
      case ChallengeDifficulty.intermediate: return const Color(0xFFE6EEFF);
      case ChallengeDifficulty.advanced:     return const Color(0xFFF3E6FF);
    }
  }

  String get _difficultyLabel {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:     return 'Beginner';
      case ChallengeDifficulty.intermediate: return 'Intermediate';
      case ChallengeDifficulty.advanced:     return 'Advanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 5),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(duration, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: _difficultyBg, borderRadius: BorderRadius.circular(20)),
                        child: Text(_difficultyLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _difficultyColor)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                        child: Text(language, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.chevron_right, color: Colors.grey, size: 22)),
          ],
        ),
      ),
    );
  }
}

// ─── Guided Task Card ─────────────────────────────────────────────────────────
class _GuidedTaskCard extends StatelessWidget {
  final String title;
  final int steps;
  final int durationMin;
  final String category;
  final IconData icon;
  final VoidCallback? onTap;

  const _GuidedTaskCard({
    required this.title, required this.steps, required this.durationMin,
    required this.category, required this.icon, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFFE6EEFF), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF3F7CF4), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 3),
                  Text('$steps steps • $durationMin min', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE6EEFF), borderRadius: BorderRadius.circular(20)),
                    child: Text(category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3F7CF4))),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Challenge Card ───────────────────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  final String title;
  final String description;
  final int durationSeconds;
  final ChallengeDifficulty difficulty;
  final String targetWpm;
  final VoidCallback? onTap;

  const _ChallengeCard({
    required this.title, required this.description, required this.durationSeconds,
    required this.difficulty, required this.targetWpm, this.onTap,
  });

  Color get _difficultyColor {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:     return const Color(0xFF3FBD7A);
      case ChallengeDifficulty.intermediate: return const Color(0xFF3F7CF4);
      case ChallengeDifficulty.advanced:     return const Color(0xFFB45FD4);
    }
  }

  Color get _difficultyBg {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:     return const Color(0xFFDFF5E8);
      case ChallengeDifficulty.intermediate: return const Color(0xFFE6EEFF);
      case ChallengeDifficulty.advanced:     return const Color(0xFFF3E6FF);
    }
  }

  String get _difficultyLabel {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:     return 'Beginner';
      case ChallengeDifficulty.intermediate: return 'Intermediate';
      case ChallengeDifficulty.advanced:     return 'Advanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 5),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${durationSeconds}s', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: _difficultyBg, borderRadius: BorderRadius.circular(20)),
                        child: Text(_difficultyLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _difficultyColor)),
                      ),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.speed, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('Target: $targetWpm', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF3F7CF4), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.adjust, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GUIDED TASK DETAIL PAGE (NOW POWERED BY MONGODB JSON)
// ═════════════════════════════════════════════════════════════════════════════

class GuidedTaskDetailPage extends StatelessWidget {
  // Changed from `GuidedTaskData` to `dynamic` so it can accept the raw JSON map
  final dynamic task;

  const GuidedTaskDetailPage({super.key, required this.task});

  static const _kPrimary      = Color(0xFF3F7CF4);
  static const _kPrimaryLight = Color(0xFFE6EEFF);
  static const _kTextDark     = Color(0xFF1A1A2E);
  static const _kBgGrey       = Color(0xFFF2F4F7);

  @override
  Widget build(BuildContext context) {
    // Extract the proTip securely. If there's no proTip in the database, we handle it.
    final String proTip = task['proTip'] ?? '';

    return Scaffold(
      backgroundColor: _kBgGrey,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  _buildStepGuideCard(),
                  if (proTip.isNotEmpty) _buildProTipCard(proTip), // Only show if data exists
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Pulling directly from your backend JSON keys
    final title = task['title'] ?? 'Guided Task';
    final category = task['category'] ?? 'General';
    final duration = task['estimatedMinutes'] ?? 0;

    return Container(
      color: _kPrimary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 22,
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: Colors.white70, size: 20),
                SizedBox(width: 2),
                Text('Back', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$category • $duration min',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStepGuideCard() {
    // Cast the JSON array into a Flutter List
    final List<dynamic> steps = task['steps'] ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: _kPrimary, size: 20),
              SizedBox(width: 8),
              Text('Step-by-Step Guide',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
            ],
          ),
          const SizedBox(height: 16),
          // Loop through the MongoDB steps array
          if (steps.isEmpty) const Text("No steps provided.", style: TextStyle(color: Colors.grey)),
          ...steps.asMap().entries.map((e) => _buildStepRow(e.key + 1, e.value.toString())),
        ],
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$number',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF333333), height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTipCard(String proTip) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber[600], size: 18),
              const SizedBox(width: 6),
              const Text('Pro Tip',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2A5BD7))),
            ],
          ),
          const SizedBox(height: 8),
          Text(proTip,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), height: 1.5)),
        ],
      ),
    );
  }
}