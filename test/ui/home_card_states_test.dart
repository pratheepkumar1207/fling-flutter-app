import 'package:fling/screens/home/home_room_cards.dart';
import 'package:fling/screens/home/home_lobby_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _members = [
  {'name': 'Bala'},
  {'name': 'Chitra'},
];

Map<String, dynamic> _room(String type, Map<String, dynamic> extra) => {
      'id': type,
      'roomType': type,
      'title': 'Room $type',
      'hostName': 'Bala Kumar',
      'memberCount': 12,
      'members': _members,
      ...extra,
    };

Future<void> _pump(WidgetTester tester, List<Widget> children,
    {Size size = const Size(390, 1600), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: ListView(padding: const EdgeInsets.all(12), children: [
          for (final c in children)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
        ]),
      ),
    ),
  ));
  await tester.pump();
}

List<Widget> _cards({VoidCallback? onTap, Future<bool?> Function()? remind}) =>
    [
      HomeLobbyCard(
          room: _room('voice', {
            'onMicCount': 3,
            'speakingName': 'Bala Kumar',
            'communityName': 'Chennai Movie Club',
          }),
          onTap: onTap ?? () {}),
      HomeLobbyCard(
          room: _room('watch', {'visibility': 'friends'}), onTap: () {}),
      HomeLobbyCard(
          room: _room(
              'live', {'giftsToday': 12800, 'dailyRank': 12, 'inPk': false}),
          onTap: () {}),
      HomeLobbyCard(
          room: _room('live', {'inPk': true, 'pkOpponentHost': 'Ravi'}),
          onTap: () {}),
      HomeEventCard(event: {
        'id': 'e1',
        'title': 'Movie night',
        'roomType': 'watch',
        'hostName': 'Bala',
        'goingCount': 48,
        'remindMe': false,
        'scheduledAt': DateTime.now()
            .add(const Duration(days: 2, hours: 4, minutes: 5))
            .toUtc()
            .toIso8601String(),
      }, onRemind: remind, onTap: () {}),
      HomeInRoomBanner(
          title: 'Movie night', speakingName: 'Bala Kumar', onOpen: () {}),
      HomeBlendCard(
          title: 'You + Chitra', members: _members, watching: 2, onTap: () {}),
    ];

void main() {
  testWidgets('Home card states show live room details', (tester) async {
    var reminded = false;
    await _pump(tester, _cards(remind: () async => reminded = !reminded));
    expect(find.text('Bala is talking'), findsOneWidget);
    expect(find.text('Chennai Movie Club'), findsOneWidget);
    expect(find.text('PK battle · vs Ravi'), findsOneWidget);
    expect(find.text('Join'), findsNothing);
    expect(find.text('STARTS IN 2D 4H'), findsOneWidget);
    expect(find.text('Watch party · 48 going · by Bala'), findsOneWidget);
    expect(find.text("YOU'RE IN"), findsOneWidget);
    expect(find.text('Rejoin'), findsOneWidget);

    await tester.tap(find.text('Remind'));
    await tester.pump();
    expect(find.text('Reminded'), findsOneWidget);
    expect(find.text('Watch party · 49 going · by Bala'), findsOneWidget);
  });

  testWidgets('Home card states fit a small phone with big text',
      (tester) async {
    final cards = _cards();
    for (var i = 0; i < cards.length; i++) {
      await _pump(tester, [cards[i]], size: const Size(320, 900), scale: 1.6);
      expect(tester.takeException(), isNull, reason: 'card $i');
    }
  });

  test('event countdown', () {
    final now = DateTime(2026, 10, 28, 10);
    expect(eventCountdown(now.add(const Duration(minutes: 30)), now),
        'STARTS IN 30M');
  });
}
