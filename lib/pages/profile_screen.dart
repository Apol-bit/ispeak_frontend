import '../widgets/fixed_back_layout.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import 'editprofile_screen.dart';
import 'login_screen.dart';
import '../services/api_client.dart';
import '../models/performance_statistics.dart';
import '../services/auth_service.dart';
import '../services/resource_access.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String firstName = "";
  String lastName = "";
  String username = "Loading...";
  String userEmail = "Loading...";
  String userInitials = "";

  int sessions = 0;
  int avgScore = 0;
  bool _hasAverage = false;
  String? _currentLevel;
  int dayStreak = 0;

  int? userAge;
  String userGender = "";
  String userGradeLevel = "";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // The real name leads; the username is secondary. Status text such as
  // "Loading..." or "Network Error" is shown as the title on its own.
  bool get _hasAccount =>
      !_isLoading && userInitials != '!' && username != 'Unknown User';

  String get _displayName {
    final fullName = '$firstName $lastName'.trim();
    return _hasAccount && fullName.isNotEmpty ? fullName : username;
  }

  String get _handle =>
      _hasAccount && _displayName != username ? '@$username' : '';

  Color _getScoreColor(int score) {
    if (score == 0) return Colors.grey;
    if (score >= 85) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFFFFC107);
    if (score >= 50) return const Color(0xFFFF9800);
    return const Color(0xFFEF4444);
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint(
        'Profile: Fetching data for userId=${widget.userId} from ${ApiConfig.baseUrl}',
      );
      final userRes = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/user/${widget.userId}'),
      );
      final statsRes = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/stats/${widget.userId}?view=compact'),
      );
      debugPrint(
        'Profile: userRes=${userRes.statusCode}, statsRes=${statsRes.statusCode}',
      );

      Map? profile;
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        if (userData is Map) profile = userData;

        firstName = userData['firstName'] ?? "";
        lastName = userData['lastName'] ?? "";
        username = userData['username'] ?? "Unknown User";
        userEmail = userData['email'] ?? "No email provided";

        userAge = userData['age'];
        userGender = userData['gender'] ?? "";
        userGradeLevel = userData['gradeLevel'] ?? "";

        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          userInitials = '${firstName[0]}${lastName[0]}'.toUpperCase();
        } else if (username != "Unknown User") {
          userInitials = username[0].toUpperCase();
        } else {
          userInitials = "?";
        }
      } else {
        username = "User Not Found";
        userEmail = "Server returned ${userRes.statusCode}";
        userInitials = "!";
      }

      if (statsRes.statusCode == 200) {
        final statsData = jsonDecode(statsRes.body);
        final overallStats = statsData['overallStats'] ?? {};
        final sessionsList = performanceSessions(statsData);

        // FIX: Properly extract totalSessions from overallStats
        sessions = overallStats['totalSessions'] ?? 0;
        final average = performanceAverage(overallStats);
        avgScore = average?.toInt() ?? 0;
        _hasAverage = average != null;
        // Same rule as Home and Progress, so the guide marks the same level.
        if (profile != null && overallStats is Map) {
          _currentLevel = ResourceAccess.currentLevel(profile, overallStats);
        }

        // --- TRUE CONTINUOUS STREAK ALGORITHM ---
        Set<DateTime> uniqueDays = {};
        for (var s in sessionsList) {
          if (s['createdAt'] != null) {
            DateTime d = DateTime.parse(s['createdAt']).toLocal();
            uniqueDays.add(DateTime(d.year, d.month, d.day));
          }
        }

        List<DateTime> sortedDays = uniqueDays.toList()
          ..sort((a, b) => b.compareTo(a));
        DateTime today = DateTime.now();
        today = DateTime(today.year, today.month, today.day);

        dayStreak = 0;

        if (sortedDays.isNotEmpty) {
          DateTime lastActive = sortedDays.first;

          if (today.difference(lastActive).inDays <= 1) {
            dayStreak = 1;
            DateTime expectedDay = lastActive.subtract(const Duration(days: 1));

            for (int i = 1; i < sortedDays.length; i++) {
              if (sortedDays[i] == expectedDay) {
                dayStreak++;
                expectedDay = expectedDay.subtract(const Duration(days: 1));
              } else {
                break;
              }
            }
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Profile ERROR: $e");
      debugPrint("Profile ERROR type: ${e.runtimeType}");
      setState(() {
        _isLoading = false;
        username = "Network Error";
        userEmail = "Check connection";
        userInitials = "!";
      });
    }
  }

  void _goToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userId: widget.userId,
          firstName: firstName,
          lastName: lastName,
          username: username,
          userEmail: userEmail,
          age: userAge,
          gender: userGender,
          gradeLevel: userGradeLevel,
        ),
      ),
    ).then((value) {
      if (value != null) {
        setState(() => _isLoading = true);
        _loadUserData();
      }
    });
  }

  void _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(15, 18, 28, 0.5),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Log Out',
            style: TextStyle(color: AppTheme.bodyInk),
          ),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.bodyInk),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.logoutRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await AuthService.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FixedBackLayout(
        onBack: null,
        child: SingleChildScrollView(
          child: Stack(
            children: [
              // Fixed band ending behind the avatar on every screen height.
              Container(
                height: 200,
                width: double.infinity,
                color: AppTheme.accentColor,
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Account settings',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),

                      const SizedBox(height: 32),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                (0.08 * 255).round(),
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        userInitials,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              _displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),

                            if (_handle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _handle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],

                            const SizedBox(height: 4),

                            Text(
                              userEmail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        _isLoading ? '-' : '$sessions',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sessions',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        _isLoading || !_hasAverage
                                            ? '-'
                                            : '$avgScore',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _getScoreColor(avgScore),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Avg Score',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        _isLoading ? '-' : '$dayStreak',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Day Streak',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!_isLoading &&
                                (userAge != null ||
                                    userGender.isNotEmpty ||
                                    userGradeLevel.isNotEmpty)) ...[
                              const SizedBox(height: 16),
                              Divider(color: Colors.grey[200], thickness: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (userAge != null)
                                    Expanded(
                                      child: _buildDemographicItem(
                                        'Age',
                                        '$userAge',
                                        Icons.calendar_today_outlined,
                                      ),
                                    ),
                                  if (userGender.isNotEmpty)
                                    Expanded(
                                      child: _buildDemographicItem(
                                        'Gender',
                                        userGender,
                                        Icons.face_outlined,
                                      ),
                                    ),
                                  if (userGradeLevel.isNotEmpty)
                                    Expanded(
                                      child: _buildDemographicItem(
                                        'Grade',
                                        userGradeLevel,
                                        Icons.school_outlined,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      _buildGuideCard(
                        Icons.info_outline,
                        'Score Guide',
                        'Every practice session is scored from 0 to 100.',
                        [
                          _buildScoreScale(),
                          for (final band in _scoreBands)
                            _buildGuideRow(
                              leading: Text(
                                band.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              title: band.label,
                              subtitle: '${band.min}-${band.max} points',
                              color: band.color,
                              tag: _averageBand == band ? 'Your average' : null,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildGuideCard(
                        Icons.stars_outlined,
                        'Level Guide',
                        'Starts from your sign-up details, then follows your '
                            'average score after 10 scored sessions.',
                        [
                          for (final band in _levelBands)
                            _buildGuideRow(
                              leading: Icon(
                                band.icon,
                                color: Colors.white,
                                size: 20,
                              ),
                              title: band.level,
                              subtitle: band.range,
                              color: band.color,
                              tag: !_isLoading && _currentLevel == band.level
                                  ? 'Current'
                                  : null,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildOptionTile(
                        icon: Icons.edit,
                        title: 'Edit Profile',
                        subtitle: 'Update your information',
                        onTap: _goToEditProfile,
                      ),

                      const SizedBox(height: 12),

                      _buildOptionTile(
                        icon: Icons.logout,
                        title: 'Log Out',
                        subtitle: null,
                        onTap: _logout,
                        isLogout: true,
                      ),

                      const SizedBox(height: 24),

                      Center(
                        child: Text(
                          'iSpeak v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Highest band first; colors are unchanged from the original guide.
  static const _scoreBands = [
    (min: 85, max: 100, label: 'Excellent', color: Colors.green, emoji: '🎉'),
    (min: 70, max: 84, label: 'Good', color: Colors.amber, emoji: '👍'),
    (min: 50, max: 69, label: 'Fair', color: Colors.orange, emoji: '💪'),
    (min: 0, max: 49, label: 'Needs Work', color: Colors.red, emoji: '📈'),
  ];

  static const _levelBands = [
    (
      level: 'Advanced',
      range: '80 - 100 average score',
      color: Color(0xFFB45FD4),
      icon: Icons.emoji_events_outlined,
    ),
    (
      level: 'Intermediate',
      range: '60 - 79 average score',
      color: Color(0xFF3F7CF4),
      icon: Icons.trending_up,
    ),
    (
      level: 'Beginner',
      range: '0 - 59 average score',
      color: Color(0xFF3FBD7A),
      icon: Icons.spa_outlined,
    ),
  ];

  ({int min, int max, String label, MaterialColor color, String emoji})?
  get _averageBand => _isLoading || !_hasAverage
      ? null
      : _scoreBands.firstWhere((band) => avgScore >= band.min);

  Widget _buildGuideCard(
    IconData icon,
    String title,
    String description,
    List<Widget> items,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            item,
          ],
        ],
      ),
    );
  }

  // A 0-100 bar split at the band boundaries, with the user's average marked.
  Widget _buildScoreScale() {
    final band = _averageBand;
    final average = band == null ? null : avgScore.clamp(0, 100);
    final textScaler = MediaQuery.textScalerOf(context);
    final labelHeight = textScaler.scale(11) * 1.5;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(num value) => width * value / 100;
        Widget label(num value, String text, TextStyle style) => Positioned(
          left: (at(value) - 32).clamp(0.0, width - 64),
          width: 64,
          child: Text(
            text,
            maxLines: 1,
            textAlign: value == 0
                ? TextAlign.left
                : value == 100
                ? TextAlign.right
                : TextAlign.center,
            style: style,
          ),
        );
        final tickStyle = TextStyle(fontSize: 11, color: Colors.grey[600]);
        // Skip an inner boundary label when narrow screens or large text
        // leave no room for it; 0 and 100 always show.
        final minGap = textScaler.scale(11) * 3.2;
        final ticks = [0];
        for (final value in [50, 70, 85]) {
          if (at(value) - at(ticks.last) >= minGap &&
              at(100) - at(value) >= minGap) {
            ticks.add(value);
          }
        }
        ticks.add(100);
        return Column(
          children: [
            if (average != null)
              SizedBox(
                height: labelHeight,
                width: width,
                child: Stack(
                  children: [
                    label(
                      average,
                      'You · $average',
                      const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 16,
              width: width,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 3,
                    height: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Row(
                        // Childless segments need stretch to get the bar height.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final band in _scoreBands.reversed)
                            Expanded(
                              flex: band.max == 100
                                  ? 100 - band.min
                                  : band.max + 1 - band.min,
                              child: ColoredBox(color: band.color),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (average != null)
                    Positioned(
                      left: (at(average) - 8).clamp(0.0, width - 16),
                      top: 0,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: band!.color, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: labelHeight,
              width: width,
              child: Stack(
                children: [
                  for (final value in ticks) label(value, '$value', tickStyle),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideRow({
    required Widget leading,
    required String title,
    required String subtitle,
    required Color color,
    String? tag,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        // Always reserve the border so highlighting never shifts the layout.
        border: Border.all(
          color: tag != null ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: leading),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The tag sits beside the title and wraps below it when
                // narrow, so the range line keeps the full width.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Material(
      color: isLogout
          ? Colors.red.withAlpha((0.1 * 255).round())
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isLogout ? Colors.red : AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isLogout ? Colors.red : Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              // A chevron implies navigation; logging out is an action.
              if (!isLogout) Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
