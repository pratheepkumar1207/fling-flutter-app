import 'package:fling/screens/home/home_lobby_card.dart';
import 'package:fling/theme/room_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _p(String id, String name,
        {bool stage = false, String? role}) =>
    {'userId': id, 'name': name, 'onStage': stage, 'role': role};

Widget _card(Map<String, dynamic> room,
        {Size size = const Size(390, 844), double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
              child: HomeLobbyCard(room: room, onTap: () {})),
        ),
      ),
    );

final _watch = <String, dynamic>{
  'id': 'r',
  'roomType': 'watch',
  'title': 'Friday movie night',
  'nowPlayingTitle': 'Leo',
  'isPlaying': false,
  'playbackPosition': 2530,
  'duration': 8880,
  'memberCount': 3,
  'hostDistanceKm': 2,
  'members': [
    _p('b', 'Bala Kumar', stage: true, role: 'host'),
    _p('d', 'Divya'),
    _p('a', 'Anu'),
  ],
};

final _chess = <String, dynamic>{
  'id': 'g',
  'roomType': 'game',
  'gameType': 'chess',
  'title': 'Chess room',
  'memberCount': 3,
  'game': {
    'status': 'playing',
    'turn': 'b',
    'playerIds': ['b', 'a'],
    'seats': 2,
  },
  'members': [
    _p('b', 'Bala', stage: true, role: 'host'),
    _p('a', 'Anu', stage: true),
    _p('d', 'Divya'),
  ],
};

void main() {
  void phone(WidgetTester t, [Size size = const Size(390, 844)]) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('Video card: its name first, time, people, no km or Join',
      (t) async {
    phone(t);
    await t.pumpWidget(_card(_watch));
    expect(find.text('Leo'), findsOneWidget);
    expect(find.text('Friday movie night'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('42:10 / 2:28:00'), findsOneWidget);
    expect(find.text('3 watching'), findsOneWidget);
    expect(find.text('Bala'), findsOneWidget);
    expect(find.text('Watching'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
    expect(find.text('Join'), findsNothing);
  });

  testWidgets('Boosted is only a tag', (t) async {
    phone(t);
    await t.pumpWidget(_card({..._watch, 'isBoosted': true}));
    expect(find.text('Boosted'), findsOneWidget);
    await t.pumpWidget(_card(_chess));
    expect(find.text('Boosted'), findsNothing);
  });

  testWidgets('Game card: whose turn, VS, then watchers', (t) async {
    phone(t);
    await t.pumpWidget(_card(_chess));
    expect(find.text('Chess'), findsOneWidget);
    expect(find.text("Bala's turn"), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('2 playing · 1 watching'), findsOneWidget);
    expect(find.text('Watching'), findsOneWidget);
  });

  testWidgets('Voice card: room name, no thumbnail', (t) async {
    phone(t);
    await t.pumpWidget(_card({
      'id': 'v',
      'roomType': 'voice',
      'title': 'Tamil talk',
      'memberCount': 3,
      'speakingName': 'Bala',
      'members': [
        _p('b', 'Bala', stage: true, role: 'host'),
        _p('r', 'Ravi'),
        _p('s', 'Sara'),
      ],
    }));
    expect(find.text('Tamil talk'), findsOneWidget);
    expect(find.text('Bala is talking'), findsOneWidget);
    expect(find.text('1 on mic · 2 listening'), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);
  });

  test('VS sits where each game wants it', () {
    expect(gameVersusSplit('chess', 2), 1);
    expect(gameVersusSplit('ludo', 3), 2);
    expect(gameVersusSplit('truth_or_dare', 6), 1);
    expect(gameVersusSplit('would_you_rather', 8), isNull);
    expect(gameVersusSplit('chess', 1), isNull);
  });

  test('Each game has its own room theme', () {
    expect(RoomTheme.forGame('chess').id, 'chess');
    expect(RoomTheme.forGame('uno').id, 'uno');
    expect(RoomTheme.forGame(null).id, 'midnight');
  });

  testWidgets('Fits a small phone with big text', (t) async {
    phone(t, const Size(320, 640));
    for (final room in [_watch, _chess]) {
      await t.pumpWidget(_card(room, size: const Size(320, 640), scale: 1.6));
      expect(t.takeException(), isNull);
    }
  });
}
