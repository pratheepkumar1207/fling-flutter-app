import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/tournaments/tournament_cards.dart';
import 'package:insync/screens/tournaments/tournament_live.dart';
import 'package:insync/screens/tournaments/tournament_watch.dart';

Map<String, dynamic> _tour(String status) => {
      'id': 't1',
      'hostId': 'u0',
      'title': 'Divya’s UNO Cup',
      'gameType': 'uno',
      'format': 'tables',
      'size': 16,
      'status': status,
      'startsAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'players': [
        for (var i = 0; i < 11; i++) {'id': 'u$i', 'name': 'Player $i', 'avatarUrl': null}
      ],
      'prizes': [300, 150, 50, 50],
      'rounds': status == 'running'
          ? [
              {
                'n': 1,
                'kind': 'tables',
                'advance': 1,
                'status': 'playing',
                'final': false,
                'matches': [
                  for (var t = 0; t < 3; t++)
                    {
                      'id': 'r1m${t + 1}',
                      'label': 'Table ${t + 1}',
                      'roomId': 'room$t',
                      'players': ['u${t * 3}', 'u${t * 3 + 1}', 'u${t * 3 + 2}'],
                      'dropped': <String>[],
                      'ranking': t == 2 ? ['u6', 'u7', 'u8'] : <String>[],
                      'status': t == 2 ? 'done' : 'playing',
                      'score': <String, int>{},
                    }
                ],
              }
            ]
          : [],
    };

void main() {
  testWidgets('Popcorn card: open tournament shows free join and prizes', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 280, child: TournamentCard(t: _tour('open'))))));
    expect(find.text('🏆 Free entry'), findsOneWidget);
    expect(find.text('Join · free'), findsOneWidget);
    expect(find.textContaining('11 of 16 joined'), findsOneWidget);
    expect(find.textContaining('🥇 300'), findsOneWidget);
  });

  testWidgets('Popcorn card: running tournament offers Watch', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 280, child: TournamentCard(t: _tour('running'))))));
    expect(find.text('Watch'), findsOneWidget);
    expect(find.textContaining('Live · Round 1'), findsOneWidget);
  });

  testWidgets('Watch: one big table, the others small, tap to swap', (tester) async {
    final live = TournamentLive('t1', null)..data = _tour('running');
    live.games['r1m1'] = {
      'gameType': 'uno',
      'status': 'playing',
      'players': [
        {'userId': 'u0', 'name': 'Player 0', 'handCount': 3},
        {'userId': 'u1', 'name': 'Player 1', 'handCount': 5},
        {'userId': 'u2', 'name': 'Player 2', 'handCount': 4},
      ],
      'hand': <dynamic>[],
      'currentPlayerIndex': 0,
      'direction': 1,
      'discardTop': {'id': 'c1', 'color': 'red', 'type': 'number', 'value': 7},
      'currentColor': 'red',
      'drawPileCount': 80,
      'pendingDraw': 0,
      'unoFlags': <String, dynamic>{},
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TournamentWatchView(live: live))));
    await tester.pump();
    // Table 1 big (first playing), tables 2 and 3 small.
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('T2 ●'), findsOneWidget);
    expect(find.text('T3 ✓'), findsOneWidget);
    await tester.tap(find.text('T3 ✓'));
    await tester.pump();
    expect(find.text('Table 3'), findsOneWidget);
    expect(find.text('Player 6 won'), findsOneWidget);
  });

  testWidgets('Watch fits a phone in portrait', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final live = TournamentLive('t1', null)..data = _tour('running');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TournamentWatchView(live: live))));
    await tester.pump();
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Other tables · tap to make big, hold for more'), findsOneWidget);
  });

  test('excitement lines', () {
    String name(String? id) => id == 'a' ? 'Sara' : 'X';
    expect(
        tourExcitement('uno', {
          'status': 'playing',
          'players': [
            {'userId': 'a', 'handCount': 1}
          ]
        }, null, name),
        'Sara has 1 card');
    expect(tourExcitement('chess', {'status': 'playing', 'check': true, 'players': []}, null, name), 'Check!');
    expect(tourExcitement('uno', {'status': 'won', 'players': []}, null, name), isNull);
  });
}
