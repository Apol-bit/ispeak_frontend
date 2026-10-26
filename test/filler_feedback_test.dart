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
}
