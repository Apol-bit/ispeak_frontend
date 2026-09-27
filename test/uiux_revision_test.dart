import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ispeak/main.dart';
import 'package:ispeak/models/session_history.dart';
import 'package:ispeak/models/signup_name.dart';
import 'package:ispeak/pages/dashboard_page.dart';
import 'package:ispeak/pages/editprofile_screen.dart';
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/pages/practice_page.dart';
import 'package:ispeak/pages/profile_screen.dart';
import 'package:ispeak/pages/progress_page.dart';
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/pages/script_practice_page.dart';
import 'package:ispeak/pages/session_history_page.dart';
import 'package:ispeak/pages/signup_screen.dart';
import 'package:ispeak/pages/time_challenge_page.dart';
import 'package:ispeak/services/resource_access.dart';
import 'package:ispeak/widgets/feedback_tips.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> session(int day) => {
  '_id': 'session-$day',
  'userId': 'test',
  'createdAt': '2026-09-${day.toString().padLeft(2, '0')}T08:00:00Z',
  'overallScore': 70 + day,
  'paceScore': 80,
  'clarityScore': 75,
  'energyScore': 85,
  'wpmScore': 130,
  'fillerWordCount': 2,
  'transcription': 'This is a saved practice session.',
  'language': 'English',
  'audioPath': 'https://example.invalid/saved-$day.wav',
  'analysisValid': true,
  'analysisFeedback': {
    'pace': ['Pause between ideas.', 'Keep a steady pace.'],
  },
};

class Fixtures {
  String level = 'Advanced';
  bool failProfile = false;
  final sessions = [session(2), session(5), session(1), session(4), session(3)];
  final requests = <http.Request>[];
  final resources = [
    for (final type in ['Script', 'Challenge', 'GuidedTask'])
      for (final level in ResourceAccess.levels)
        for (final language in ['English', 'Filipino'])
          {
            '_id': '$type-$level-$language',
            'type': type,
            'title': '$type $level $language',
            'difficulty': level,
            'language': language,
            'description': 'Practice clearly and confidently.',
            'transcript': 'Practice this script with a steady pace. ' * 20,
            'estimatedMinutes': 2,
            'timeLimitSeconds': 60,
            'steps': ['Take a breath.', 'Speak clearly.'],
            'tips': ['Pause between ideas.'],
          },
  ];

