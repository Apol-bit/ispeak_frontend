import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ispeak/pages/demographic_screen.dart';
import 'package:ispeak/pages/signup_screen.dart';
import 'package:ispeak/services/auth_service.dart';
import 'package:ispeak/widgets/primary_button.dart';

void main() {
  for (final scenario in [
    (suffix: '', rejected: false),
    (suffix: 'Jr.', rejected: false),
    (suffix: '', rejected: true),
  ]) {
    final suffix = scenario.suffix;
    testWidgets('public signup suffix=$suffix rejected=${scenario.rejected}', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      Map<String, dynamic>? submitted;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(MaterialApp(home: const SignupScreen()));
          final fields = find.byType(TextFormField);
          final values = [
            'Ana',
            'Santos',
            'ana-santos',
            'ana@example.com',
            'StrongPassword123!',
            'StrongPassword123!',
          ];
          for (var index = 0; index < values.length; index++) {
            await tester.ensureVisible(fields.at(index));
            await tester.enterText(fields.at(index), values[index]);
          }
          tester.testTextInput.hide();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          if (suffix.isNotEmpty) {
            final dropdown = find.byKey(const ValueKey('name-extension'));
            await tester.ensureVisible(dropdown);
            await tester.tap(dropdown);
            await tester.pumpAndSettle();
            await tester.tap(find.text(suffix).last);
            await tester.pumpAndSettle();
          }
          final invitation = find.byKey(const ValueKey('invitation-code'));
          expect(invitation, findsNothing);
          await tester.ensureVisible(find.byType(Checkbox));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
          await tester.ensureVisible(find.byType(PrimaryButton));
          await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          expect(
            submitted?['lastName'],
            suffix.isEmpty ? 'Santos' : 'Santos Jr.',
          );
          expect(submitted?['acceptTerms'], isTrue);
          expect(submitted?.containsKey('nameExtension'), isFalse);
          expect(submitted?.containsKey('invitationCode'), isFalse);
          if (scenario.rejected) {
            expect(
              find.text(
                'Registration is currently unavailable. Please try again later.',
              ),
              findsOneWidget,
            );
            expect(await AuthService.getToken(), isNull);
            expect(find.byType(DemographicScreen), findsNothing);
            expect(tester.takeException(), isNull);
            return;
          }
          expect(await AuthService.getToken(), 'test-token');
          final onboarding = tester.widget<DemographicScreen>(
            find.byType(DemographicScreen),
          );
          expect(onboarding.userId, 'new-user');
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          if (scenario.rejected) {
            return http.Response(
              jsonEncode({
                'message':
                    'Registration is currently unavailable. Please try again later.',
              }),
              403,
            );
          }
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {
                'id': 'new-user',
                'role': 'user',
                'username': 'ana-santos',
              },
            }),
            201,
          );
        }),
      );
    });
  }
}
