import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; 
import '../theme/app_theme.dart';        
import 'editprofile_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int dayStreak = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Color _getScoreColor(int score) {
    if (score == 0) return Colors.grey; 
    if (score >= 85) return const Color(0xFF4CAF50); 
    if (score >= 70) return const Color(0xFFFFC107); 
    if (score >= 50) return const Color(0xFFFF9800); 
    return const Color(0xFFEF4444); 
  }

  Future<void> _loadUserData() async {
    try {
      final userRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/user/${widget.userId}'));
      final statsRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/stats/${widget.userId}'));

      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        
        firstName = userData['firstName'] ?? "";
        lastName = userData['lastName'] ?? "";
        username = userData['username'] ?? "Unknown User";
        userEmail = userData['email'] ?? "No email provided";
        
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
        final sessionsList = statsData['sessions'] as List<dynamic>? ?? [];
        
        // FIX: Properly extract totalSessions from overallStats
        sessions = overallStats['totalSessions'] ?? 0;
        avgScore = (overallStats['avgScore'] ?? 0).toInt();

        // --- TRUE CONTINUOUS STREAK ALGORITHM ---
        Set<DateTime> uniqueDays = {};
        for (var s in sessionsList) {
          if (s['createdAt'] != null) {
            DateTime d = DateTime.parse(s['createdAt']).toLocal();
            uniqueDays.add(DateTime(d.year, d.month, d.day)); 
          }
        }

        List<DateTime> sortedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
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
      debugPrint("Error fetching profile data: $e");
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: 320, 
              width: double.infinity,
              color: AppTheme.accentColor, 
            ),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.chevron_left, color: Colors.white, size: 26),
                          SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70, 
                      ),
                    ),

                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.08 * 255).round()),
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
                                ? const CircularProgressIndicator(color: Colors.white)
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
                            username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _isLoading ? '-' : '$firstName $lastName',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
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
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    _isLoading ? '-' : '$avgScore',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreColor(avgScore), 
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Avg Score',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Column(
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
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Container(
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
                              const Icon(Icons.info_outline, color: AppTheme.accentColor, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Score Guide',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          _buildScoreGuideItem('95', 'Excellent', '85-100 points', Colors.green, '🎉'),
                          const SizedBox(height: 12),
                          _buildScoreGuideItem('76', 'Good', '70-84 points', Colors.amber, '👍'),
                          const SizedBox(height: 12),
                          _buildScoreGuideItem('58', 'Fair', '50-69 points', Colors.orange, '💪'),
                          const SizedBox(height: 12),
                          _buildScoreGuideItem('42', 'Needs Work', '0-49 points', Colors.red, '📈'),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

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
    );
  }

  Widget _buildScoreGuideItem(String score, String label, String range, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              score,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  range,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 18), 
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLogout ? Colors.red.withAlpha((0.1 * 255).round()) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}