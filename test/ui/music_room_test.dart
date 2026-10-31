import 'package:fling/core/auth_provider.dart';
import 'package:fling/screens/lobby/music_room_create_screen.dart';
import 'package:fling/screens/lobby/source_search_area.dart';
import 'package:fling/widgets/static_bloom_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _card(
        {double keyboard = 0,
        Size size = const Size(390, 844),
        double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
            child: StaticBloomPlayer(
              compact: true,
              musicRoom: true,
              isHost: true,
              playing: true,
              title: 'Kannaana Kanney with a rather long song name',
              subtitle: 'Added by Divya',
              nextTitle: 'Hukum',
              volume: 80,
              onVolumeChange: (_) {},
              onTogglePlay: () {},
              onSkip: () {},
              onToggleLike: () {},
              currentTime: 112,
              duration: 268,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Music card: compact, slim while typing, full on tap', (t) async {
    await t.pumpWidget(_card());
    expect(find.text('Added by Divya'), findsOneWidget);
    expect(find.text('Next: Hukum'), findsOneWidget);
    expect(find.text('1:52'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Open full player'));
    await t.pump();
    expect(find.text('Up next'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(_card(keyboard: 300));
    expect(find.text('1:52/4:28'), findsOneWidget);
  });

  testWidgets('Music card fits a small phone with big text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_card(size: const Size(320, 640), scale: 1.6));
    expect(t.takeException(), isNull);
    await t.tap(find.bySemanticsLabel('Open full player'));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('Create flow: setup then pick a song', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: MusicRoomCreateScreen()),
    ));
    await t.pump();
    expect(find.text('Listen together'), findsOneWidget);
    expect(find.text('WHO ADDS SONGS'), findsOneWidget);
    await t.tap(find.text('Next · pick the first song'));
    await t.pump();
    expect(find.text('Search songs on YouTube Music'), findsOneWidget);
    expect(find.text('Tamil hits'), findsOneWidget);
  });

  testWidgets('Search area: pasted link shows a preview, bad link says so',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SourceSearchArea(
            inRoom: false,
            onPick: (
                {required sourceType,
                required videoUrl,
                required title,
                thumbnail}) {},
            sources: const Text('the sources'),
          ),
        ),
      ),
    ));
    await t.pump();
    expect(find.text('the sources'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'https://example.com/x');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    expect(find.textContaining('can’t play here'), findsOneWidget);
    expect(find.text('the sources'), findsNothing);
    await t.enterText(find.byType(TextField),
        'https://drive.google.com/file/d/abcdefghijkl/view');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    expect(find.text('Start watching'), findsOneWidget);
  });
}
