import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/lobby/choose_game_screen.dart';

void main() {
  testWidgets('all five boards draw; pick one; small phone fits', (t) async {
    t.view.physicalSize = const Size(640, 1200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ChooseGameScreen()));
    await t.pump(const Duration(seconds: 4)); // bottle finishes its spin
    for (final g in ['Chess', 'Ludo', 'Tic Tac Toe', 'UNO']) {
      expect(find.bySemanticsLabel(RegExp('^$g, ')), findsOneWidget);
    }
    expect(find.text('Pick a game'), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp(r'^Ludo, ')));
    await t.pump();
    expect(find.text('Start game · Ludo'), findsOneWidget);
    await t.drag(find.byType(GridView).first, const Offset(0, -400));
    await t.pump();
    await t.tap(find.bySemanticsLabel(RegExp(r'^Truth or Dare, ')));
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Start game · Truth or Dare'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
