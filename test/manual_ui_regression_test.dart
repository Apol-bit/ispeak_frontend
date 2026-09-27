import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ispeak/main.dart';
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/pages/profile_screen.dart';
import 'package:ispeak/pages/login_screen.dart';
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/services/auth_service.dart';
import 'package:ispeak/services/resource_access.dart';
import 'package:ispeak/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'uiux_revision_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  // Use the production app theme, including its text colors, to catch inherited
  // dialog/menu styles that a default MaterialApp would conceal.
  Widget app(Widget child, GlobalKey key) => Builder(
    builder: (context) {
      final theme = (const MyApp().build(context) as MaterialApp).theme;
      return RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: child,
        ),
      );
    },
  );

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final rendered = await boundary.toImage();
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/uiux-previews/manual-$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  for (final width in [320.0, 390.0, 450.0]) {
    testWidgets(
      'actual filter, result and logout widgets fit ${width.toInt()}px',
      (tester) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          addTearDown(tester.view.reset);
          final font = FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
          await font.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          final data = fixtures.Fixtures();
          await http.runWithClient(() async {
            var key = GlobalKey();
            await tester.pumpWidget(
              app(const LearningResourcesScreen(userId: 'test'), key),
            );
            await tester.pumpAndSettle();
            final chip = tester.widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'All'),
            );
            expect(chip.checkmarkColor, const Color(0xFF3D6BFF));
            expect(
              chip.selectedColor,
              AppTheme.resourceBlue.withValues(alpha: 0.12),
            );
            expect(chip.side!.color, AppTheme.resourceBlue);
            await tester.tap(find.byKey(const ValueKey('level-filter')));
            await tester.pumpAndSettle();
            expect(
              tester.widget<Text>(find.text('Advanced').last).style!.color,
              AppTheme.resourceBlue,
            );
            for (final text in tester.widgetList<Text>(
              find.text('Available'),
            )) {
              expect(text.style!.color, AppTheme.resourceBlue);
            }
            expect(tester.takeException(), isNull);
            await capture(tester, key, 'level-${width.toInt()}');
            await tester.tap(find.text('Advanced').last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Guided Tasks'));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('level-filter')), findsNothing);
            expect(find.byIcon(Icons.lock_outline), findsNothing);
            await capture(tester, key, 'guided-${width.toInt()}');
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -1200),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await capture(tester, key, 'guided-scrolled-${width.toInt()}');

            var practiced = false;
            var wentBack = false;
            for (final valid in [true, false]) {
              key = GlobalKey();
              await tester.pumpWidget(
                app(
                  ResultPage(
                    sessionData: {
                      ...fixtures.session(1),
                      'analysisValid': valid,
                    },
                    onPracticeAgain: () => practiced = true,
                    onBack: () => wentBack = true,
                  ),
                  key,
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('Back to Home'), findsNothing);
              await tester.ensureVisible(find.text('Practice Again'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await capture(tester, key, 'result-$valid-${width.toInt()}');
              await tester.tap(find.text('Practice Again'));
              await tester.tap(find.byKey(const ValueKey('fixed-back-button')));
              expect(practiced, isTrue);
              expect(wentBack, isTrue);
            }

            await AuthService.saveSession(
              token: 'test-token',
              userId: 'test',
              role: 'user',
            );
            key = GlobalKey();
            await tester.pumpWidget(
              app(const ProfileScreen(userId: 'test'), key),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Log Out'));
            await tester.tap(find.text('Log Out'));
            await tester.pumpAndSettle();
            final dialog = find.byType(AlertDialog);
            expect(dialog, findsOneWidget);
            final route = ModalRoute.of(tester.element(dialog))!;
            expect(route.barrierColor, const Color.fromRGBO(15, 18, 28, 0.5));
            final title = tester.widget<AlertDialog>(dialog).title! as Text;
            expect(title.style!.color, AppTheme.bodyInk);
            final cancel = tester.widget<TextButton>(
              find.widgetWithText(TextButton, 'Cancel'),
            );
            expect(
              cancel.style!.foregroundColor!.resolve({}),
              AppTheme.bodyInk,
            );
            final logout = tester.widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Log Out'),
            );
            expect(
              logout.style!.backgroundColor!.resolve({}),
              AppTheme.logoutRed,
            );
            expect(logout.style!.foregroundColor!.resolve({}), Colors.white);
            expect(tester.takeException(), isNull);
            await capture(tester, key, 'logout-${width.toInt()}');
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            expect(await AuthService.getToken(), 'test-token');
            expect(find.byType(ProfileScreen), findsOneWidget);
            await tester.tap(find.text('Log Out'));
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
            await tester.pumpAndSettle();
            expect(await AuthService.getToken(), isNull);
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(tester.takeException(), isNull);
          }, data.client);
        } finally {
          debugDisableShadows = previousShadows;
        }
      },
    );
  }

  for (final userLevel in ResourceAccess.levels) {
    testWidgets(
      '$userLevel opens every Guided Task while Script/Challenge gates remain',
      (tester) async {
        final data = fixtures.Fixtures()..level = userLevel;
        data.resources.addAll([
          {
            'type': 'GuidedTask',
            'title': 'Legacy unclassified task',
            'difficulty': 'None',
            'language': 'None',
            'steps': ['Breathe.'],
          },
          {
            'type': 'GuidedTask',
            'title': 'Task without metadata',
            'steps': ['Breathe.'],
          },
          {
            'type': 'GuidedTask',
            'title': 'Mixed language task',
            'difficulty': 'Advanced',
            'language': 'Taglish',
            'steps': ['Breathe.'],
          },
        ]);
        await http.runWithClient(() async {
          await tester.pumpWidget(
            app(const LearningResourcesScreen(userId: 'test'), GlobalKey()),
          );
          await tester.pumpAndSettle();
          for (final tab in ['Scripts', 'Challenges']) {
            await tester.ensureVisible(find.text(tab));
            await tester.tap(find.text(tab));
            for (final level in ResourceAccess.levels) {
              await tester.tap(find.byKey(const ValueKey('level-filter')));
              await tester.pumpAndSettle();
              await tester.tap(find.text(level).last);
              await tester.pumpAndSettle();
              final allowed = ResourceAccess.allows(userLevel, level);
              expect(
                find.text('Level: $level'),
                allowed ? findsOneWidget : findsNothing,
              );
              final type = tab == 'Scripts' ? 'Script' : 'Challenge';
              expect(
                find.text('$type $level English'),
                allowed ? findsOneWidget : findsNothing,
              );
            }
          }
          await tester.tap(find.text('Guided Tasks'));
          await tester.pumpAndSettle();
          for (final task in data.resources.where(
            (r) => r['type'] == 'GuidedTask',
          )) {
            expect(find.byKey(const ValueKey('level-filter')), findsNothing);
            expect(find.byIcon(Icons.lock_outline), findsNothing);
            final title = find.text(task['title'] as String);
            await tester.ensureVisible(title);
            await tester.pumpAndSettle();
            final requestsBefore = data.requests.length;
            await tester.tap(title);
            await tester.pumpAndSettle();
            expect(find.byType(GuidedTaskDetailPage), findsOneWidget);
            expect(
              data.requests.length,
              requestsBefore,
              reason: 'Opening a Guided Task must not verify proficiency',
            );
            await tester.tap(find.byKey(const ValueKey('fixed-back-button')));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        }, data.client);
      },
    );
  }

  testWidgets(
    'profile failure cannot lock Guided Tasks but keeps Scripts gated',
    (tester) async {
      final data = fixtures.Fixtures()..failProfile = true;
      await http.runWithClient(() async {
        await tester.pumpWidget(
          app(const LearningResourcesScreen(userId: 'test'), GlobalKey()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Script Advanced English'), findsNothing);
        await tester.tap(find.text('Guided Tasks'));
        await tester.pumpAndSettle();
        final title = find.text('GuidedTask Advanced English');
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(find.byType(GuidedTaskDetailPage), findsOneWidget);
      }, data.client);
    },
  );
}
