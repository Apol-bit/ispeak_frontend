import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_client.dart';

/// The existing proficiency thresholds, shared by Home and resource access.
class ResourceAccess {
  static const levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const languages = ['All', 'English', 'Filipino'];

  static String? parseLevel(Object? value) {
    for (final level in levels) {
      if (level.toLowerCase() == value?.toString().trim().toLowerCase()) {
        return level;
      }
    }
    return null;
  }

  static String currentLevel(Map profile, Map stats) {
    if ((stats['totalSessions'] as num? ?? 0) >= 10) {
      final score = (stats['avgScore'] as num? ?? 0).toInt();
      if (score >= 80) return 'Advanced';
      if (score >= 60) return 'Intermediate';
      return 'Beginner';
    }
    return parseLevel(profile['level']) ??
        parseLevel(profile['initialLevel']) ??
        'Beginner';
  }

  static bool allows(String current, String requested) {
    final rank = levels.indexOf(requested);
    return rank >= 0 && rank <= levels.indexOf(current);
  }

  static String lockedMessage(String level) =>
      '$level resources are locked. Reach the $level level to unlock them.';

  static Future<String> fetchCurrentLevel(String userId) async {
    final responses = await Future.wait([
      ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/user/$userId')),
      ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/stats/$userId?view=summary'),
      ),
    ]);
    if (responses.any((response) => response.statusCode != 200)) {
      throw StateError(
        'Unable to verify your current level. Please try again.',
      );
    }
    final profile = jsonDecode(responses[0].body) as Map;
    final stats = jsonDecode(responses[1].body) as Map;
    return currentLevel(profile, stats['overallStats'] as Map? ?? {});
  }
}

/// Independent filters; only a successful, accessible level choice is persisted.
class ResourceFilters {
  final String userId;
  String currentLevel = 'Beginner';
  String selectedLevel = 'Beginner';
  String selectedLanguage = 'All';
  SharedPreferences? _preferences;

  ResourceFilters(this.userId);

  String get _key => 'learning_resources.level.$userId';

  Future<void> restore(String level) async {
    _preferences ??= await SharedPreferences.getInstance();
    currentLevel = level;
    final remembered = _preferences!.getString(_key);
    selectedLevel =
        remembered != null && ResourceAccess.allows(level, remembered)
        ? remembered
        : level;
    await _preferences!.setString(_key, selectedLevel);
  }

  Future<void> updateCurrentLevel(String level) async {
    currentLevel = level;
    if (!ResourceAccess.allows(level, selectedLevel)) {
      selectedLevel = level;
      await _preferences?.setString(_key, selectedLevel);
    }
  }

  Future<bool> selectLevel(String level) async {
    if (!ResourceAccess.allows(currentLevel, level)) return false;
    selectedLevel = level;
    await _preferences?.setString(_key, level);
    return true;
  }

  bool matches(Map resource) {
    if (resource['type'] == 'GuidedTask') {
      return selectedLanguage == 'All' ||
          resource['language']?.toString().trim() == selectedLanguage;
    }
    final level = ResourceAccess.parseLevel(resource['difficulty']);
    final language = resource['language']?.toString().trim();
    // Unclassified and mixed-language content cannot be truthfully labeled
    // English/Filipino at a specific level. Retain it in storage and history.
    return level != null &&
        ResourceAccess.allows(currentLevel, level) &&
        level == selectedLevel &&
        (language == 'English' || language == 'Filipino') &&
        (selectedLanguage == 'All' || language == selectedLanguage);
  }
}
