import 'dart:io';
import 'dart:ui' as ui;

import 'package:fling/screens/home/home_room_cards.dart';
import 'package:fling/screens/shell/liquid_glass_bottom_nav.dart';
import 'package:fling/theme/app_colors.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:fling/theme/insync_icons.dart';
import 'package:fling/widgets/animated_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _members = [
  {'name': 'Bala'},
  {'name': 'Chitra'},
  {'name': 'Ravi'},
  {'name': 'Anu'},
];

Map<String, dynamic> _room(String type, {String theme = 'midnight'}) => {
      'id': type,
      'roomType': type,
      'theme': theme,
      'title': switch (type) {
        'voice' => 'Late night songs',
        'game' => 'Ludo with Anu',
        'live' => 'Singing your requests',
        _ => 'Movie night',
      },
      'nowPlayingTitle': 'Moththa Raathiri',
      'hostName': 'Divya',
      'sourceType': 'netflix',
      'gameType': type == 'game' ? 'ludo' : null,
      'memberCount': type == 'game' ? 2 : 6,
      'members': _members,
      'playbackPosition': 2892,
      'isPlaying': true,
    };

ThemeData _theme() => AppTheme.darkWithoutWebFonts();

Future<void> _snap(WidgetTester tester, GlobalKey key, String name) async {
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

  testWidgets('Home room cards render every room type without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    var taps = 0;
    var navTaps = <int>[];
    await tester.pumpWidget(MaterialApp(
      theme: _theme(),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          bottomNavigationBar: LiquidGlassBottomNav(
            currentIndex: 0,
            onTap: navTaps.add,
            onCreateTap: () => taps++,
            items: const [
              NavItemData(InIcons.home, 'Home'),
              NavItemData(InIcons.feed, 'Feed'),
              NavItemData(InIcons.live, 'Live', tag: 'LIVE'),
              NavItemData(InIcons.flame, 'Discover'),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            for (final r in [
              _room('watch', theme: 'cinema'),
              _room('voice'),
              _room('game', theme: 'neon'),
              _room('live', theme: 'dark'),
            ]) ...[
              HomeRoomCard(room: r, onTap: () => taps++),
              const SizedBox(height: 12),
            ],
            HomeInviteCard(
                title: 'Bala invited you to Movie night',
                subtitle: 'Tap to join the room',
                onTap: () => taps++),
          ]),
        ),
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Take seat'));
    await tester.tap(find.bySemanticsLabel('Create'));
    await tester.tap(find.text('Live'));
    expect(taps, 2);
    expect(navTaps, [2]);
    await tester.pumpAndSettle();
    await _snap(tester, key, 'home-cards');
  });

  testWidgets('Room cards cope with large text on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: _theme(),
      home: MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 1600), textScaler: TextScaler.linear(1.4)),
        child: Scaffold(
          body: ListView(padding: const EdgeInsets.all(12), children: [
            for (final t in ['watch', 'voice', 'game', 'live'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HomeRoomCard(room: _room(t), onTap: () {}),
              ),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Splash logo finishes and reports done', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: AnimatedLogo(onDone: () => done = true)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(done, isFalse);
    await tester.pump(AnimatedLogo.total);
    expect(done, isTrue);
    await tester.runAsync(() async {
      for (final n in [
        'loop',
        'head_left',
        'head_right',
        'bubble',
        'pad',
        'play',
        'word',
        'tag'
      ]) {
        await precacheImage(
            AssetImage('assets/logo/$n.png'), key.currentContext!);
      }
    });
    await tester.pump();
    await _snap(tester, key, 'splash-final');
  });
}
