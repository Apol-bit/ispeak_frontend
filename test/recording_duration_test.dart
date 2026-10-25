import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ispeak/pages/practice_page.dart';
import 'package:ispeak/pages/script_practice_page.dart';
import 'package:ispeak/pages/time_challenge_page.dart';
import 'package:ispeak/services/recording_limits.dart';

void main() {
  test('challenge limits retain shorter settings and cap at five minutes', () {
    expect(challengeRecordingLimit(60), 60);
    expect(challengeRecordingLimit(300), 300);
    expect(challengeRecordingLimit(600), 300);
    for (final value in [null, '60', 0, -1, double.nan]) {
      expect(challengeRecordingLimit(value), 60);
    }
  });

  for (final mode in ['ordinary', 'script', 'challenge']) {
    for (final scenario in ['limit', 'interruption', 'failure']) {
      final interrupted = scenario == 'interruption';
      testWidgets('$mode recording $scenario and cleanup', (tester) async {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        final directory = Directory.systemTemp.createTempSync(
          'ispeak-duration-',
        );
        String? path;
        var stops = 0;
        var pauses = 0;
        var uploads = 0;
        Future<void> flushFileIO() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
        }

        String? uploaded;
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
              path = (call.arguments as Map)['path'] as String;
              File(path!).writeAsBytesSync(List.filled(64, 0));
              if (scenario == 'failure') {
                throw PlatformException(code: 'recording_failed');
              }
            }
            if (call.method == 'pause') pauses++;
            if (call.method == 'stop') {
              stops++;
              return path;
            }
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
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        });
        final resource = {
          '_id': '507f1f77bcf86cd799439011',
          'title': 'Fixture',
          'difficulty': 'Beginner',
          'content': 'A small practice script.',
          'language': 'English',
          'timeLimitSeconds': 60,
        };
        final page = mode == 'ordinary'
            ? const PracticePage(userId: 'test')
            : mode == 'script'
            ? ScriptPracticePage(userId: 'test', script: resource)
            : TimedChallengePage(userId: 'test', challenge: resource);
        await http.runWithClient(
          () async {
            await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byIcon(Icons.mic).last);
            await tester.tap(find.byIcon(Icons.mic).last);
            await tester.pumpAndSettle();
            expect(path, isNotNull);
            if (scenario == 'failure') {
              await flushFileIO();
              expect(uploads, 0);
              expect(File(path!).existsSync(), false);
            } else if (interrupted) {
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.paused,
              );
              await flushFileIO();
              await tester.pumpAndSettle();
              if (mode == 'challenge') {
                expect(stops, 1);
              } else {
                expect(pauses, 1);
              }
              await tester.pump(const Duration(seconds: 400));
              expect(uploads, 0);
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
            } else {
              final limit = mode == 'challenge' ? 60 : 300;
              await tester.pump(Duration(seconds: limit - 1));
              expect(stops, 0);
              await tester.pump(const Duration(seconds: 2));
              await flushFileIO();
              await tester.pumpAndSettle();
              expect(stops, 1);
              if (mode == 'challenge') {
                expect(uploads, 1);
              } else {
                expect(uploads, 0);
                expect(
                  find.textContaining('5-minute limit reached'),
                  findsOneWidget,
                );
                await tester.ensureVisible(
                  find.text('Finish & Analyze Speech'),
                );
                await tester.tap(find.text('Finish & Analyze Speech'));
                await flushFileIO();
                await tester.pumpAndSettle();
                expect(uploads, 1);
                expect(uploaded, contains('300'));
              }
            }
            await tester.pumpWidget(const SizedBox());
            await flushFileIO();
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              for (var i = 0; i < 20 && File(path!).existsSync(); i++) {
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
              expect(File(path!).existsSync(), false);
            });
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.url.path.endsWith('/upload-audio')) {
              uploads++;
              uploaded = request.body;
              return http.Response(
                '{"message":"Controlled test rejection"}',
                400,
              );
            }
            return http.Response(
              jsonEncode(
                request.url.path.contains('/stats/')
                    ? {
                        'overallStats': {'eligibleScoredSessions': 0},
                      }
                    : {'initialLevel': 'Beginner'},
              ),
              200,
            );
          }),
        );
      });
    }
  }
}
