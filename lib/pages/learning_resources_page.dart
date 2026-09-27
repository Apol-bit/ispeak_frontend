import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/resource_icon.dart';
import '../widgets/loading_skeleton.dart';
import 'dart:convert';
import '../services/resource_access.dart';
import '../widgets/fixed_back_layout.dart';
import 'package:ispeak/config/api_config.dart';
import 'package:ispeak/services/api_client.dart';
import 'package:ispeak/pages/time_challenge_page.dart';
import 'package:ispeak/pages/script_practice_page.dart';

enum _Tab { scripts, challenges, guidedTasks }

List<dynamic> resourcesInDisplayOrder(Iterable<dynamic> source) {
  final rows = source.toList();
  final original = <Object?, int>{
    for (var index = 0; index < rows.length; index++)
      (rows[index] as Map)['_id']: index,
  };
  rows.sort((first, second) {
    final firstMap = first as Map;
    final secondMap = second as Map;
    final firstOrder = firstMap['displayOrder'];
    final secondOrder = secondMap['displayOrder'];
    if (firstOrder is num && secondOrder is num) {
      return firstOrder.compareTo(secondOrder);
    }
    // Legacy rows retain the deterministic order supplied by the API. New
    // resources have an order after the legacy group until it is first saved.
    if (firstOrder is num) return 1;
    if (secondOrder is num) return -1;
    return original[firstMap['_id']]!.compareTo(original[secondMap['_id']]!);
  });
  return rows;
}

class LearningResourcesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final String userId;
  final bool isActive;
  final int refreshKey;

  const LearningResourcesScreen({
    super.key,
    required this.userId,
    this.onBack,
    this.isActive = true,
    this.refreshKey = 0,
  });

  @override
  State<LearningResourcesScreen> createState() =>
      _LearningResourcesScreenState();
}

