import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ispeak/main.dart';
import 'package:ispeak/pages/login_screen.dart';
import 'package:ispeak/pages/signup_screen.dart';
import 'package:ispeak/pages/dashboard_page.dart';
import 'package:ispeak/pages/practice_page.dart';
import 'package:ispeak/pages/script_practice_page.dart';
import 'package:ispeak/pages/time_challenge_page.dart';
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/pages/session_history_page.dart';
import 'package:ispeak/pages/progress_page.dart';
import 'package:ispeak/pages/profile_screen.dart';
import 'package:ispeak/pages/editprofile_screen.dart';
import 'package:ispeak/pages/terms_conditions_screen.dart';
import 'package:ispeak/widgets/primary_button.dart';
import 'uiux_revision_test.dart' as fixtures;
import 'resource_loading_pagination_test.dart' show capture;

Map<String, Widget> screens(fixtures.Fixtures data) => {
  'login': const LoginScreen(),
  'signup': const SignupScreen(),
  'home': Scaffold(
    body: DashBoardPage(
      userId: 'test',
      onStartPractice: () {},
      onLearningResources: () {},
    ),
  ),
  'practice': Scaffold(
    body: PracticePage(userId: 'test', onFinish: (_) {}),
  ),
  'script': ScriptPracticePage(userId: 'test', script: data.resources.first),
  'challenge': TimedChallengePage(
    userId: 'test',
    challenge: data.resources.first,
  ),
  'resources': const LearningResourcesScreen(userId: 'test'),
  'guided': GuidedTaskDetailPage(task: data.resources.last),
  'results': ResultPage(
    sessionData: fixtures.session(1),
    onPracticeAgain: () {},
  ),
  'history': SessionHistoryPage(
    userId: 'test',
    onStartPractice: () {},
    onBackToHome: () {},
  ),
  'progress': ProgressPage(userId: 'test', onStartPractice: () {}),
  'profile': const ProfileScreen(userId: 'test'),
  'edit': const EditProfileScreen(
    userId: 'test',
    firstName: 'Test',
    lastName: 'User',
    username: 'test',
    userEmail: 'test@example.test',
  ),
  'terms': const TermsConditionsScreen(),
  'navigation': const MainPage(userId: 'test'),
};

Widget app(Widget child, GlobalKey key, double scale) => Builder(
  builder: (context) => RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: (const MyApp().build(context) as MaterialApp).theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'fixture-token'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        );
  });
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 360.0, 390.0, 412.0, 450.0]) {
    for (final scale in [1.0, 1.2, 1.3]) {
      for (final name in screens(fixtures.Fixtures()).keys) {
        testWidgets('$name width=$width text=$scale with safe insets', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, scale == 1.3 ? 568 : 844);
          tester.view.viewPadding = const FakeViewPadding(
            top: 32,
            bottom: 24,
            left: 4,
            right: 4,
          );
          tester.view.padding = const FakeViewPadding(
            top: 32,
            bottom: 24,
            left: 4,
            right: 4,
          );
          addTearDown(tester.view.reset);
          final data = fixtures.Fixtures();
          final key = GlobalKey();
          await http.runWithClient(() async {
            await tester.pumpWidget(app(screens(data)[name]!, key, scale));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'initial $name');
            if (name == 'resources') {
              await tester.tap(find.byKey(const ValueKey('level-filter')));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'level dropdown');
              await tester.tap(find.text('Advanced').last);
              await tester.pumpAndSettle();
              for (final tab in ['Challenges', 'Guided Tasks', 'Scripts']) {
                await tester.ensureVisible(find.text(tab));
                await tester.tap(find.text(tab));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull, reason: tab);
              }
            }
            if (name == 'navigation') {
              for (final label in ['Progress', 'Home']) {
                final nav = find.descendant(
                  of: find.byType(BottomAppBar),
                  matching: find.text(label),
                );
                final rect = tester.getRect(nav);
                expect(
                  rect.bottom,
                  lessThanOrEqualTo(tester.view.physicalSize.height - 24),
                );
                expect(nav.hitTestable(), findsOneWidget);
                await tester.tap(nav);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
              await tester.tap(find.byType(FloatingActionButton));
              await tester.pumpAndSettle();
              expect(find.byType(PracticePage), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
            if (const bool.fromEnvironment('CAPTURE_UI') &&
                (width == 320 || width == 450) &&
                scale == 1.3) {
              await capture(tester, key, 'mobile-$name-$width-top');
            }
            if (find.byType(Scrollable).evaluate().isNotEmpty) {
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -1800),
              );
              await tester.pumpAndSettle();
            }
            final buttons = find.byType(PrimaryButton);
            if (buttons.evaluate().isNotEmpty) {
              await tester.ensureVisible(buttons.last);
              await tester.pumpAndSettle();
              final rect = tester.getRect(buttons.last);
              expect(rect.left, greaterThanOrEqualTo(4));
              expect(rect.right, lessThanOrEqualTo(width - 4));
              expect(
                rect.bottom,
                lessThanOrEqualTo(tester.view.physicalSize.height - 24),
                reason: 'primary button above gesture area',
              );
              expect(rect.height, greaterThanOrEqualTo(48));
            }
            expect(tester.takeException(), isNull, reason: 'scrolled $name');
            if (const bool.fromEnvironment('CAPTURE_UI') &&
                (width == 320 || width == 450) &&
                scale == 1.3) {
              await capture(tester, key, 'mobile-$name-$width-bottom');
            }
            if (name == 'profile') {
              await tester.ensureVisible(find.text('Log Out'));
              await tester.tap(find.text('Log Out'));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(find.text('Cancel').hitTestable(), findsOneWidget);
              expect(
                find.widgetWithText(ElevatedButton, 'Log Out').hitTestable(),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull, reason: 'logout dialog');
              await tester.tap(find.text('Cancel'));
              await tester.pumpAndSettle();
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          }, data.client);
        });
      }
    }
    for (final name in ['login', 'signup', 'edit']) {
      testWidgets('$name keyboard at $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 568);
        tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
        tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
        addTearDown(tester.view.reset);
        final data = fixtures.Fixtures();
        await http.runWithClient(() async {
          await tester.pumpWidget(app(screens(data)[name]!, GlobalKey(), 1.3));
          await tester.pumpAndSettle();
          final input = find
              .byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              )
              .last;
          await tester.ensureVisible(input);
          await tester.tap(input);
          await tester.pump();
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          tester.view.padding = const FakeViewPadding(top: 32);
          await tester.pumpAndSettle();
          await tester.ensureVisible(input);
          await tester.pumpAndSettle();
          expect(tester.getRect(input).bottom, lessThanOrEqualTo(308));
          final button = find.byType(PrimaryButton).last;
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(tester.getRect(button).bottom, lessThanOrEqualTo(308));
          expect(button.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }, data.client);
      });
    }
  }
}
