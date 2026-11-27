import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/home/popcorn_cards.dart';
import 'package:insync/widgets/animated_emoji.dart';
import 'package:insync/widgets/emoji_panel.dart';

Map<String, dynamic> _m(String id, String name,
        {bool stage = false, bool friend = false}) =>
    {'userId': id, 'name': name, 'onStage': stage, 'isFriend': friend};

// Renders the four post-style room cards and the emoji panel, and saves a
// picture to build/design-preview/popcorn_cards.png.
void main() {
  testWidgets('Popcorn post cards and the emoji panel render', (t) async {
    t.view.physicalSize = const Size(400, 2300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    AnimatedEmojiRegistry.entries = [
      for (final e in ['😀', '😂', '😍', '🔥', '❤️', '👏', '😮', '😢', '🐶', '🍕'])
        (emoji: e, name: 'x', category: e == '🐶' ? 'Animals and nature' : 'Smileys and emotions'),
    ];
    final rooms = [
      {
        'id': 'w',
        'roomType': 'watch',
        'title': 'Kesariya and chill',
        'nowPlayingTitle': 'Kesariya – Brahmastra',
        'memberCount': 14,
        'hostId': 'h',
        'duration': 200,
        'playbackPosition': 80,
        'members': [_m('a', 'Divya', friend: true), _m('b', 'Arun'), _m('h', 'Host')],
      },
      {
        'id': 't',
        'roomType': 'voice',
        'title': 'Which 2026 song will you still play next year?',
        'topic': 'Movies and music',
        'speakingName': 'Meena',
        'memberCount': 27,
        'hostId': 'm',
        'members': [
          _m('m', 'Meena', stage: true),
          _m('r', 'Ravi', stage: true),
          _m('p', 'Priya', stage: true),
          _m('l1', 'Lis One'),
          _m('l2', 'Lis Two'),
        ],
      },
      {
        'id': 'g',
        'roomType': 'game',
        'gameType': 'ludo',
        'title': 'Ludo with us',
        'memberCount': 9,
        'hostId': 'a',
        'game': {'playerIds': ['a', 'p', 'd'], 'seats': 4, 'status': 'waiting'},
        'members': [_m('a', 'Arun'), _m('p', 'Priya'), _m('d', 'Divya'), _m('w1', 'Watcher')],
      },
      {
        'id': 'l',
        'roomType': 'live',
        'title': 'Cooking biryani live',
        'memberCount': 1200,
        'hostId': 'k',
        'createdAt': DateTime.now()
            .subtract(const Duration(minutes: 20))
            .toIso8601String(),
        'members': [_m('v1', 'Viewer')],
      },
    ];
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.black,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                for (final r in rooms) ...[
                  PopcornPostCard(room: r, onTap: () {}),
                  const SizedBox(height: 14),
                ],
                Container(
                  color: Colors.black,
                  child: EmojiPanel(onPick: (_) {}),
                ),
              ]),
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Join'), findsNWidgets(2));
    expect(find.text('Watch'), findsOneWidget);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-preview/popcorn_cards.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
