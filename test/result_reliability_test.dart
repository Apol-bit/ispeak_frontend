import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/services/api_client.dart';

void main() {
  testWidgets('old non-speech results cannot display positive score feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResultPage(
          sessionData: {
            'wpmScore': 0,
            'transcription': 'yeah yeah yeah',
            'overallScore': 33,
            'clarityScore': 40,
            'energyScore': 68,
            'fillerAnalysisAvailable': true,
            'fillerWordCount': 0,
          },
        ),
      ),
    );
    expect(find.text('Recording not evaluated'), findsOneWidget);
    expect(find.text('Overall Score'), findsNothing);
    expect(find.textContaining('Perfect!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial scores display stored findings, without inferring volume',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResultPage(
            sessionData: {
              'analysisValid': true,
              'wpmScore': 130.3,
              'transcription': 'Good morning everyone',
              'overallScore': 96.8,
              'paceScore': 100,
              'clarityScore': 92,
              'energyScore': 100,
              'analysisAvailability': {
                'pitch': false,
                'pronunciation': false,
                'fillers': true,
              },
              'analysisFeedback': {
                'energy': 'Pitch analysis was unavailable; partial estimate.',
                'clarity': 'No filler spans were detected.',
                'pace': 'Your pace is close to the reference recording.',
              },
            },
          ),
        ),
      );
      expect(find.textContaining('Partial assessment:'), findsOneWidget);
      expect(
        find.textContaining('Pitch analysis was unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('close to the reference'), findsOneWidget);
      expect(find.textContaining('Great vocal'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('upload validation displays a message rather than raw JSON or HTML', () {
    expect(
      ApiClient.errorMessage(
        http.Response('{"message":"Recording too short"}', 400),
      ),
      'Recording too short',
    );
    expect(
      ApiClient.errorMessage(http.Response('<html>internal error</html>', 502)),
      'The recording could not be analyzed. Please try again.',
    );
  });
}
