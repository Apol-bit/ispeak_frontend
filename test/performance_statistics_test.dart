import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ispeak/pages/progress_page.dart';
import 'package:ispeak/models/performance_statistics.dart';
import 'package:ispeak/services/resource_access.dart';

void main() {
  testWidgets(
    'Progress distinguishes no eligible data from a legitimate zero average',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      for (final count in [0, 1]) {
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: ProgressPage(
                  key: ValueKey(count),
                  userId: 'test',
                  onStartPractice: () {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text('No data'),
              count == 0 ? findsOneWidget : findsNothing,
            );
            if (count == 1) expect(find.text('0%'), findsWidgets);
            expect(tester.takeException(), isNull);
          },
          () => MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.contains('/stats/')
                    ? {
                        'statisticsVersion': 1,
                        'overallStats': {
                          'totalSessions': 4,
                          'eligibleScoredSessions': count,
                          'avgScore': count == 0 ? null : 0,
                        },
                        'sessions': count == 0
                            ? []
                            : [
                                {
                                  'language': 'English',
                                  'createdAt': DateTime.now().toIso8601String(),
                                  'overallScore': 0,
                                  'paceScore': 0,
                                  'clarityScore': 0,
                                  'energyScore': 0,
                                },
                              ],
                      }
                    : {'initialLevel': 'Beginner'},
              ),
              200,
            ),
          ),
        );
      }
    },
  );
  test(
    'ten eligible assessments and unchanged 60/80 boundaries determine placement',
    () {
      for (final count in [9, 10, 11]) {
        for (final score in [0, 59.9, 60, 79.9, 80, 100]) {
          final level = ResourceAccess.currentLevel(
            {'initialLevel': 'Intermediate'},
            {
              'totalSessions': 114,
              'eligibleScoredSessions': count,
              'avgScore': score,
            },
          );
          expect(
            level,
            count < 10
                ? 'Intermediate'
                : score >= 80
                ? 'Advanced'
                : score >= 60
                ? 'Intermediate'
                : 'Beginner',
          );
        }
      }
    },
  );
  test('legacy and malformed stats preserve demographic placement', () {
    for (final stats in <Map>[
      {},
      {'totalSessions': 114, 'avgScore': 0},
      {'eligibleScoredSessions': 10},
      {'eligibleScoredSessions': '10', 'avgScore': 90},
      {'eligibleScoredSessions': 10.5, 'avgScore': 90},
      for (final value in [null, '90', double.nan, double.infinity, -1, 101])
        {'eligibleScoredSessions': 10, 'avgScore': value},
    ]) {
      expect(
        ResourceAccess.currentLevel({'initialLevel': 'Advanced'}, stats),
        'Advanced',
      );
      expect(ResourceAccess.hasPerformancePlacement(stats), false);
    }
  });
  test(
    'weekly/language rows require eligibility-aware API and finite scores; zero survives',
    () {
      final rows = [
        for (final language in ['English', 'Filipino', 'Taglish'])
          {
            'language': language,
            'overallScore': 0,
            'paceScore': 0,
            'clarityScore': 0,
            'energyScore': 0,
          },
        {'overallScore': 80},
        {
          'overallScore': 80,
          'paceScore': '80',
          'clarityScore': 80,
          'energyScore': 80,
        },
      ];
      expect(
        performanceSessions({'statisticsVersion': 1, 'sessions': rows}).length,
        3,
      );
      expect(performanceSessions({'sessions': rows}), isEmpty);
      expect(eligibleSessionCount({}), 0);
    },
  );
}
