import 'package:fling/screens/party/chat_overlay.dart';
import 'package:fling/widgets/static_bloom_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {double width = 390}) async {
  t.view.physicalSize = Size(width, 700);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await t.pump();
}

void main() {
  testWidgets('Slim room music bar: like, play and skip on one line',
      (t) async {
    var played = 0, skipped = 0, liked = 0;
    await _pump(
        t,
        StaticBloomPlayer(
          compact: true,
          playing: true,
          isHost: true,
          title: 'Kannaana Kanney',
          volume: 80,
          onVolumeChange: (_) {},
          onTogglePlay: () => played++,
          onSkip: () => skipped++,
          onToggleLike: () => liked++,
          currentTime: 112,
          duration: 268,
        ));
    expect(find.text('Kannaana Kanney'), findsOneWidget);
    expect(find.text('1:52/4:28'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Like'));
    await t.tap(find.bySemanticsLabel('Pause'));
    await t.tap(find.bySemanticsLabel('Skip'));
    expect([liked, played, skipped], [1, 1, 1]);
  });

  testWidgets('Listener play only mutes their own phone', (t) async {
    var volume = 70;
    var votes = 0;
    await _pump(
        t,
        StatefulBuilder(
          builder: (context, set) => StaticBloomPlayer(
            compact: true,
            playing: true,
            title: 'Hukum',
            volume: volume,
            onVolumeChange: (v) => set(() => volume = v),
            onVoteSkip: () => votes++,
            currentTime: 10,
            duration: 200,
          ),
        ));
    await t.tap(find.bySemanticsLabel('Pause'));
    await t.pump();
    expect(volume, 0);
    await t.tap(find.bySemanticsLabel('Play'));
    await t.pump();
    expect(volume, 70);
    await t.tap(find.bySemanticsLabel('Vote to skip'));
    expect(votes, 1);
  });

  testWidgets('Slim bar fits a small phone with big text', (t) async {
    t.view.physicalSize = const Size(320, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 400), textScaler: TextScaler.linear(1.6)),
        child: Scaffold(
          body: StaticBloomPlayer(
            compact: true,
            playing: true,
            isHost: true,
            title: 'A very long Tamil song name that keeps going',
            volume: 80,
            onVolumeChange: (_) {},
            onTogglePlay: () {},
            onSkip: () {},
            onToggleLike: () {},
            currentTime: 3600,
            duration: 5400,
          ),
        ),
      ),
    ));
    expect(t.takeException(), isNull);
  });

  testWidgets('Room view-once photo lines', (t) async {
    final opened = <String>[];
    final seenTaps = <String>[];
    await _pump(
        t,
        SizedBox(
          height: 600,
          child: ChatOverlay(
            messages: const [
              {
                'senderId': 'k',
                'name': 'Kavya',
                'viewOnceId': 'p1',
                'ts': 1,
              },
              {
                'senderId': 'me',
                'name': 'Me',
                'viewOnceId': 'p2',
                'seenCount': 12,
                'ts': 2,
              },
            ],
            onSend: (_, __, {replyTo}) {},
            myUserId: 'me',
            primaryColor: Colors.purple,
            textColor: Colors.white,
            roster: const [],
            myMicOn: false,
            myMicRequested: false,
            onMicTap: () {},
            onPoll: () {},
            onGift: () {},
            onShare: () {},
            onInvite: () {},
            onViewOncePhoto: ({required bool camera}) {},
            onOpenViewOnce: (id, name) async => opened.add(id),
            onViewOnceSeen: seenTaps.add,
          ),
        ));
    expect(find.text('Tap to open · 10 sec'), findsOneWidget);
    expect(find.text('Seen by 12'), findsOneWidget);
    await t.tap(find.text('Seen by 12'));
    expect(seenTaps, ['p2']);
    await t.tap(find.text('Tap to open · 10 sec'));
    await t.pumpAndSettle();
    expect(opened, ['p1']);
    expect(find.text('Kavya’s photo · viewed'), findsOneWidget);
  });
}
