import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/models/assessment_feedback.dart';
import 'package:ispeak/pages/result_page.dart';

Map<String, dynamic> evidence({String? missing}) => {
  'status': 'Completed',
  'analysisValid': true,
  'overallScore': 96.8,
  'transcription': 'Good morning everyone',
  'wpmScore': 127,
  'paceScore': 100,
  'clarityScore': 92,
  'energyScore': 100,
  'assessmentDetails': {
    'version': 1,
    'completeness': missing == null ? 'complete' : 'partial',
    'coverage': missing == 'coverage' ? 'mismatch' : 'matched',
    'availability': {
      for (final k in [
        'pacing',
        'pronunciation',
        'enunciation',
        'intensity',
        'pauses',
        'pitch',
        'fillers',
      ])
        k: k != missing,
    },
    'fallback': {
      'pronunciation': missing == 'pronunciation',
      'fillers': missing == 'fillers',
    },
    'weights': {
      'clarity': {
        'articulation': missing == 'fillers' ? 1 : .6,
        'fillers': missing == 'fillers' ? 0 : .4,
      },
    },
    'basis': {'pacing': 'target_range'},
  },
};

void main() {
  test(
    'omit unavailable pronunciation message but preserve remaining evidence',
    () {
      final feedback = assessmentFeedback(evidence(missing: 'pronunciation'));
      expect(
        feedback,
        isNot(contains('Pronunciation confidence was unavailable')),
      );
      expect(feedback, contains('enunciation timing/audibility proxy'));
      expect(feedback, startsWith('Partial assessment:'));
    },
  );

  testWidgets('Clarity hides only the unavailable pronunciation tip', (
    tester,
  ) async {
    for (final tips in <Object>[
      'Pronunciation confidence was unavailable; pronunciation accuracy cannot be concluded. Keep your articulation steady.',
      [
        'Pronunciation confidence was unavailable',
        'Keep your articulation steady.',
      ],
    ]) {
      final session = evidence(missing: 'pronunciation');
      session['analysisFeedback'] = {
        'clarity': tips,
        'pace': 'Keep this pace.',
        'energy': 'Keep this energy.',
      };
      await tester.pumpWidget(
        MaterialApp(home: ResultPage(sessionData: session)),
      );
      expect(
        find.textContaining('Pronunciation confidence was unavailable'),
        findsNothing,
      );
      expect(find.text('Keep your articulation steady.'), findsOneWidget);
      expect(find.text('Keep this pace.'), findsOneWidget);
      expect(find.text('Keep this energy.'), findsOneWidget);
      expect(find.text('96.8'), findsOneWidget);
      expect(session['clarityScore'], 92);
      expect(tester.takeException(), isNull);
    }
  });

  test(
    'complete, unavailable components, uncertainty and legacy explanations',
    () {
      expect(
        assessmentFeedback(evidence()),
        startsWith('Complete assessment.'),
      );
      expect(
        assessmentFeedback(evidence(missing: 'pronunciation')),
        contains('enunciation timing/audibility proxy'),
      );
      expect(
        assessmentFeedback(evidence(missing: 'fillers')),
        contains('articulation only'),
      );
      expect(
        assessmentFeedback(evidence(missing: 'pitch')),
        contains('Intonation cannot be concluded'),
      );
      expect(
        assessmentFeedback(evidence(missing: 'coverage')),
        contains('coverage is incomplete'),
      );
      expect(
        assessmentFeedback(evidence(missing: 'uncertainty')),
        startsWith('Partial assessment:'),
      );
      expect(assessmentFeedback({}), startsWith('Legacy assessment:'));
      expect(overallScoreText(96.8), '96.8');
      expect(overallScoreText(100), '100.0');
      expect(overallScoreText(null), 'Unavailable');
    },
  );
  testWidgets(
    'small Results preserve decimal scores and concise assessment notice',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final session in [
        evidence(missing: 'pronunciation'),
        Map<String, dynamic>.from(evidence(missing: 'pronunciation')),
        evidence(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: ResultPage(sessionData: session)),
        );
        expect(find.text('96.8'), findsOneWidget);
        expect(
          find.text(
            'Partial assessment: some analysis components are unavailable.',
          ),
          session['assessmentDetails']['completeness'] == 'complete'
              ? findsNothing
              : findsOneWidget,
        );
        expect(find.textContaining('Overall weighting:'), findsNothing);
        expect(find.textContaining('Clarity uses articulation'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
