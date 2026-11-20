import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/screens/shell/create_room_screen.dart';

void main() {
  testWidgets('pick a type, Continue names it; fits a small phone', (t) async {
    t.view.physicalSize = const Size(640, 1200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: CreateRoomTypeScreen()));
    expect(find.text('Pick a room type'), findsOneWidget);
    expect(find.text('Go live'), findsNothing);
    for (final name in ['Watch', 'Talk', 'Game', 'Tournament']) {
      expect(find.bySemanticsLabel(RegExp('^$name, ')), findsOneWidget);
    }
    await t.tap(find.bySemanticsLabel(RegExp(r'^Tournament, ')));
    await t.pump();
    expect(find.text('Continue · Tournament'), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp(r'^Watch, ')));
    await t.pump();
    expect(find.text('Continue · Watch'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
