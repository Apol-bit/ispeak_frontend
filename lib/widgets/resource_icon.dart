import 'package:flutter/material.dart';

class IconOption {
  final String name;
  final IconData icon;
  final String category;
  final List<String> keywords;

  const IconOption(
    this.name,
    this.icon,
    this.category, [
    this.keywords = const [],
  ]);

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty ||
        name.contains(normalized) ||
        category.toLowerCase().contains(normalized) ||
        keywords.any((keyword) => keyword.contains(normalized));
  }
}

/// Canonical names stored in LearningResource.iconName.
class ResourceIcon {
  static const fallbackName = 'volume_up';
  static const fallback = Icons.volume_up;
  static const categories = <String>[
    'All',
    'Speech',
    'Audio',
    'Learning',
    'Time',
    'Communication',
    'General',
  ];
  static const options = <IconOption>[
    IconOption('mic', Icons.mic, 'Speech', ['microphone', 'record']),
    IconOption('record_voice_over', Icons.record_voice_over, 'Speech', [
      'mic',
      'speaker',
    ]),
    IconOption('campaign', Icons.campaign, 'Speech', ['announce', 'voice']),
    IconOption('volume_up', Icons.volume_up, 'Audio', ['sound', 'speaker']),
    IconOption('hearing', Icons.hearing, 'Audio', ['hear', 'listen']),
    IconOption('graphic_eq', Icons.graphic_eq, 'Audio', ['wave', 'sound']),
    IconOption('school', Icons.school, 'Learning', ['study', 'education']),
    IconOption('menu_book', Icons.menu_book, 'Learning', ['book', 'read']),
    IconOption('psychology', Icons.psychology, 'Learning', ['mind', 'brain']),
    IconOption('lightbulb', Icons.lightbulb, 'Learning', ['idea', 'tip']),
    IconOption('timer', Icons.timer, 'Time', ['clock', 'challenge']),
    IconOption('access_time', Icons.access_time, 'Time', ['clock']),
    IconOption('speed', Icons.speed, 'Time', ['pace', 'fast']),
    IconOption('forum', Icons.forum, 'Communication', ['chat', 'talk']),
    IconOption('groups', Icons.groups, 'Communication', ['people', 'audience']),
    IconOption('chat_bubble', Icons.chat_bubble, 'Communication', ['message']),
    IconOption(
      'chat_bubble_outline',
      Icons.chat_bubble_outline,
      'Communication',
      ['message'],
    ),
    IconOption('person_outline', Icons.person_outline, 'Communication', [
      'person',
      'speaker',
    ]),
    IconOption('flash_on', Icons.flash_on, 'General', ['flash', 'energy']),
    IconOption('bolt', Icons.bolt, 'General', ['energy', 'flash']),
  ];
  static final icons = <String, IconData>{
    for (final option in options) option.name: option.icon,
  };

  static bool supports(Object? name) =>
      name is String && icons.containsKey(name.trim());
  static IconData resolve(Object? name) =>
      name is String ? icons[name.trim()] ?? fallback : fallback;

  static List<IconOption> filtered(String category, String query) => options
      .where((option) => category == 'All' || option.category == category)
      .where((option) => option.matches(query))
      .toList(growable: false);
}
