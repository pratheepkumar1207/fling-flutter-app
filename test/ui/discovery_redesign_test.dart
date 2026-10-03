import 'dart:io';
import 'package:fling/screens/auth/onboarding_screen.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fling/screens/home/room_discovery_header.dart';
import 'package:fling/theme/app_colors.dart';
import 'package:fling/theme/clay_colors.dart';
import 'package:fling/screens/shell/liquid_glass_bottom_nav.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(File('test/fixtures/materialicons-regular.otf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await icons.load();
  });
  testWidgets(
      'Discovery actions stay usable on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var creates = 0;
    var joins = 0;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 1400), textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
              padding: const EdgeInsets.all(20),
              child: RoomDiscoveryHeader(
                  firstName: 'Pratheep',
                  onCreate: () => creates++,
                  onJoin: () => joins++,
                  onSearch: () {}),
            ))))));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Start a room'));
    await tester.tap(find.text('Start a room'));
    await tester.ensureVisible(find.text('Join with code'));
    await tester.tap(find.text('Join with code'));
    expect(creates, 1);
    expect(joins, 1);
  });

  testWidgets('Room card handles long content and opens the selected room',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DiscoveryRoomCard(
                title:
                    'A very long watch party title that should wrap without overflowing',
                subtitle: 'Hosted by a person with a long display name',
                kind: 'watch',
                count: 12,
                onTap: () => opens++))));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('12 people in the room'));
    expect(opens, 1);
  });

  testWidgets('Render the new visual direction', (tester) async {
    tester.view.physicalSize = const Size(390, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: AppColors.bg,
            extensions: [ClayColors.dark]),
        home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
                bottomNavigationBar: LiquidGlassBottomNav(
                    currentIndex: 0,
                    onTap: (_) {},
                    onCreateTap: () {},
                    items: const [
                      NavItemData(Icons.home_rounded, 'Home'),
                      NavItemData(Icons.explore_outlined, 'Discover'),
                      NavItemData(Icons.chat_bubble_outline_rounded, 'Chat'),
                      NavItemData(Icons.person_outline_rounded, 'Profile')
                    ]),
                body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView(children: [
                      const SizedBox(height: 12),
                      const Text('insync',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      RoomDiscoveryHeader(
                          firstName: 'Pratheep',
                          onCreate: () {},
                          onJoin: () {},
                          onSearch: () {}),
                      const SizedBox(height: 24),
                      const Text('Find your room',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      const Text('FOR YOU      WATCH      TALK      PLAY',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                      const SizedBox(height: 18),
                      DiscoveryRoomCard(
                          title: 'Friday night, together',
                          subtitle: 'Example room · Design preview',
                          kind: 'watch',
                          count: 8,
                          positionSeconds: 143,
                          isPlaying: true,
                          participants: const [
                            {'name': 'Priya'},
                            {'name': 'Alex'},
                            {'name': 'Sam'}
                          ],
                          onTap: () {}),
                    ]))))));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/icons/app/watch_clay.png'),
        boundaryKey.currentContext!));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-preview/discovery.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
  testWidgets(
      'Onboarding scrolls on a small screen with large text and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 250)),
            child: const OnboardingScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Continue'), 150, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}

