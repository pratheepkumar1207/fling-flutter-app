import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/widgets/game_computer.dart';
import 'package:insync/widgets/game_seat.dart';

void main() {
  Widget host(Widget child, {VoidCallback? onAdd}) => MaterialApp(
        home: Scaffold(
          body: GameSeatScope(
            isHost: true,
            requested: false,
            invited: false,
            onSit: () {},
            onRequest: () {},
            onCancelRequest: () {},
            onInvite: () {},
            onAddComputer: onAdd,
            avatarFor: (_) => null,
            child: Center(child: child),
          ),
        ),
      );

  testWidgets('a computer seat shows the robot and thinking on its turn',
      (tester) async {
    await tester.pumpWidget(host(const GameSeat(
        userId: 'bot:abc', name: 'Bot Mango', isTurn: true)));
    expect(find.byType(BotAvatar), findsOneWidget);
    expect(find.text('thinking…'), findsOneWidget);
    expect(find.text('Bot Mango'), findsOneWidget);
  });

  testWidgets('host sees Add computer next to Invite', (tester) async {
    var added = 0;
    await tester.pumpWidget(host(const GameJoinButton(seated: true, full: false),
        onAdd: () => added++));
    await tester.tap(find.text('Add computer'));
    expect(added, 1);
  });

  testWidgets('host tapping an empty seat can add a computer', (tester) async {
    var added = 0;
    await tester.pumpWidget(host(const GameOpenSeat(), onAdd: () => added++));
    await tester.tap(find.byType(GameOpenSeat));
    await tester.pumpAndSettle();
    expect(find.text('Invite someone'), findsOneWidget);
    await tester.tap(find.text('Add computer'));
    await tester.pumpAndSettle();
    expect(added, 1);
  });

  test('bot ids', () {
    expect(isBotId('bot:x1'), isTrue);
    expect(isBotId('user-1'), isFalse);
    expect(isBotId(null), isFalse);
  });
}