  http.Client client() => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object data;
    if (path.contains('/user/')) {
      if (failProfile) return http.Response('{}', 500);
      data = {
        'firstName': 'Test',
        'lastName': 'User',
        'username': 'test-user',
        'email': 'test@example.com',
        'initialLevel': level,
      };
    } else if (path.contains('/stats/')) {
      data = {
        'overallStats': {'totalSessions': sessions.length, 'avgScore': 75},
        'sessions': sessions,
      };
    } else if (path.contains('/sessions/')) {
      data = sessions;
    } else if (path.endsWith('/resources')) {
      data = resources;
    } else if (path.endsWith('/upload-audio')) {
      final saved = session(6);
      sessions.add(saved);
      data = saved;
    } else if (path.endsWith('/signup')) {
      return http.Response(
        jsonEncode({
          'user': {'id': 'test', 'username': 'test-user'},
          'token': 'test-token',
        }),
        201,
      );
    } else {
      return http.Response('{}', 404);
    }
    return http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });

  test(
    'home preview sorts dates and never mutates or truncates saved history',
    () {
      final saved = Fixtures().sessions;
      expect(newestSessions(saved, limit: 3).map((s) => s['_id']), [
        'session-5',
        'session-4',
        'session-3',
      ]);
      expect(saved.length, 5);
      expect(saved.first['_id'], 'session-2');
    },
  );

  test(
    'all nine cumulative access combinations follow current proficiency',
    () {
      for (var user = 0; user < 3; user++) {
        for (var resource = 0; resource < 3; resource++) {
          expect(
            ResourceAccess.allows(
              ResourceAccess.levels[user],
              ResourceAccess.levels[resource],
            ),
            resource <= user,
          );
        }
      }
      expect(
        ResourceAccess.currentLevel(
          {'initialLevel': 'Advanced'},
          {'totalSessions': 10, 'avgScore': 59},
        ),
        'Beginner',
      );
      expect(
        ResourceAccess.currentLevel(
          {'initialLevel': 'Beginner'},
          {'totalSessions': 10, 'avgScore': 80},
        ),
        'Advanced',
      );
    },
  );

  test(
    'valid preference persists per user; locked selection cannot replace it',
    () async {
      final filters = ResourceFilters('one');
      await filters.restore('Intermediate');
      expect(await filters.selectLevel('Beginner'), isTrue);
      expect(await filters.selectLevel('Advanced'), isFalse);
      final returned = ResourceFilters('one');
      await returned.restore('Intermediate');
      expect(returned.selectedLevel, 'Beginner');
      final other = ResourceFilters('two');
      await other.restore('Advanced');
      expect(other.selectedLevel, 'Advanced');
    },
  );

  for (final demotion in [
    ('Advanced', 'Intermediate'),
    ('Intermediate', 'Beginner'),
    ('Advanced', 'Beginner'),
  ]) {
    test(
      'demotion ${demotion.$1} to ${demotion.$2} replaces a locked preference',
      () async {
        final filters = ResourceFilters('test');
        await filters.restore(demotion.$1);
        await filters.updateCurrentLevel(demotion.$2);
        expect(filters.selectedLevel, demotion.$2);
        final returned = ResourceFilters('test');
        await returned.restore(demotion.$2);
        expect(returned.selectedLevel, demotion.$2);
        expect(await filters.selectLevel(demotion.$1), isFalse);
      },
    );
  }

  test(
    'scripts and challenges filter by level; guided tasks only by language',
    () async {
      final filters = ResourceFilters('test');
      await filters.restore('Intermediate');
      await filters.selectLevel('Beginner');
      filters.selectedLanguage = 'Filipino';
      final matches = Fixtures().resources.where(filters.matches).toList();
      expect(matches.length, 5);
      expect(
        matches.every(
          (r) =>
              (r['type'] == 'GuidedTask' || r['difficulty'] == 'Beginner') &&
              r['language'] == 'Filipino',
        ),
        isTrue,
      );
      expect(
        filters.matches({'difficulty': 'None', 'language': 'Filipino'}),
        isFalse,
      );
      filters.selectedLanguage = 'All';
      expect(Fixtures().resources.where(filters.matches).length, 10);
    },
  );

  test(
    'optional suffix and existing feedback lists preserve their contents',
    () {
      expect(lastNameWithExtension(' Santos ', ''), 'Santos');
      expect(lastNameWithExtension(' Santos ', 'Jr.'), 'Santos Jr.');
      expect(feedbackTips(['Pause here.', 'Speak slowly. Add a pause.']), [
        'Pause here.',
        'Speak slowly.',
        'Add a pause.',
      ]);
    },
  );

  testWidgets('optional suffix survives form rebuild and terms navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    final suffix = find.byKey(const ValueKey('name-extension'));
    await tester.ensureVisible(suffix);
    await tester.tap(suffix);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jr.').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Terms & Conditions'));
    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButtonFormField<String>>(suffix).initialValue,
      'Jr.',
    );
  });

  testWidgets(
    'language persists across types, locked filter stays selected, demotion refreshes',
    (tester) async {
      final fixtures = Fixtures()..level = 'Intermediate';
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: LearningResourcesScreen(userId: 'test')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Filipino'));
        await tester.pumpAndSettle();
        for (final tab in ['Scripts', 'Challenges', 'Guided Tasks']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          final type = {
            'Scripts': 'Script',
            'Challenges': 'Challenge',
            'Guided Tasks': 'GuidedTask',
          }[tab];
          expect(find.text('$type Intermediate Filipino'), findsOneWidget);
          expect(find.text('$type Intermediate English'), findsNothing);
        }
        await tester.tap(find.text('Scripts'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('level-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();
        expect(find.text('Level: Intermediate'), findsOneWidget);
        expect(
          find.text(ResourceAccess.lockedMessage('Advanced')),
          findsOneWidget,
        );
        fixtures.level = 'Beginner';
        await tester.pumpWidget(
          const MaterialApp(
            home: LearningResourcesScreen(userId: 'test', refreshKey: 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Level: Beginner'), findsOneWidget);
        expect(find.text('Script Beginner Filipino'), findsOneWidget);
        expect(fixtures.sessions.length, 5);
        expect(tester.takeException(), isNull);
      }, fixtures.client);
    },
  );

  testWidgets('failed level verification exposes no resources', (tester) async {
    final fixtures = Fixtures()..failProfile = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: LearningResourcesScreen(userId: 'test')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to load resources'), findsOneWidget);
      expect(find.text('Script Advanced English'), findsNothing);
    }, fixtures.client);
  });

  for (final fromHome in [true, false]) {
    testWidgets(
      '${fromHome ? 'Home' : 'Progress'} opens the shared complete history',
      (tester) async {
        final fixtures = Fixtures();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: fromHome
                  ? DashBoardPage(
                      userId: 'test',
                      onStartPractice: () {},
                      onLearningResources: () {},
                    )
                  : ProgressPage(userId: 'test', onStartPractice: () {}),
            ),
          );
          await tester.pumpAndSettle();
          if (fromHome) {
            expect(find.text('75'), findsWidgets);
            expect(find.text('2026-09-05'), findsOneWidget);
            expect(find.text('2026-09-01'), findsNothing);
          } else {
            expect(find.text('Session #5'), findsNothing);
          }
          final label = fromHome ? 'See All Sessions' : 'View Session History';
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.byType(SessionHistoryPage), findsOneWidget);
          await tester.scrollUntilVisible(find.text('Session #1'), 200);
          expect(find.text('Session #1'), findsOneWidget);
          await tester.tap(find.text('Session #1'));
          await tester.pumpAndSettle();
          expect(find.byType(ResultPage), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('fixed-back-button')));
          await tester.pumpAndSettle();
          expect(find.byType(SessionHistoryPage), findsOneWidget);
          expect(fixtures.sessions.length, 5);
          expect(fixtures.requests.every((r) => r.method == 'GET'), isTrue);
        }, fixtures.client);
      },
    );
  }

  for (final width in [320.0, 390.0, 450.0]) {
    testWidgets(
      'affected screens and fixed back controls fit ${width.toInt()}px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        addTearDown(tester.view.reset);
        final fixtures = Fixtures();
        await http.runWithClient(() async {
          final screens = <Widget>[
            const SignupScreen(),
            DashBoardPage(
              userId: 'test',
              onStartPractice: () {},
              onLearningResources: () {},
            ),
            ProgressPage(userId: 'test', onStartPractice: () {}),
            const LearningResourcesScreen(userId: 'test'),
            ResultPage(
              sessionData: session(1),
              onPracticeAgain: () {},
              onBackToHome: () {},
            ),
            SessionHistoryPage(
              userId: 'test',
              onStartPractice: () {},
              onBackToHome: () {},
            ),
            const ProfileScreen(userId: 'test'),
            const EditProfileScreen(
              userId: 'test',
              firstName: 'Test',
              lastName: 'User',
              username: 'test-user',
              userEmail: 'test@example.com',
            ),
            ScriptDetailPage(userId: 'test', script: fixtures.resources.first),
            ScriptPracticePage(
              userId: 'test',
              script: fixtures.resources.first,
            ),
            TimedChallengePage(
              userId: 'test',
              challenge: fixtures.resources.first,
            ),
            GuidedTaskDetailPage(task: fixtures.resources.last),
          ];
          for (final screen in screens) {
            const capture = bool.fromEnvironment('CAPTURE_UI');
            final captureKey = GlobalKey();
            if (capture) {
              final loader = FontLoader('Inter')
                ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
                ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
              await loader.load();
              await (FontLoader('MaterialIcons')..addFont(
                    rootBundle.load('fonts/MaterialIcons-Regular.otf'),
                  ))
                  .load();
            }
            await tester.pumpWidget(
              RepaintBoundary(
                key: captureKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(fontFamily: capture ? 'Inter' : null),
                  home: screen is DashBoardPage
                      ? Scaffold(body: screen)
                      : screen,
                ),
              ),
            );
            await tester.pumpAndSettle();
            Future<void> captureScreen(String position) async {
              if (!capture) return;
              final boundary =
                  captureKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final rendered = await boundary.toImage();
                final bytes = await rendered.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/uiux-previews/${screen.runtimeType}-${width.toInt()}-$position.png',
                );
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(bytes!.buffer.asUint8List());
                rendered.dispose();
              });
            }

            await captureScreen('top');
            if (screen is LearningResourcesScreen) {
              for (final tab in ['Challenges', 'Guided Tasks', 'Scripts']) {
                await tester.ensureVisible(find.text(tab));
                await tester.tap(find.text(tab));
                await tester.pumpAndSettle();
                await captureScreen(tab.replaceAll(' ', '-'));
              }
              await tester.ensureVisible(
                find.byKey(const ValueKey('level-filter')),
              );
              await tester.tap(find.byKey(const ValueKey('level-filter')));
              await tester.pumpAndSettle();
              expect(find.text('Beginner'), findsOneWidget);
              await captureScreen('level-menu');
              await tester.tap(find.text('Beginner'));
              await tester.pumpAndSettle();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} at $width',
            );
            final back = find.byKey(const ValueKey('fixed-back-button'));
            final before = back.evaluate().isEmpty
                ? null
                : tester.getTopLeft(back);
            final scroll = find.byType(Scrollable).first;
            await tester.drag(scroll, const Offset(0, -600));
            await tester.pumpAndSettle();
            await captureScreen('scrolled');
            if (before != null) {
              expect(
                tester.getTopLeft(back),
                before,
                reason: '${screen.runtimeType} back must stay fixed',
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} after scrolling',
            );
          }
        }, fixtures.client);
      },
    );
  }

  for (final mode in ['free', 'script', 'challenge']) {
    for (final exit in ['Practice Again', 'Back', 'system']) {
      testWidgets(
        '$mode Analysis $exit clears draft and timer while keeping the saved session',
        (tester) async {
          final fixtures = Fixtures();
          final directory = Directory.systemTemp.createTempSync(
            'ispeak_uiux_test_',
          );
          addTearDown(() => directory.deleteSync(recursive: true));
          String? recordedPath;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path,
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            (call) async {
              if (call.method == 'hasPermission') return true;
              if (call.method == 'start') {
                recordedPath = (call.arguments as Map)['path'] as String;
                File(recordedPath!).writeAsBytesSync(List.filled(64, 0));
              }
              if (call.method == 'stop') return recordedPath;
              return null;
            },
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            messenger.setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
            messenger.setMockMethodCallHandler(
              const MethodChannel('com.llfbandit.record/messages'),
              null,
            );
          });
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(home: MainPage(userId: 'test')),
            );
            await tester.pumpAndSettle();
            if (mode == 'free') {
              await tester.tap(find.byType(FloatingActionButton));
            } else {
              await tester.ensureVisible(find.text('Learning Resources'));
              await tester.tap(find.text('Learning Resources'));
              await tester.pumpAndSettle();
              if (mode == 'challenge') {
                await tester.tap(find.text('Challenges'));
                await tester.pumpAndSettle();
              }
              final title = mode == 'script'
                  ? 'Script Advanced English'
                  : 'Challenge Advanced English';
              await tester.ensureVisible(find.text(title));
              await tester.tap(find.text(title));
              await tester.pumpAndSettle();
              if (mode == 'script') {
                await tester.ensureVisible(
                  find.text('Practice with this Script'),
                );
                await tester.tap(find.text('Practice with this Script'));
              }
            }
            await tester.pumpAndSettle();
            final practiceType = mode == 'free'
                ? PracticePage
                : mode == 'script'
                ? ScriptPracticePage
                : TimedChallengePage;
            final mic = find
                .descendant(
                  of: find.byType(practiceType),
                  matching: find.byIcon(Icons.mic),
                )
                .last;
            await tester.ensureVisible(mic);
            await tester.tap(mic);
            for (var frame = 0; frame < 10; frame++) {
              await tester.pump();
            }
            await tester.pump(const Duration(seconds: 12));
            expect(find.text('00:12'), findsOneWidget);
            if (mode != 'challenge') {
              await tester.tap(find.byIcon(Icons.pause));
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Finish & Analyze Speech'));
            }
            await tester.runAsync(() async {
              await tester.tap(
                mode == 'challenge'
                    ? find.byIcon(Icons.stop_rounded)
                    : find.text('Finish & Analyze Speech'),
              );
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await tester.pumpAndSettle();
            expect(find.text('Overall Score'), findsOneWidget);
            if (exit == 'system') {
              await tester.binding.handlePopRoute();
            } else {
              await tester.ensureVisible(find.text(exit));
              await tester.tap(find.text(exit));
            }
            await tester.pump();
            for (var frame = 0; frame < 10; frame++) {
              await tester.runAsync(
                () async =>
                    Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump();
            }
            await tester.pumpAndSettle();
            expect(fixtures.sessions.length, 6);
            expect(
              fixtures.sessions.last['audioPath'],
              'https://example.invalid/saved-6.wav',
            );
            for (
              var attempt = 0;
              attempt < 10 && File(recordedPath!).existsSync();
              attempt++
            ) {
              await tester.runAsync(
                () async =>
                    Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump();
            }
            expect(File(recordedPath!).existsSync(), isFalse);
            if (exit == 'system' && mode == 'free') {
              await tester.tap(find.byType(FloatingActionButton));
              await tester.pumpAndSettle();
            }
            expect(find.text('Ready to Record'), findsOneWidget);
            expect(find.text('00:00'), findsOneWidget);
            expect(find.text('Finish & Analyze Speech'), findsNothing);
            if (mode != 'free') {
              final context = tester.element(find.byType(practiceType));
              Navigator.popUntil(context, (route) => route.isFirst);
              await tester.pumpAndSettle();
            }
            await tester.tap(find.text('Home'));
            await tester.pumpAndSettle();
            await Scrollable.ensureVisible(
              tester.element(find.text('See All Sessions')),
              alignment: 0.3,
            );
            await tester.tap(find.text('See All Sessions'));
            await tester.pumpAndSettle();
            expect(find.text('Session #6'), findsOneWidget);
            expect(
              fixtures.requests.where((r) => r.method == 'DELETE'),
              isEmpty,
            );
            await tester.pumpWidget(const MaterialApp(home: SizedBox()));
            await tester.pumpAndSettle();
          }, fixtures.client);
        },
      );
    }
  }
}
