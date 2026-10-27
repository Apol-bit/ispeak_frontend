import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ispeak/models/filler_feedback.dart';
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/widgets/feedback_tips.dart';

void main() {
  Map<String, dynamic> session(
    int count,
    int candidates, {
    bool available = true,
    String coverage = 'matched',
  }) => {
    'fillerWordCount': count,
    'fillerAnalysisAvailable': true,
    'fillerAnalysis': {
      'version': 1,
      'available': available,
      'count': available ? count : null,
      'candidateCount': candidates,
      'words': [
        {'word': 'um um'},
      ],
      'coverage': {'status': coverage},
    },
  };
  test(
    'zero, uncertainty, unavailable, grouped positive and alignment states',
    () {
      expect(
        fillerFeedback(session(0, 0)),
        contains('No accepted filler spans'),
      );
      expect(
        fillerFeedback(session(0, 2)),
        contains('possible fillers need review'),
      );
      expect(
        fillerFeedback(session(0, 0, available: false)),
        'Filler-word analysis unavailable.',
      );
      expect(
        fillerFeedback(session(1, 0)),
        contains('1 confirmed filler spans'),
      );
      expect(fillerFeedback(session(1, 0)), contains('um um'));
      expect(
        fillerFeedback(session(0, 0, coverage: 'mismatch')),
        contains('may be incomplete'),
      );
    },
  );
  test('legacy fields are safe and do not claim verified coverage', () {
    expect(fillerFeedback({}), 'Filler-word analysis unavailable.');
    expect(
      fillerFeedback({'fillerAnalysisAvailable': true, 'fillerWordCount': 0}),
      contains('not verified'),
    );
    expect(
      fillerFeedback({'fillerAnalysis': 'invalid'}),
      contains('unavailable'),
    );
  });
  test('vocabulary recognition is shown separately from confirmed count', () {
    final data = session(0, 4);
    (data['fillerAnalysis'] as Map)['candidates'] = [
      {'word': 'ano', 'confidence': null},
      {'word': 'parang', 'confidence': null},
      {'word': 'ah', 'confidence': null},
      {'word': 'so', 'confidence': null},
    ];
    expect(
      fillerFeedback(data),
      contains('Review matches (may be grammatical): ano, parang, ah, so.'),
    );
    expect(fillerFeedback(data), isNot(contains('4 confirmed')));
  });
  testWidgets(
    'Results labels the API grouped-span count and separates review matches',
    (tester) async {
      final data = session(2, 1);
      data.addAll({'wpmScore': 130, 'transcription': 'um um ano hello'});
      (data['fillerAnalysis'] as Map)['candidates'] = [
        {'word': 'ano', 'confidence': null},
      ];
      await tester.pumpWidget(MaterialApp(home: ResultPage(sessionData: data)));
      expect(find.text('2 confirmed filler spans'), findsOneWidget);
      expect(find.textContaining('Detected: um um.'), findsOneWidget);
      expect(
        find.textContaining('Review matches (may be grammatical): ano.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Results keeps concise filler subtitle and partial coverage notice',
    (tester) async {
      final data = session(0, 2, coverage: 'mismatch');
      data.addAll({
        'wpmScore': 130,
        'transcription': 'um hello there',
        'overallScore': 90,
        'analysisAvailability': {
          'pitch': true,
          'pronunciation': true,
          'fillers': true,
        },
      });
      await tester.pumpWidget(MaterialApp(home: ResultPage(sessionData: data)));
      expect(find.text('No confirmed fillers detected'), findsOneWidget);
      expect(
        find.textContaining('possible fillers need review'),
        findsOneWidget,
      );
      expect(find.textContaining('Partial assessment:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Results limits Clarity to three non-repeating bullets', (
    tester,
  ) async {
    final data = session(2, 3, coverage: 'mismatch');
    final detail = data['fillerAnalysis'] as Map;
    detail['words'] = [
      {'word': 'um'},
      {'word': 'uh'},
    ];
    detail['candidates'] = [
      {'word': 'like'},
      {'word': 'ano'},
    ];
    data.addAll({
      'analysisValid': true,
      'transcription': 'um uh like ano hello',
      'wpmScore': 130,
      'overallScore': 85,
      'paceScore': 90,
      'clarityScore': 80,
      'energyScore': 80,
      'analysisFeedback': {
        'clarity':
            'Some word timing or audibility needs practice. '
            'Pronunciation confidence was unavailable. '
            'Detected 2 grouped filler spans. '
            'Filler analysis may be incomplete because transcript coverage differs.',
      },
    });
    await tester.pumpWidget(MaterialApp(home: ResultPage(sessionData: data)));
    final clarity = tester.widgetList<FeedbackTips>(find.byType(FeedbackTips));
    expect(feedbackTips(clarity.elementAt(1).tips), [
      'Some word timing or audibility needs practice.',
      'Detected: um, uh.',
      'Review matches (may be grammatical): like, ano.',
    ]);
    expect(tester.takeException(), isNull);
  });
}
