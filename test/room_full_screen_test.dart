import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/core/room_playback.dart';
import 'package:insync/screens/party/full_screen_controls.dart';
import 'package:insync/screens/party/player_settings_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(
    home: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox(width: 800, height: 380, child: child)));

void main() {
  test('room position moves at the host speed', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = {
      'position': 100,
      'isPlaying': true,
      'updatedAt': now - 10000,
      'rate': 1.5
    };
    expect(roomRate(p), 1.5);
    expect(roomPosition(p), closeTo(115, 0.5));
    expect(roomRate({'position': 0}), 1);
    expect(roomPosition({'position': 50, 'isPlaying': false, 'updatedAt': now}),
        50);
  });

  testWidgets('host gets play and jumps in full screen', (tester) async {
    var played = false;
    double? seekedTo;
    await tester.pumpWidget(_wrap(RoomFullScreenControls(
      initiallyShown: true,
      title: 'Lupin',
      isHost: true,
      playing: false,
      elapsed: 60,
      duration: 600,
      onTogglePlay: () => played = true,
      onSeekTo: (v) => seekedTo = v,
      onSkip: () {},
      onSettings: () {},
    )));
    await tester.tap(find.bySemanticsLabel('Play for everyone'));
    expect(played, isTrue);
    await tester.tap(find.bySemanticsLabel('Forward 10 seconds'));
    expect(seekedTo, 70);
    expect(find.bySemanticsLabel('Next title'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Vote to skip')), findsNothing);
  });

  testWidgets('viewers get like and vote skip, no play', (tester) async {
    await tester.pumpWidget(_wrap(RoomFullScreenControls(
      initiallyShown: true,
      title: 'Lupin',
      isHost: false,
      playing: true,
      elapsed: 60,
      duration: 600,
      onToggleLike: () {},
      onVoteSkip: () {},
      skipVoteCount: 1,
      skipVoteRequired: 3,
      onSettings: () {},
      onCatchUp: () {},
    )));
    expect(find.bySemanticsLabel('Pause for everyone'), findsNothing);
    expect(find.bySemanticsLabel('Back 10 seconds'), findsNothing);
    expect(find.bySemanticsLabel('Like'), findsOneWidget);
    expect(find.bySemanticsLabel('Vote to skip, 1 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Catch up with host'), findsOneWidget);
  });

  testWidgets('speed is locked for viewers and open to the host',
      (tester) async {
    await tester.pumpWidget(_wrap(const PlayerSettingsSheet(
        label: 'YouTube', isHost: false, rate: 1.25)));
    expect(find.text('Normal · set by host'), findsNothing);
    expect(find.text('1.25x · set by host'), findsOneWidget);

    double? picked;
    await tester.pumpWidget(_wrap(PlayerSettingsSheet(
        label: 'YouTube', isHost: true, rate: 1, onRate: (r) => picked = r)));
    await tester.tap(find.text('Speed for everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(picked, 1.5);
  });

  testWidgets('full screen shows only the picture until a tap', (tester) async {
    await tester.pumpWidget(_wrap(RoomFullScreenControls(
      title: 'Lupin',
      isHost: true,
      playing: true,
      elapsed: 60,
      duration: 600,
      onTogglePlay: () {},
      onSettings: () {},
    )));
    expect(find.bySemanticsLabel('Pause for everyone'), findsNothing);
    await tester.tapAt(const Offset(400, 190));
    await tester.pump();
    expect(find.bySemanticsLabel('Pause for everyone'), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.bySemanticsLabel('Pause for everyone'), findsNothing);
  });
}
