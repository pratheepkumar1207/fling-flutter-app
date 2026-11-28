import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/models/room_models.dart';
import 'package:insync/screens/party/chat_overlay.dart';

// Now Playing and join notes work like messages: long-press opens the
// sheet (actions, search, emoji), a reaction shows under them, and Reply
// quotes them. Saves the sheet to build/design-preview/chat_sheet.png.
void main() {
  testWidgets('Now Playing and joins: sheet, reactions, reply', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final reacted = <List<String>>[];
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox(
            height: 800,
            child: ChatOverlay(
              messages: const [
                {
                  'id': 'sys-1-nowPlaying-x',
                  'system': true,
                  'type': 'nowPlaying',
                  'title': 'Ithanundu Muthathile',
                  'videoUrl': 'https://youtu.be/x',
                  'pinnedBy': 'b',
                  'pinnedByName': 'Bala Kumar',
                  'ts': 1,
                  'reactions': {
                    '🔥': ['b']
                  },
                },
                {
                  'id': 'sys-2-joined-y',
                  'system': true,
                  'event': 'joined',
                  'userId': 'c',
                  'text': 'Chitra joined',
                  'ts': 2,
                },
              ],
              onSend: (_, __, {replyTo}) {},
              onReact: (id, e) => reacted.add([id, e]),
              myUserId: 'me',
              primaryColor: Colors.purple,
              textColor: Colors.white,
              roster: [
                RosterEntry(userId: 'b', name: 'Bala Kumar', username: 'bala'),
              ],
              myMicOn: false,
              myMicRequested: false,
              onMicTap: () {},
              onPoll: () {},
              onGift: () {},
              onShare: () {},
              onInvite: () {},
            ),
          ),
        ),
      ),
    ));
    await t.pump();
    // Long-press Now Playing: Share, Copy, Reply, Report and search.
    await t
        .longPress(find.textContaining('Ithanundu', findRichText: true).first);
    await t.pumpAndSettle();
    for (final a in ['Share', 'Copy', 'Reply', 'Report', 'Search']) {
      expect(find.text(a), findsWidgets, reason: a);
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-preview/chat_sheet.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await t.tap(find.text('Reply'));
    await t.pumpAndSettle();
    expect(find.text('Replying to Now Playing'), findsOneWidget);

    // Long-press the join note: Copy and Reply, no Share or Report.
    await t.longPress(
        find.textContaining('Chitra joined the lobby', findRichText: true));
    await t.pumpAndSettle();
    expect(find.text('Share'), findsNothing);
    expect(find.text('Reply'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
