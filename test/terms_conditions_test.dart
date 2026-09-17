import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/pages/signup_screen.dart';
import 'package:ispeak/pages/terms_conditions_screen.dart';

void main() {
  testWidgets('terms can be opened and accepted from sign up', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.scrollUntilVisible(
      find.text('Terms & Conditions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();

    expect(find.byType(TermsConditionsScreen), findsOneWidget);
    expect(find.text('Please read before continuing'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('declining terms clears previous acceptance', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.scrollUntilVisible(
      find.text('Terms & Conditions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Keep Accepted'), findsOneWidget);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
  });

  testWidgets('terms remain usable on a small phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: TermsConditionsScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });
}
