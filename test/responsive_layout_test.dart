import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/pages/demographic_screen.dart';
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/pages/login_screen.dart';
import 'package:ispeak/pages/practice_page.dart';
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/pages/script_practice_page.dart';
import 'package:ispeak/pages/signup_screen.dart';
import 'package:ispeak/pages/splash_screen.dart';
import 'package:ispeak/pages/time_challenge_page.dart';

void main() {
  Future<void> pumpAtLogicalSize(
    WidgetTester tester, {
    required Size logicalSize,
    required double devicePixelRatio,
    required Widget child,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = Size(
      logicalSize.width * devicePixelRatio,
      logicalSize.height * devicePixelRatio,
    );
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: '${child.runtimeType} overflowed at $logicalSize',
    );
  }

  group('responsive layouts', () {
    for (final viewport in <({Size size, double dpr})>[
      (size: const Size(320, 568), dpr: 1),
      (size: const Size(390, 844), dpr: 2),
      (size: const Size(450, 900), dpr: 3),
    ]) {
      testWidgets('splash adapts to ${viewport.size.width}px', (tester) async {
        await pumpAtLogicalSize(
          tester,
          logicalSize: viewport.size,
          devicePixelRatio: viewport.dpr,
          child: const SplashScreen(),
        );
      });
    }

    testWidgets('forms and result fit a small phone', (tester) async {
      final screens = <Widget>[
        const LoginScreen(),
        const SignupScreen(),
        const DemographicScreen(userId: 'test', username: 'Responsive User'),
        const ResultPage(
          sessionData: {
            'createdAt': '2026-08-16T18:00:00.000Z',
            'overallScore': 0,
            'paceScore': 0,
            'clarityScore': 0,
            'energyScore': 0,
          },
        ),
      ];

      for (final screen in screens) {
        await pumpAtLogicalSize(
          tester,
          logicalSize: const Size(320, 568),
          devicePixelRatio: 2,
          child: screen,
        );
      }
    });

    testWidgets('practice flows fit a small phone', (tester) async {
      const script = {
        'title': 'Responsive Practice Script With a Long Title',
        'description': 'Practice reading aloud with clear, confident delivery.',
        'transcript':
            'A responsive interface keeps every practice control accessible.',
        'estimatedMinutes': 2,
        'difficulty': 'Intermediate',
        'language': 'English',
        'tips': ['Speak clearly', 'Pause between ideas'],
      };
      const challenge = {
        'title': 'Responsive Timed Challenge With a Long Title',
        'description': 'Speak about the prompt before the timer ends.',
        'prompt':
            'Explain why adaptable interfaces improve the user experience.',
        'timeLimitSeconds': 60,
        'difficulty': 'Advanced',
        'language': 'Taglish',
        'tips': ['Organize your thoughts', 'Keep a steady pace'],
      };

      final screens = <Widget>[
        const PracticePage(userId: 'test'),
        const ScriptDetailPage(script: script, userId: 'test'),
        const ScriptPracticePage(script: script, userId: 'test'),
        const TimedChallengePage(challenge: challenge, userId: 'test'),
        const GuidedTaskDetailPage(
          task: {
            'title': 'Responsive Guided Task With a Long Title',
            'category': 'Confidence Building',
            'estimatedMinutes': 10,
            'steps': [
              'Read the prompt carefully and identify the main idea.',
              'Deliver the response while maintaining a steady pace.',
            ],
            'proTip': 'Use short pauses to make each point easier to follow.',
          },
        ),
      ];

      for (final screen in screens) {
        await pumpAtLogicalSize(
          tester,
          logicalSize: const Size(320, 568),
          devicePixelRatio: 2,
          child: screen,
        );
      }
    });

    testWidgets('login remains usable when the keyboard appears', (
      tester,
    ) async {
      await pumpAtLogicalSize(
        tester,
        logicalSize: const Size(320, 568),
        devicePixelRatio: 2,
        child: const LoginScreen(),
      );

      await tester.tap(find.byType(TextFormField).first);
      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
