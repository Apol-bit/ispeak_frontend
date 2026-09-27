import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ispeak/main.dart';
import 'package:ispeak/pages/learning_resources_page.dart';
import 'package:ispeak/pages/session_history_page.dart';
import 'package:ispeak/pages/result_page.dart';
import 'package:ispeak/widgets/loading_skeleton.dart';
import 'package:ispeak/widgets/resource_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'uiux_revision_test.dart' as fixtures;

Widget app(Widget child, GlobalKey key) => Builder(
  builder: (context) => RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: (const MyApp().build(context) as MaterialApp).theme,
      home: child,
    ),
  ),
);
Widget history() => SessionHistoryPage(
  userId: 'test',
  onStartPractice: () {},
  onBackToHome: () {},
);
http.Response page(
  List<Map<String, dynamic>> rows, {
  String cursor = '',
  int total = 30,
}) => http.Response(
  jsonEncode(rows),
  200,
  headers: {'x-next-cursor': cursor, 'x-total-count': '$total'},
);
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final rendered = await boundary.toImage();
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/uiux-previews/loading-$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    rendered.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'fixture-token'});
  });
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('stored icon names resolve predictably, including invalid values', () {
    expect(ResourceIcon.resolve('flash_on'), Icons.flash_on);
    expect(ResourceIcon.resolve('volume_up'), Icons.volume_up);
    expect(ResourceIcon.resolve('timer'), Icons.timer);
    for (final value in [null, '', '  ', 'unknown', 42, <String>[]]) {
      expect(ResourceIcon.resolve(value), ResourceIcon.fallback);
    }
  });
  for (final width in [320.0, 390.0, 450.0]) {
    for (final resources in [false, true]) {
      for (final outcome in ['success', 'empty', 'error']) {
        testWidgets(
          '${resources ? 'Resources' : 'History'} initial skeleton to $outcome at $width',
          (tester) async {
            tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final gate = Completer<void>();
            final requests = <Uri>[];
            final key = GlobalKey();
            final fixture = fixtures.Fixtures();
            for (final resource in fixture.resources) {
              resource['iconName'] = 'flash_on';
            }
            await http.runWithClient(
              () async {
                await tester.pumpWidget(
                  app(
                    resources
                        ? const LearningResourcesScreen(userId: 'test')
                        : history(),
                    key,
                  ),
                );
                await tester.pumpAndSettle();
                expect(find.byType(SkeletonList), findsOneWidget);
                expect(find.textContaining('No sessions'), findsNothing);
                expect(find.textContaining('No resources'), findsNothing);
                final skeleton = find.byType(SkeletonList);
                expect(
                  find.descendant(of: skeleton, matching: find.byType(InkWell)),
                  findsNothing,
                );
                expect(
                  find.descendant(
                    of: skeleton,
                    matching: find.byType(IgnorePointer),
                  ),
                  findsOneWidget,
                );
                final requestsBefore = requests.length;
                await tester.pump(const Duration(seconds: 3));
                expect(requests.length, requestsBefore);
                if (outcome == 'success') {
                  await capture(
                    tester,
                    key,
                    '${resources ? 'resources' : 'history'}-$width',
                  );
                }
                gate.complete();
                await tester.pumpAndSettle();
                expect(find.byType(SkeletonList), findsNothing);
                if (outcome == 'error') {
                  expect(find.text('Try Again'), findsOneWidget);
                }
                if (outcome == 'empty') {
                  expect(find.textContaining('No '), findsWidgets);
                }
                if (outcome == 'success') {
                  if (resources) {
                    await tester.tap(find.text('Guided Tasks'));
                    await tester.pumpAndSettle();
                    expect(find.byIcon(Icons.flash_on), findsWidgets);
                    expect(
                      find.byKey(const ValueKey('level-filter')),
                      findsNothing,
                    );
                    expect(
                      requests.length,
                      3,
                    ); // resources + current-level profile/statistics only
                  } else {
                    expect(find.text('Session #1'), findsOneWidget);
                    expect(requests.length, 1);
                  }
                }
                await capture(
                  tester,
                  key,
                  '${resources ? 'resources' : 'history'}-$outcome-$width',
                );
                expect(tester.takeException(), isNull);
              },
              () => MockClient((request) async {
                requests.add(request.url);
                await gate.future;
                if (outcome == 'error') return http.Response('{}', 503);
                if (request.url.path.contains('/sessions/')) {
                  return page(
                    outcome == 'empty' ? [] : [fixtures.session(1)],
                    total: 1,
                  );
                }
                if (request.url.path.endsWith('/resources')) {
                  return http.Response(
                    jsonEncode(outcome == 'empty' ? [] : fixture.resources),
                    200,
                  );
                }
                if (request.url.path.contains('/user/')) {
                  return http.Response('{"initialLevel":"Beginner"}', 200);
                }
                return http.Response(
                  '{"overallStats":{"totalSessions":0}}',
                  200,
                );
              }),
            );
          },
        );
      }
    }
    testWidgets(
      'history automatic paging retains rows, retries, deduplicates, stops, refreshes at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final requests = <Uri>[];
        var next = Completer<http.Response>();
        var firstPage = Completer<http.Response>()
          ..complete(
            page([
              for (var i = 30; i >= 11; i--) fixtures.session(i),
            ], cursor: 'older'),
          );
        await http.runWithClient(
          () async {
            await tester.pumpWidget(app(history(), key));
            await tester.pumpAndSettle();
            expect(requests.length, 1);
            expect(find.text('Load more'), findsNothing);
            final list = find.byType(ListView);
            final controller = tester.widget<ListView>(list).controller!;
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            await tester.scrollUntilVisible(find.text('Session #11'), 400);
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pump();
            expect(requests.length, 2);
            expect(requests.last.queryParameters, {
              'limit': '20',
              'before': 'older',
            });
            expect(find.byType(SkeletonList), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            expect(find.text('Session #11'), findsOneWidget);
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pump(const Duration(seconds: 2));
            expect(
              requests.length,
              2,
              reason: 'only one request may be pending',
            );
            await capture(tester, key, 'history-bottom-loader-$width');
            next.complete(http.Response('{}', 503));
            await tester.pumpAndSettle();
            expect(find.text('Session #11'), findsOneWidget);
            expect(find.textContaining('Unable to load more'), findsOneWidget);
            await tester.pump(const Duration(seconds: 4));
            expect(requests.length, 2, reason: 'no error polling');
            next = Completer<http.Response>();
            await tester.ensureVisible(find.text('Try Again'));
            await tester.tap(find.text('Try Again'));
            await tester.pump();
            expect(requests.length, 3);
            next.complete(
              page([
                fixtures.session(11),
                for (var i = 10; i >= 1; i--) fixtures.session(i),
              ]),
            );
            await tester.pumpAndSettle();
            // Inspect retained children as well as visible rows: exactly 30 unique sessions, newest first.
            final children =
                (tester.widget<ListView>(list).childrenDelegate
                        as SliverChildListDelegate)
                    .children;
            final titles = children
                .whereType<Card>()
                .map((card) => ((card.child as ListTile).title as Text).data)
                .toList();
            expect(titles, [for (var i = 30; i >= 1; i--) 'Session #$i']);
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pumpAndSettle();
            await tester.pump(const Duration(seconds: 3));
            expect(requests.length, 3);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            firstPage = Completer<http.Response>();
            final refresh = tester
                .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                .onRefresh();
            await tester.pump();
            expect(find.byType(SkeletonList), findsNothing);
            expect(find.text('Session #1'), findsOneWidget);
            firstPage.complete(
              page([fixtures.session(30)], cursor: 'refreshed', total: 2),
            );
            next = Completer<http.Response>()
              ..complete(page([fixtures.session(29)], total: 2));
            await refresh;
            await tester.pumpAndSettle();
            expect(requests.length, 5);
            expect(requests[3].queryParameters, {'limit': '20'});
            expect(requests[4].queryParameters['before'], 'refreshed');
            expect(find.text('Session #2'), findsOneWidget);
            expect(find.text('Session #1'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) {
            requests.add(request.url);
            return request.url.queryParameters.containsKey('before')
                ? next.future
                : firstPage.future;
          }),
        );
      },
    );
  }
  testWidgets(
    'history prefetches before the bottom, continues through three pages and opens an appended result',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final requests = <http.Request>[];
      final second = Completer<http.Response>();
      final third = Completer<http.Response>();
      Map<String, dynamic> row(int number) => {
        ...fixtures.session(1),
        '_id': 'saved-$number',
        'createdAt': DateTime.utc(
          2026,
          1,
          1,
        ).add(Duration(days: number)).toIso8601String(),
        'overallScore': number,
      };
      final first = page(
        [for (var n = 60; n >= 41; n--) row(n)],
        cursor: 'page-2',
        total: 60,
      );
      await http.runWithClient(
        () async {
          await tester.pumpWidget(app(history(), GlobalKey()));
          await tester.pumpAndSettle();
          expect(requests.length, 1);
          expect(
            find.textContaining(RegExp('load more', caseSensitive: false)),
            findsNothing,
          );
          final list = find.byType(ListView);
          final controller = tester.widget<ListView>(list).controller!;
          controller.jumpTo(controller.position.maxScrollExtent - 200);
          expect(controller.position.extentAfter, closeTo(200, .01));
          await tester.pump();
          await tester.pump();
          expect(
            requests.length,
            2,
            reason: 'prefetch must start before the absolute bottom',
          );
          expect(requests.last.url.queryParameters['before'], 'page-2');
          controller.jumpTo(controller.position.maxScrollExtent - 100);
          await tester.pump();
          expect(
            requests.length,
            2,
            reason: 'rapid scrolling must not duplicate a pending request',
          );
          second.complete(
            page(
              [for (var n = 41; n >= 21; n--) row(n)],
              cursor: 'page-3',
              total: 60,
            ),
          );
          await tester.pumpAndSettle();
          List<ListTile> tiles() =>
              (tester.widget<ListView>(list).childrenDelegate
                      as SliverChildListDelegate)
                  .children
                  .whereType<Card>()
                  .map((card) => card.child! as ListTile)
                  .toList();
          expect(
            tiles().length,
            40,
            reason: 'overlapping saved-41 must be deduplicated',
          );
          expect(tiles().map((tile) => (tile.trailing as Text).data), [
            for (var n = 60; n >= 21; n--) '$n',
          ]);
          controller.jumpTo(controller.position.maxScrollExtent - 200);
          await tester.pump();
          await tester.pump();
          expect(requests.length, 3);
          expect(requests.last.url.queryParameters['before'], 'page-3');
          third.complete(
            page([for (var n = 20; n >= 1; n--) row(n)], total: 60),
          );
          await tester.pumpAndSettle();
          expect(tiles().length, 60);
          expect(tiles().map((tile) => (tile.trailing as Text).data), [
            for (var n = 60; n >= 1; n--) '$n',
          ]);
          await tester.scrollUntilVisible(
            find.text('Session #1'),
            600,
            maxScrolls: 30,
          );
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 3));
          expect(
            requests.length,
            3,
            reason: 'the terminal cursor must stop further requests',
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          await tester.tap(find.text('Session #1'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ResultPage>(find.byType(ResultPage))
                .sessionData!['_id'],
            'saved-1',
          );
          await tester.tap(find.byKey(const ValueKey('fixed-back-button')));
          await tester.pumpAndSettle();
          expect(find.byType(SessionHistoryPage), findsOneWidget);
          expect(
            requests.every(
              (r) =>
                  r.method == 'GET' && r.url.queryParameters['limit'] == '20',
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) {
          requests.add(request);
          return switch (request.url.queryParameters['before']) {
            'page-2' => second.future,
            'page-3' => third.future,
            _ => Future.value(first),
          };
        }),
      );
    },
  );

  testWidgets(
    'history refresh supersedes a pending older page and preserves rows on refresh error',
    (tester) async {
      final old = Completer<http.Response>();
      var refresh = Completer<http.Response>();
      var count = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(app(history(), GlobalKey()));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(
            count,
            2,
          ); // short first page automatically asks for the next page
          final onRefresh = tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh;
          final pending = onRefresh();
          await tester.pump();
          refresh.complete(page([fixtures.session(5)], total: 1));
          await pending;
          await tester.pumpAndSettle();
          old.complete(page([fixtures.session(1)], total: 2));
          await tester.pumpAndSettle();
          expect(find.text('Session #2'), findsNothing);
          expect(find.text('Session #1'), findsOneWidget);
          refresh = Completer<http.Response>();
          final failed = onRefresh();
          await tester.pump();
          refresh.complete(http.Response('{}', 503));
          await failed;
          await tester.pumpAndSettle();
          expect(find.text('Session #1'), findsOneWidget);
          expect(find.text('Try Again'), findsOneWidget);
          expect(find.byType(SkeletonList), findsNothing);
          expect(count, 4);
        },
        () => MockClient((request) async {
          count++;
          if (count == 1) {
            return page([fixtures.session(2)], cursor: 'older', total: 2);
          }
          if (request.url.queryParameters.containsKey('before')) {
            return old.future;
          }
          return refresh.future;
        }),
      );
    },
  );
}
