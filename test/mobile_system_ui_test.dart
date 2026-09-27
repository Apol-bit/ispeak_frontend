import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/widgets/mobile_system_ui.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final modes = <Object?>[];
  setUp(() {
    modes.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments);
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  void androidTest(String name, WidgetTesterCallback callback) => testWidgets(
    name,
    callback,
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
  Widget app() => MaterialApp(
    builder: (context, child) => MobileSystemUi(child: child!),
    home: const Scaffold(body: Text('Home')),
  );

  androidTest('one Android request survives rebuilds, routes and dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(modes, ['SystemUiMode.immersiveSticky']);
    await tester.pumpWidget(app());
    final context = tester.element(find.text('Home'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Results')),
      ),
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: tester.element(find.text('Results')),
      builder: (_) => const AlertDialog(title: Text('Permission explanation')),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Results'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(modes, hasLength(1));
  });

  androidTest(
    'keyboard dismissal waits beyond Android one-second restriction',
    (tester) async {
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(seconds: 2));
      expect(modes, hasLength(1));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(seconds: 1));
      expect(modes, hasLength(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(modes, hasLength(2));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(milliseconds: 500));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(seconds: 2));
      expect(
        modes,
        hasLength(2),
        reason: 'reopening keyboard cancels restoration',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  androidTest(
    'resume after background or permission interruption restores once',
    (tester) async {
      await tester.pumpWidget(app());
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.inactive,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
        await tester.pump(const Duration(seconds: 2));
        final before = modes.length;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 1100));
        expect(modes, hasLength(before + 1));
      }
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      final before = modes.length;
      await tester.pump(const Duration(seconds: 2));
      expect(modes, hasLength(before), reason: 'dispose cancels pending timer');
    },
  );

  androidTest('resume does not force bars while keyboard is visible', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(modes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.windows]) {
    testWidgets(
      '$platform keeps platform system UI',
      (tester) async {
        await tester.pumpWidget(app());
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(seconds: 2));
        expect(modes, isEmpty);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