class _LearningResourcesScreenState extends State<LearningResourcesScreen>
    with WidgetsBindingObserver {
  _Tab _activeTab = _Tab.scripts;
  bool _isLoading = true;
  String? _error;
  String? _levelError;
  List<dynamic> _resources = [];
  late final ResourceFilters _filters = ResourceFilters(widget.userId);
  bool _restored = false;
  int _request = 0;

  List<dynamic> _ofType(String type) => resourcesInDisplayOrder(
    _resources.where(
      (resource) =>
          resource['type'] == type && _filters.matches(resource as Map),
    ),
  );
  List<dynamic> get _scripts => _ofType('Script');
  List<dynamic> get _challenges => _ofType('Challenge');
  List<dynamic> get _guidedTasks => _ofType('GuidedTask');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) _fetchResourcesFromBackend();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(LearningResourcesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        (!oldWidget.isActive || oldWidget.refreshKey != widget.refreshKey)) {
      _fetchResourcesFromBackend();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _fetchResourcesFromBackend();
    }
  }

  Future<void> _fetchResourcesFromBackend() async {
    final request = ++_request;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/resources'),
      );
      if (response.statusCode != 200) throw StateError('Resources unavailable');
      final resources = jsonDecode(response.body) as List;
      String? levelError;
      try {
        final level = await ResourceAccess.fetchCurrentLevel(widget.userId);
        if (!mounted || request != _request) return;
        if (_restored) {
          await _filters.updateCurrentLevel(level);
        } else {
          await _filters.restore(level);
          _restored = true;
        }
      } catch (_) {
        levelError =
            'Unable to load resources and verify your level. Please try again.';
      }
      if (!mounted || request != _request) return;
      setState(() {
        _resources = resources;
        _levelError = levelError;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _isLoading = false;
        _error =
            'Unable to load resources and verify your level. Please try again.';
      });
    }
  }

  Future<void> _openResource(Map resource, Widget page) async {
    if (resource['type'] == 'GuidedTask') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      if (mounted) await _fetchResourcesFromBackend();
      return;
    }
    // Revalidate at entry as well as on return/resume, including demotions.
    setState(() => _isLoading = true);
    try {
      final level = await ResourceAccess.fetchCurrentLevel(widget.userId);
      await _filters.updateCurrentLevel(level);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final difficulty = ResourceAccess.parseLevel(resource['difficulty']);
      if (difficulty == null || !ResourceAccess.allows(level, difficulty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResourceAccess.lockedMessage(difficulty ?? 'These')),
          ),
        );
        return;
      }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      if (mounted) await _fetchResourcesFromBackend();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to verify your current level. Please try again.',
          ),
        ),
      );
    }
  }

  // Helper to map Database string to your Flutter Enum
  ChallengeDifficulty _mapDifficulty(String? dbDifficulty) {
    if (dbDifficulty == 'Intermediate') return ChallengeDifficulty.intermediate;
    if (dbDifficulty == 'Advanced') return ChallengeDifficulty.advanced;
    return ChallengeDifficulty.beginner; // Default
  }

  // Helper to map Database icons
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: AppTheme.resourceBlue,
        secondary: AppTheme.resourceBlue,
        secondaryContainer: AppTheme.resourceBlue.withValues(alpha: 0.12),
        onSecondaryContainer: AppTheme.resourceBlue,
        surfaceTint: Colors.transparent,
      ),
      highlightColor: AppTheme.resourceBlue.withValues(alpha: 0.12),
      splashColor: AppTheme.resourceBlue.withValues(alpha: 0.12),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: FixedBackLayout(
        onBack: widget.onBack,
        child: RefreshIndicator(
          onRefresh: _fetchResourcesFromBackend,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF3F7CF4),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learning Resources',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Improve your speaking skills',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tabBar(),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final language in ResourceAccess.languages)
                            ChoiceChip(
                              selectedColor: AppTheme.resourceBlue.withValues(
                                alpha: 0.12,
                              ),
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.transparent,
                              checkmarkColor: AppTheme.resourceBlue,
                              labelStyle: TextStyle(
                                color: _filters.selectedLanguage == language
                                    ? AppTheme.resourceBlue
                                    : AppTheme.bodyInk,
                              ),
                              side: BorderSide(
                                color: _filters.selectedLanguage == language
                                    ? AppTheme.resourceBlue
                                    : const Color(0xFFD1D5DB),
                              ),
                              label: Text(language),
                              selected: _filters.selectedLanguage == language,
                              onSelected: (_) => setState(
                                () => _filters.selectedLanguage = language,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_activeTab != _Tab.guidedTasks &&
                          (!_isLoading || _resources.isNotEmpty))
                        PopupMenuButton<String>(
                          key: const ValueKey('level-filter'),
                          color: AppTheme.menuSurfaceOf(context),
                          surfaceTintColor: Colors.transparent,
                          initialValue: _filters.selectedLevel,
                          enabled:
                              !_isLoading &&
                              _error == null &&
                              _levelError == null,
                          tooltip: 'Filter by level',
                          onSelected: (level) async {
                            final selected = await _filters.selectLevel(level);
                            if (!context.mounted) return;
                            if (!selected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ResourceAccess.lockedMessage(level),
                                  ),
                                ),
                              );
                            } else {
                              setState(() {});
                            }
                          },
                          itemBuilder: (_) => [
                            for (final level in ResourceAccess.levels)
                              PopupMenuItem(
                                value: level,
                                child: Row(
                                  children: [
                                    if (level == _filters.selectedLevel) ...[
                                      const Icon(
                                        Icons.check,
                                        color: AppTheme.resourceBlue,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        level,
                                        style: TextStyle(
                                          color: level == _filters.selectedLevel
                                              ? AppTheme.resourceBlue
                                              : AppTheme.menuTextOf(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      ResourceAccess.allows(
                                            _filters.currentLevel,
                                            level,
                                          )
                                          ? 'Available'
                                          : 'Locked',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            ResourceAccess.allows(
                                              _filters.currentLevel,
                                              level,
                                            )
                                            ? AppTheme.resourceBlue
                                            : Colors.grey,
                                      ),
                                    ),
                                    if (!ResourceAccess.allows(
                                      _filters.currentLevel,
                                      level,
                                    )) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.lock_outline,
                                        size: 16,
                                        color: AppTheme.menuTextOf(context),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Level: ${_filters.selectedLevel}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.resourceBlue,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: AppTheme.resourceBlue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isLoading && _resources.isEmpty)
                        const SkeletonList(count: 3)
                      else if (_error != null ||
                          (_activeTab != _Tab.guidedTasks &&
                              _levelError != null)) ...[
                        Text(_error ?? _levelError!),
                        TextButton(
                          onPressed: _fetchResourcesFromBackend,
                          child: const Text('Try Again'),
                        ),
                      ] else ...[
                        _subTitle(),
                        const SizedBox(height: 14),
                        if (_activeTab == _Tab.scripts) ..._buildScriptCards(),
                        if (_activeTab == _Tab.challenges)
                          ..._buildChallengeCards(),
                        if (_activeTab == _Tab.guidedTasks)
                          ..._buildGuidedTaskCards(),
                      ],
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
        return const Text(
          'Choose a script to practice with',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        );
      case _Tab.challenges:
        return const Text(
          'Test your skills with timed challenges',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        );
      case _Tab.guidedTasks:
        return const Text(
          'Step-by-step exercises to improve your skills',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        );
    }
  }

  // ── DYNAMIC BUILDERS ──────────────────────────────────────────────────────────────

  List<Widget> _buildScriptCards() {
    if (_scripts.isEmpty) {
      return [_buildEmptyState('scripts')];
    }

    return _scripts.map((scriptData) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ScriptCard(
          title: scriptData['title'] ?? 'Unknown',
          description: scriptData['description'] ?? '',
          duration: '${scriptData['estimatedMinutes'] ?? 0} min',
          difficulty: _mapDifficulty(scriptData['difficulty']),
          language: scriptData['language'] ?? 'English',
          onTap: () => _openResource(
            scriptData,
            ScriptDetailPage(
              script: scriptData,
              userId: widget.userId,
              onBackToHome: widget.onBack,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildChallengeCards() {
    if (_challenges.isEmpty) {
      return [_buildEmptyState('challenges')];
    }

    return _challenges.map((challengeData) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ChallengeCard(
          title: challengeData['title'] ?? 'Unknown',
          description: challengeData['description'] ?? '',
          durationSeconds: challengeData['timeLimitSeconds'] ?? 60,
          difficulty: _mapDifficulty(challengeData['difficulty']),
          targetWpm:
              (challengeData['targetMetric']?.toString().trim().isNotEmpty ??
                  false)
              ? challengeData['targetMetric'].toString()
              : '120-150 WPM',
          language: challengeData['language'],
          onTap: () => _openResource(
            challengeData,
            TimedChallengePage(
              challenge: challengeData,
              userId: widget.userId,
              onBackToHome: widget.onBack,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildGuidedTaskCards() {
    if (_guidedTasks.isEmpty) {
      return [_buildEmptyState('guided tasks')];
    }

    return _guidedTasks.map((taskData) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _GuidedTaskCard(
          title: taskData['title'] ?? 'Unknown',
          steps: (taskData['steps'] as List?)?.length ?? 0,
          durationMin: taskData['estimatedMinutes'] ?? 5,
          category: taskData['category'] ?? 'General',
          icon: ResourceIcon.resolve(taskData['iconName']),
          language: taskData['language']?.toString() ?? '',
          onTap: () =>
              _openResource(taskData, GuidedTaskDetailPage(task: taskData)),
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState(String contentType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              _activeTab == _Tab.guidedTasks
                  ? 'No guided tasks yet'
                  : 'No ${_filters.selectedLevel} $contentType yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back later — more content\nfor your level is on the way!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
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
    required this.title,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.language,
    this.onTap,
  });

  Color get _difficultyColor {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:
        return const Color(0xFF3FBD7A);
      case ChallengeDifficulty.intermediate:
        return const Color(0xFF3F7CF4);
      case ChallengeDifficulty.advanced:
        return const Color(0xFFB45FD4);
    }
  }

  Color get _difficultyBg {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:
        return const Color(0xFFDFF5E8);
      case ChallengeDifficulty.intermediate:
        return const Color(0xFFE6EEFF);
      case ChallengeDifficulty.advanced:
        return const Color(0xFFF3E6FF);
    }
  }

  String get _difficultyLabel {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:
        return 'Beginner';
      case ChallengeDifficulty.intermediate:
        return 'Intermediate';
      case ChallengeDifficulty.advanced:
        return 'Advanced';
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _difficultyBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _difficultyLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _difficultyColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          language,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right, color: Colors.grey, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Guided Task Card ─────────────────────────────────────────────────────────
class _GuidedTaskCard extends StatelessWidget {
  final String title;
  final String language;
  final int steps;
  final int durationMin;
  final String category;
  final IconData icon;
  final VoidCallback? onTap;

  const _GuidedTaskCard({
    required this.title,
    required this.language,
    required this.steps,
    required this.durationMin,
    required this.category,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE6EEFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF3F7CF4), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$steps steps • $durationMin min',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    language,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3F7CF4),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EEFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F7CF4),
                      ),
                    ),
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
  final String language;
  final String description;
  final int durationSeconds;
  final ChallengeDifficulty difficulty;
  final String targetWpm;
  final VoidCallback? onTap;

  const _ChallengeCard({
    required this.title,
    required this.language,
    required this.description,
    required this.durationSeconds,
    required this.difficulty,
    required this.targetWpm,
    this.onTap,
  });

  Color get _difficultyColor {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:
        return const Color(0xFF3FBD7A);
      case ChallengeDifficulty.intermediate:
        return const Color(0xFF3F7CF4);
      case ChallengeDifficulty.advanced:
        return const Color(0xFFB45FD4);
    }
  }

  Color get _difficultyBg {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:
        return const Color(0xFFDFF5E8);
      case ChallengeDifficulty.intermediate:
        return const Color(0xFFE6EEFF);
      case ChallengeDifficulty.advanced:
        return const Color(0xFFF3E6FF);
    }
  }

  String get _difficultyLabel {
    switch (difficulty) {
      case ChallengeDifficulty.beginner:
        return 'Beginner';
      case ChallengeDifficulty.intermediate:
        return 'Intermediate';
      case ChallengeDifficulty.advanced:
        return 'Advanced';
    }
  }

  String get _formattedDuration => '${durationSeconds}s';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formattedDuration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _difficultyBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_difficultyLabel | $language',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _difficultyColor,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speed,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Target: $targetWpm',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3F7CF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.adjust, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GUIDED TASK DETAIL PAGE (NOW 100% CONSISTENT WITH OTHER SCREENS)
// ═════════════════════════════════════════════════════════════════════════════

class GuidedTaskDetailPage extends StatelessWidget {
  final dynamic task;

  const GuidedTaskDetailPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final String proTip = task['proTip'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: SafeArea(
          top: false, // Edge-to-edge support to match others
          bottom: true,
          child: FixedBackLayout(
            onBack: null,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                    child: Column(
                      children: [
                        _buildStepGuideCard(),
                        if (proTip.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildProTipCard(proTip),
                        ],
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

  Widget _buildHeader(BuildContext context) {
    final title = task['title'] ?? 'Guided Task';
    final category = task['category'] ?? 'General';
    final duration = '${task['estimatedMinutes'] ?? 0} min';

    const double topPadding = 0;

    return Container(
      width: double.infinity,
      // EXACT SAME PADDING AS SCRIPT & CHALLENGE HEADERS
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF3F7CF4),
        // NO BORDER RADIUS - Perfectly flat and straight
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$category • $duration',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8), // Extra padding for breathing room
        ],
      ),
    );
  }

  Widget _buildStepGuideCard() {
    final List<dynamic> steps = task['steps'] ?? [];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: Color(0xFF3F7CF4), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Step-by-Step Guide',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (steps.isEmpty)
            const Text(
              "No steps provided.",
              style: TextStyle(color: Colors.grey),
            ),
          ...steps.asMap().entries.map(
            (e) => _buildStepRow(e.key + 1, e.value.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF3F7CF4),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTipCard(String proTip) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Pro Tip',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F7CF4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            proTip,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
