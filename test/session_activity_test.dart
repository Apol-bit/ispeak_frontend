import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/models/session_history.dart';
import 'package:ispeak/pages/result_page.dart';

void main() {
  test('only explicit activity metadata gets a specific label', () {
    expect(sessionActivityLabel({'practiceMode': 'ordinary'}), 'Free Practice');
    expect(sessionActivityLabel({'practiceMode': 'script'}), 'Script Practice');
    expect(
      sessionActivityLabel({'practiceMode': 'challenge'}),
      'Timed Challenge',
    );
    for (final session in [
      {},
      {'challengeId': 'legacy'},
      {'resourceId': 'legacy'},
      {'practiceMode': null},
      {'practiceMode': 'unknown'},
    ]) {
      expect(sessionActivityLabel(session), 'Activity unavailable');
    }
  });

  testWidgets(
    'Results shows saved activity with existing scores at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final mode in ['ordinary', 'script', 'challenge', null]) {
        final session = <String, dynamic>{
          'practiceMode': mode,
          'transcription': 'A usable test transcript.',
          'analysisValid': true,
        'wpmScore': 130,
          'overallScore': 80,
          'paceScore': 80,
          'clarityScore': 80,
          'energyScore': 80,
        };
        await tester.pumpWidget(
          MaterialApp(home: ResultPage(sessionData: session)),
        );
        expect(
          find.textContaining(sessionActivityLabel(session)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
