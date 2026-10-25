import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ispeak/models/filler_feedback.dart';
import 'package:ispeak/pages/result_page.dart';

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
      expect(find.textContaining('Partial assessment:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
