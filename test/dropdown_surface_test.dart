import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/pages/signup_screen.dart';
import 'package:ispeak/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uiux_revision_test.dart' as fixtures;

ThemeData _theme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  colorScheme: AppTheme.colorScheme(brightness),
  canvasColor: AppTheme.menuSurface(brightness),
  popupMenuTheme: AppTheme.popupMenuTheme(brightness),
  dropdownMenuTheme: DropdownMenuThemeData(
    menuStyle: AppTheme.menuStyle(brightness),
  ),
  menuTheme: MenuThemeData(style: AppTheme.menuStyle(brightness)),
  menuButtonTheme: MenuButtonThemeData(
    style: AppTheme.menuButtonStyle(brightness),
  ),
  hoverColor: AppTheme.resourceBlue.withValues(alpha: 0.08),
  focusColor: AppTheme.resourceBlue.withValues(alpha: 0.08),
  highlightColor: AppTheme.resourceBlue.withValues(alpha: 0.08),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'Light' : 'Dark';

    testWidgets('Name Extension dropdown uses the $mode menu surface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: _theme(brightness), home: const SignupScreen()),
      );
      final dropdown = find.byKey(const ValueKey('name-extension'));
      final dropdownButton = find.descendant(
        of: dropdown,
        matching: find.byWidgetPredicate(
          (widget) => widget is DropdownButton<String>,
        ),
      );
      expect(
        tester.widget<DropdownButton<String>>(dropdownButton).dropdownColor,
        AppTheme.menuSurface(brightness),
      );
      final input = find.descendant(
        of: dropdown,
        matching: find.byType(InputDecorator),
      );
      expect(
        tester.widget<InputDecorator>(input).decoration.fillColor,
        AppTheme.menuSurface(brightness),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      for (final label in ['None / Blank', 'Jr.', 'Sr.', 'III', 'IV', 'V']) {
        expect(find.text(label), findsWidgets);
      }
      expect(
        tester.widget<Text>(find.text('None / Blank').last).style?.color,
        AppTheme.resourceBlue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Learning Resources level menu uses the $mode menu surface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final data = fixtures.Fixtures();

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(brightness),
            home: const LearningResourcesScreen(userId: 'test'),
          ),
        );
        await tester.pumpAndSettle();
        final levelFilter = find.byKey(const ValueKey('level-filter'));
        expect(
          tester.widget<PopupMenuButton<String>>(levelFilter).color,
          AppTheme.menuSurface(brightness),
        );
        await tester.tap(levelFilter);
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.text('Advanced').last).style?.color,
          AppTheme.resourceBlue,
        );
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, data.client);
    });
  }

  for (final width in [320.0, 360.0, 390.0, 412.0, 450.0]) {
    testWidgets('dropdown overlays fit at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          home: const SignupScreen(),
        ),
      );
      final nameExtension = find.byKey(const ValueKey('name-extension'));
      await tester.ensureVisible(nameExtension);
      await tester.tap(nameExtension);
      await tester.pumpAndSettle();
      expect(find.text('None / Blank'), findsWidgets);
      expect(find.text('V'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
