import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ispeak/pages/dashboard_page.dart';
import 'package:ispeak/pages/result_page.dart';

void main() {
  testWidgets(
    'dashboard averages fit at 320px and session labels follow the count',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final cases = <(dynamic, bool?, String)>[
        (76.36753246753247, true, '76.4'),
        (0, true, '0.0'),
        (100, true, '100.0'),
        (null, false, '—'),
        ('invalid', true, '—'),
        (-1, true, '—'),
        (101, true, '—'),
        (76.36753246753247, false, '—'),
        (76.36753246753247, null, '76.4'),
      ];
      for (var i = 0; i < cases.length; i++) {
        final (average, available, expected) = cases[i];
        final sessionCount = i % 3;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: DashBoardPage(
                    key: ValueKey(i),
                    userId: 'fixture',
                    onStartPractice: () {},
                    onLearningResources: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final label = find.text('Avg Score');
            expect(label, findsOneWidget);
            final card = find
                .ancestor(of: label, matching: find.byType(Column))
                .first;
            expect(
              find.descendant(of: card, matching: find.text(expected)),
              findsOneWidget,
            );
            expect(find.text('76.36753246753247'), findsNothing);
            expect(
              find.text(sessionCount == 1 ? 'Session' : 'Sessions'),
              findsOneWidget,
            );
            expect(find.text('Attempts'), findsNothing);
            expect(tester.takeException(), isNull);
          },
          () => MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.contains('/stats/')
                    ? {
                        'overallStats': {
                          'totalSessions': sessionCount,
                          'eligibleScoredSessions': 3,
                          'avgScore': average,
                          'avgScoreAvailable': ?available,
                        },
                        'sessions': [],
                      }
                    : request.url.path.contains('/sessions/')
                    ? []
                    : {'initialLevel': 'Beginner'},
              ),
              200,
            ),
          ),
        );
      }
    },
  );

  testWidgets(
    'Results hides transcript and shows only verified concise filler counts',
    (tester) async {
      for (final item in [
        (true, 2, '2 confirmed filler spans'),
        (true, 0, 'No confirmed fillers detected'),
        (false, 2, 'Filler-word analysis unavailable'),
        (true, null, 'Filler-word analysis unavailable'),
        (true, 2.5, 'Filler-word analysis unavailable'),
      ]) {
        final session = <String, dynamic>{
          'transcription': 'Authorized fixture transcript remains in the data.',
          'analysisValid': true,
          'wpmScore': 130,
          'overallScore': 93.2,
          'paceScore': 90,
          'clarityScore': 88,
          'energyScore': 95,
          'fillerWordCount': 0,
          'fillerAnalysisAvailable': item.$1,
          'fillerAnalysis': {
            'version': 1,
            'available': item.$1,
            'count': item.$2,
            'candidateCount': 2,
            'coverage': {'status': 'mismatch'},
            'words': [
              {'word': 'um', 'start': 1, 'end': 2, 'confidence': .9},
            ],
          },
        };
        final before = jsonEncode(session);
        await tester.pumpWidget(
          MaterialApp(home: ResultPage(sessionData: session)),
        );
        expect(find.text(item.$3), findsOneWidget);
        expect(find.text('Transcription'), findsNothing);
        expect(find.text(session['transcription']), findsNothing);
        expect(find.byType(SelectableText), findsNothing);
        expect(find.text('93.2'), findsOneWidget);
        expect(jsonEncode(session), before);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
