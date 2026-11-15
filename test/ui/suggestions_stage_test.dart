import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/party/video_suggestions_panel.dart';

// Stands in for the live player: counts how many times it was created.
int _created = 0;

class _FakePlayer extends StatefulWidget {
  const _FakePlayer();
  @override
  State<_FakePlayer> createState() => _FakePlayerState();
}

class _FakePlayerState extends State<_FakePlayer> {
  @override
  void initState() {
    super.initState();
    _created++;
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Colors.red, child: SizedBox(height: 225));
}

Widget _panel({required bool open, int rows = 2, VoidCallback? onRestore}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: VideoSuggestionsPanel(
            open: open,
            rows: rows,
            player: const _FakePlayer(),
            sourceType: 'drive',
            videoUrl: 'https://example.com/v.mp4',
            onPin: ({required videoUrl, required title, thumbnail, required sourceType}) {},
            onRestore: onRestore ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('Opening and closing suggestions keeps the same player',
      (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    _created = 0;
    var restored = false;
    await t.pumpWidget(_panel(open: false));
    await t.pump(const Duration(milliseconds: 50));
    expect(t.getSize(find.byType(_FakePlayer)).width, 400);

    await t.pumpWidget(_panel(open: true, onRestore: () => restored = true));
    await t.pump(const Duration(milliseconds: 50));
    // Shrunk into the first tile: half the width, 16:9.
    final tile = t.getSize(find.byType(_FakePlayer));
    expect(tile.width, 200);
    expect(tile.height, closeTo(112.5, 0.01));
    await t.tap(find.byType(_FakePlayer), warnIfMissed: false);
    expect(restored, isTrue);

    await t.pumpWidget(_panel(open: false));
    await t.pump(const Duration(milliseconds: 50));
    expect(_created, 1, reason: 'the player must never be built again');
  });

  testWidgets('Landscape full screen: three rows', (t) async {
    t.view.physicalSize = const Size(800, 360);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_panel(open: true, rows: 3));
    await t.pump(const Duration(milliseconds: 50));
    expect(t.getSize(find.byType(_FakePlayer)).height, closeTo(120, 0.01));
  });
}
