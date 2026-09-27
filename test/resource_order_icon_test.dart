import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/widgets/resource_icon.dart';

void main() {
  test('admin order survives language and level filtering', () {
    final resources = <Map<String, dynamic>>[
      {'_id': 'legacy', 'title': 'Legacy', 'language': 'English'},
      {
        '_id': 'third',
        'title': 'Third',
        'displayOrder': 3,
        'language': 'English',
      },
      {
        '_id': 'first',
        'title': 'First',
        'displayOrder': 1,
        'language': 'Filipino',
      },
      {
        '_id': 'second',
        'title': 'Second',
        'displayOrder': 2,
        'language': 'English',
      },
    ];
    expect(resourcesInDisplayOrder(resources).map((row) => row['title']), [
      'Legacy',
      'First',
      'Second',
      'Third',
    ]);
    expect(
      resourcesInDisplayOrder(
        resources.where((row) => row['language'] == 'English'),
      ).map((row) => row['title']),
      ['Legacy', 'Second', 'Third'],
    );
  });

  test('supported registry resolves every picker name and one fallback', () {
    for (final option in ResourceIcon.options) {
      expect(ResourceIcon.supports(option.name), isTrue);
      expect(ResourceIcon.resolve(option.name), option.icon);
    }
    expect(ResourceIcon.resolve('hearing'), Icons.hearing);
    expect(ResourceIcon.resolve('unsupported-legacy'), ResourceIcon.fallback);
    expect(ResourceIcon.resolve(null), ResourceIcon.fallback);
  });
}
