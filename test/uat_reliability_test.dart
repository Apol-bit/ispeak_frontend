import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ispeak/pages/session_history_page.dart';
import 'package:ispeak/services/api_client.dart';
import 'package:ispeak/services/auth_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'valid-token'});
    ApiClient.onAuthenticationExpired = null;
  });

  for (final status in [500, 502, 503, 504, 429]) {
    test(
      'HTTP $status preserves credentials during validation and API use',
      () async {
        await http.runWithClient(() async {
          expect(await AuthService.validateSession(), isNull);
          expect(await AuthService.getToken(), 'valid-token');
          var expired = false;
          ApiClient.onAuthenticationExpired = () async => expired = true;
          expect(
            (await ApiClient.get(
              Uri.parse('https://example.test/stats'),
            )).statusCode,
            status,
          );
          expect(await AuthService.getToken(), 'valid-token');
          expect(expired, isFalse);
        }, () => MockClient((_) async => http.Response('{}', status)));
      },
    );
  }

  test('network failure preserves token; actual 401 clears it', () async {
    await http.runWithClient(() async {
      expect(await AuthService.validateSession(), isNull);
      expect(await AuthService.getToken(), 'valid-token');
    }, () => MockClient((_) async => throw http.ClientException('offline')));
    await http.runWithClient(() async {
      expect(await AuthService.validateSession(), isNull);
      expect(await AuthService.getToken(), isNull);
    }, () => MockClient((_) async => http.Response('{}', 401)));
  });

  testWidgets('History loads older pages without losing saved sessions', (
    tester,
  ) async {
    final requests = <Uri>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: SessionHistoryPage(
              userId: 'user',
              onStartPractice: () {},
              onBackToHome: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Session #2'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('Session #2'), findsOneWidget);
        expect(find.text('Session #1'), findsOneWidget);
        expect(find.text('Load more'), findsNothing);
        expect(requests.last.queryParameters['before'], 'next-page');
        expect(requests.first.queryParameters['limit'], '20');
      },
      () => MockClient((request) async {
        requests.add(request.url);
        final more = request.url.queryParameters.containsKey('before');
        return http.Response(
          jsonEncode([
            {
              '_id': more ? 'old' : 'new',
              'createdAt': more
                  ? '2026-09-01T00:00:00Z'
                  : '2026-09-02T00:00:00Z',
              'overallScore': 75,
            },
          ]),
          200,
          headers: {
            'x-total-count': '2',
            'x-next-cursor': more ? '' : 'next-page',
          },
        );
      }),
    );
  });
}
