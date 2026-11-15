import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/shell/liquid_glass_bottom_nav.dart';
import 'package:insync/theme/insync_icons.dart';

// The bottom bar with Popcorn open and with Home open, saved to
// build/design-preview/popcorn_tab.png.
void main() {
  testWidgets('Popcorn tab icon rises above the bar', (t) async {
    t.view.physicalSize = const Size(400, 260);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const items = [
      NavItemData(InIcons.home, 'Home'),
      NavItemData(InIcons.reels, 'Reels'),
      NavItemData(InIcons.popcorn, 'Popcorn',
          image: 'assets/icon/popcorn-tab.png'),
      NavItemData(InIcons.flame, 'Discover'),
      NavItemData(InIcons.chat, 'Chat'),
    ];
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.black,
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final i in [2, 0])
                LiquidGlassBottomNav(
                    currentIndex: i, onTap: (_) {}, items: items),
            ]),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pump();
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-preview/popcorn_tab.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
