import 'package:fling/models/room_models.dart';
import 'package:fling/screens/live/live_rankings_screen.dart';
import 'package:fling/screens/party/live_broadcast_controller.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:fling/widgets/live_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live extras at a normal phone and a small phone with large text.
Future<void> _render(
    WidgetTester t, Widget child, Size size, double textScale) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.darkWithoutWebFonts(),
    builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: w!),
    home: child,
  ));
  await t.pump();
}

Map<String, dynamic> _battle(String status, {String? winner}) => {
      'id': 'b1',
      'status': status,
      'roomA': 'r1',
      'roomB': 'r2',
      'hostA': {'id': 'h1', 'name': 'Asha Raman with a long name'},
      'hostB': {'id': 'h2', 'name': 'Vikram'},
      'scoreA': 1200,
      'scoreB': 450,
      'endsAt':
          DateTime.now().add(const Duration(minutes: 3)).toIso8601String(),
      'winnerRoomId': winner,
    };

void main() {
  test('live uids are stable and positive', () {
    expect(liveUidFor('user-1'), liveUidFor('user-1'));
    expect(liveUidFor('user-1') == liveUidFor('user-2'), isFalse);
    expect(liveUidFor('x') > 0, isTrue);
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.6),
  ]) {
    final tag = '${size.width.toInt()}@$scale';

    testWidgets('PK view, bar, guests and pill $tag', (t) async {
      final live = LiveBroadcastController(roomId: 'r1', isHost: false);
      addTearDown(live.dispose);
      await _render(
        t,
        Scaffold(
          backgroundColor: Colors.black,
          body: Column(children: [
            SizedBox(
                height: 230,
                child: PkSplitView(
                    live: live,
                    pk: _battle('active'),
                    roomId: 'r1',
                    isHost: false)),
            PkBattleBar(pk: _battle('active'), roomId: 'r1'),
            PkBattleBar(pk: _battle('ended', winner: 'r1'), roomId: 'r1'),
            Row(children: [
              LiveDiamondsPill(diamonds: 12000, onTap: () {}),
              const Spacer(),
              LiveGuestTiles(
                live: live,
                guests: [
                  RosterEntry(
                      userId: 'g1',
                      name: 'Guest One',
                      isHost: false,
                      micOn: true),
                ],
                myUserId: 'me',
                isHost: true,
                onRemove: (_) {},
              ),
            ]),
          ]),
        ),
        size,
        scale,
      );
      expect(t.takeException(), isNull);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('We won!'), findsOneWidget);
      expect(find.text('12K'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove Guest One from the stage'),
          findsOneWidget);
    });

    testWidgets('fans sheet and PK invite sheet $tag', (t) async {
      final extras = LiveExtrasController(roomId: 'r1', socket: null);
      addTearDown(extras.dispose);
      extras.diamonds = 340;
      extras.fanClub = {
        'cost': 50,
        'days': 30,
        'memberCount': 3,
        'memberIds': ['f1'],
        'joined': false,
      };
      extras.topFans = [
        {'id': 'f1', 'name': 'Top Fan With A Very Long Name', 'coins': 300},
        {'id': 'f2', 'name': 'Second', 'coins': 40},
      ];
      await _render(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: () => showLiveFansSheet(context,
                        extras: extras,
                        hostId: 'h1',
                        hostName: 'Asha',
                        isHost: false),
                    child: const Text('fans')),
                TextButton(
                    onPressed: () => showPkInviteSheet(context, extras: extras),
                    child: const Text('pk')),
              ]),
            ),
          ),
        ),
        size,
        scale,
      );
      await t.tap(find.text('fans'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Asha’s fan club'), findsOneWidget);
      expect(find.text('Join · 50 coins'), findsOneWidget);
      expect(find.text('Top Fan With A Very Long Name'), findsOneWidget);
      Navigator.of(t.element(find.text('Asha’s fan club'))).pop();
      await t.pumpAndSettle();

      await t.tap(find.text('pk'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      expect(find.text('Start a PK battle'), findsOneWidget);
    });

    testWidgets('rankings screen without a server $tag', (t) async {
      await _render(t, const LiveRankingsScreen(), size, scale);
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.text('Live rankings'), findsOneWidget);
    });
  }
}
