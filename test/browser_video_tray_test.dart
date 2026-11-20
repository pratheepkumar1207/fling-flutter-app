import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/lobby/browser_video_tray.dart';

FoundVideo v(int i, {bool locked = false}) => FoundVideo(
    key: 'k$i',
    title: 'Video $i with a fairly long title to test wrapping',
    videoUrl: 'https://example.com/$i.mp4',
    sourceType: 'web',
    site: 'example.com',
    durationSec: 125 + i,
    locked: locked);

Widget host(Widget child) => MaterialApp(
    home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child))));

void main() {
  testWidgets('tray: select two and add', (t) async {
    List<FoundVideo>? picked;
    await t.pumpWidget(host(BrowserVideoTray(
        videos: [v(1), v(2), v(3, locked: true), v(4)],
        inRoom: true,
        onPick: (p) => picked = p)));
    expect(find.text('4 videos on this page'), findsOneWidget);
    await t.tap(find.text('Select'));
    await t.pump();
    await t.tap(find.bySemanticsLabel(RegExp(r'^Video 1 ')));
    await t.tap(find.bySemanticsLabel(RegExp(r'^Video 2 ')));
    await t.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await t.tap(find.text('Add 2 to queue'));
    expect(picked!.map((x) => x.key), ['k1', 'k2']);
  });

  testWidgets('tray: select all skips locked', (t) async {
    List<FoundVideo>? picked;
    await t.pumpWidget(host(BrowserVideoTray(
        videos: [v(1), v(2), v(3, locked: true)],
        inRoom: false,
        onPick: (p) => picked = p)));
    await t.tap(find.text('Select'));
    await t.pump();
    await t.tap(find.text('Select all'));
    await t.pump();
    await t.tap(find.text('Start watch party with 2'));
    expect(picked!.length, 2);
  });

  testWidgets('single card and pill fit a small phone', (t) async {
    var watched = false;
    await t.pumpWidget(host(BrowserVideoCard(
        video: v(1),
        collapsed: false,
        onWatch: () => watched = true,
        onClose: () {},
        onExpand: () {})));
    await t.tap(find.text('Watch together'));
    expect(watched, isTrue);
    await t.pumpWidget(host(BrowserVideoCard(
        video: v(1), collapsed: true, onWatch: () {}, onClose: () {}, onExpand: () {})));
    await t.pumpAndSettle();
    expect(find.text('Watch together'), findsOneWidget);
  });
}
