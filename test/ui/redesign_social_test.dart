import 'dart:io';
import 'dart:ui' as ui;

import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/user.dart';
import 'package:fling/screens/discover/discover_screen.dart';
import 'package:fling/screens/feed/feed_screen.dart';
import 'package:fling/screens/calls/incoming_call_view.dart';
import 'package:fling/screens/messages/messages_screen.dart';
import 'package:fling/screens/lobby/lobby_create_screen.dart';
import 'package:fling/screens/live/live_ended_screen.dart';
import 'package:fling/screens/live/live_feed_screen.dart';
import 'package:fling/screens/lobby/source_picker_screen.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends AuthProvider {
  final User _u = User.fromJson({'id': 'me', 'name': 'Test User'});
  @override
  User? get user => _u;
}

Future<GlobalKey> _render(WidgetTester tester, Widget screen,
    {Size size = const Size(390, 844), double text = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: _FakeAuth(),
    child: MaterialApp(
      theme: AppTheme.darkWithoutWebFonts(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: RepaintBoundary(key: key, child: Scaffold(body: screen)),
      ),
    ),
  ));
  // No server in tests: let the failed loads settle into empty states.
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  return key;
}

Future<void> _snap(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/design-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await loader.load();
  });

  testWidgets('Feed renders its header, chips and new-post button', (t) async {
    final key = await _render(t, const FeedScreen());
    expect(t.takeException(), isNull);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.bySemanticsLabel('New post'), findsOneWidget);
    await _snap(t, key, 'feed');
  });

  testWidgets('Discover header and filters sheet', (t) async {
    final key = await _render(t, const DiscoverScreen());
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('Filters'));
    await t.pumpAndSettle();
    expect(find.text('SHOW ME'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _snap(t, key, 'discover-filters');
  });

  testWidgets('Messages renders search, filters and empty state', (t) async {
    final key = await _render(t, const MessagesScreen());
    expect(t.takeException(), isNull);
    expect(find.text('Search chats'), findsOneWidget);
    await _snap(t, key, 'messages');
  });

  testWidgets('Incoming call shows both actions', (t) async {
    var accepted = 0, declined = 0;
    final key = await _render(
        t,
        IncomingCallView(
            name: 'Chitra',
            video: true,
            onAccept: () => accepted++,
            onDecline: () => declined++));
    await t.tap(find.text('Accept'));
    await t.tap(find.text('Decline'));
    expect([accepted, declined], [1, 1]);
    await _snap(t, key, 'incoming-call');
  });

  testWidgets('Start a room shows all four types and the theme picker',
      (t) async {
    final key = await _render(t, const LobbyCreateScreen());
    expect(t.takeException(), isNull);
    expect(find.text('Go live'), findsOneWidget);
    expect(find.text('Lobby theme'), findsOneWidget);
    await _snap(t, key, 'start-room');
    await t.tap(find.text('Game room'));
    await t.pump();
    expect(find.text('Choose a game'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Source picker groups free and subscription sources', (t) async {
    final key =
        await _render(t, const SourcePickerScreen(visibility: 'public'));
    expect(t.takeException(), isNull);
    expect(find.text('FREE'), findsOneWidget);
    await _snap(t, key, 'source-picker');
  });

  testWidgets('Live tab and live ended summary', (t) async {
    var key = await _render(t, const LiveFeedScreen());
    expect(t.takeException(), isNull);
    expect(find.text('Go live'), findsWidgets);
    await _snap(t, key, 'live-feed');
    key = await _render(
        t,
        const LiveEndedScreen(
            title: 'Singing your requests',
            duration: Duration(minutes: 72),
            viewers: 1086,
            peak: 312));
    expect(find.text('Live ended'), findsOneWidget);
    await _snap(t, key, 'live-ended');
  });

  for (final s in [
    const LiveFeedScreen(),
    const LiveEndedScreen(
        title: 'A very long live title that keeps going and going',
        duration: Duration(hours: 2),
        viewers: 123456,
        peak: 99999),
    const LobbyCreateScreen(initialRoomType: 'live'),
    const LobbyCreateScreen(),
    const SourcePickerScreen(visibility: 'public'),
    const FeedScreen(),
    const DiscoverScreen(),
    const MessagesScreen(),
    IncomingCallView(
        name: 'Venkatalakshmi Ramasubramanian',
        video: false,
        onAccept: () {},
        onDecline: () {}),
  ]) {
    testWidgets('${s.runtimeType} fits a small phone with large text',
        (t) async {
      await _render(t, s, size: const Size(320, 640), text: 1.6);
      expect(t.takeException(), isNull);
    });
  }
}
