import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/widgets/ludo_board.dart';

// Renders the Ludo board mid-game (tokens out, one movable) and saves a
// picture to build/design-preview/ludo.png.
void main() {
  testWidgets('Ludo board renders a game in progress', (t) async {
    t.view.physicalSize = const Size(400, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: RepaintBoundary(
          key: key,
          child: SingleChildScrollView(
            child: LudoBoard(
              game: const {
                'status': 'playing',
                'turn': 'a',
                'diceValue': 6,
                'movableTokenIndices': [0, 1],
                'players': [
                  {'userId': 'a', 'name': 'Ravi', 'color': 'red'},
                  {'userId': 'b', 'name': 'Priya', 'color': 'green'},
                  {'userId': 'c', 'name': 'Divya', 'color': 'yellow'},
                  {'userId': 'd', 'name': 'Arun', 'color': 'blue'},
                ],
                'tokens': {
                  'red': [0, 5, 20, 0],
                  'green': [3, 0, 0, 58],
                  'yellow': [0, 0, 10, 62],
                  'blue': [0, 30, 0, 0],
                },
              },
              myUserId: 'a',
              isHost: true,
              onJoin: () {},
              onMove: (_) {},
              onReset: () {},
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-preview/ludo.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
