import 'dart:io';
import 'dart:ui' as ui;

import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/user.dart';
import 'package:fling/screens/discover/discover_screen.dart';
import 'package:fling/screens/feed/feed_screen.dart';
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

  for (final s in [const FeedScreen(), const DiscoverScreen()]) {
    testWidgets('${s.runtimeType} fits a small phone with large text',
        (t) async {
      await _render(t, s, size: const Size(320, 640), text: 1.6);
      expect(t.takeException(), isNull);
    });
  }
}
