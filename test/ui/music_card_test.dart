import 'package:fling/models/room_models.dart';
import 'package:fling/widgets/static_bloom_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card(
        {double keyboard = 0,
        Size size = const Size(390, 844),
        double scale = 1,
        bool host = true,
        bool compact = false}) =>
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
              compact: compact,
              isHost: host,
              playing: true,
              title: 'Kannaana Kanney with a rather long song name',
              subtitle: 'Added by Divya',
              nextTitle: 'Hukum',
              volume: 80,
              onVolumeChange: (_) {},
              onTogglePlay: () {},
              onSkip: () {},
              onVoteSkip: () {},
              onToggleLike: () {},
              currentTime: 112,
              duration: 268,
              listeners: [
                for (final n in ['Anu', 'Bala', 'Chitra', 'Divya', 'Ravi'])
                  RosterEntry(userId: n, name: n),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Fixed CD card with an equalizer, slim while typing', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_card());
    expect(find.bySemanticsLabel('Now playing'), findsOneWidget);
    expect(find.text('Added by Divya'), findsOneWidget);
    expect(find.text('Next: Hukum'), findsOneWidget);
    expect(find.text('1:52'), findsOneWidget);
    expect(find.text(' +2'), findsOneWidget);
    // The CD doesn't open anything.
    expect(find.bySemanticsLabel('Open full player'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(_card(keyboard: 300));
    expect(find.bySemanticsLabel('Now playing'), findsNothing);
    expect(find.text('1:52/4:28'), findsOneWidget);
  });

  testWidgets('A listener votes to skip', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_card(host: false));
    expect(find.byTooltip('Vote to skip'), findsOneWidget);
  });

  testWidgets('Voice rooms keep the slim bar', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_card(compact: true));
    expect(find.bySemanticsLabel('Now playing'), findsNothing);
  });

  testWidgets('Fits a small phone with big text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_card(size: const Size(320, 640), scale: 1.6));
    expect(t.takeException(), isNull);
  });
}
