import 'package:fling/theme/insync_icons.dart';
import 'package:fling/models/room_models.dart';
import 'package:fling/screens/party/chat_overlay.dart';
import 'package:fling/widgets/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _overlay(List<Map<String, dynamic>> messages,
    {List<RosterEntry> roster = const []}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        height: 500,
        child: ChatOverlay(
          messages: messages,
          onSend: (_, __, {replyTo}) {},
          primaryColor: Colors.blue,
          textColor: Colors.white,
          roster: roster,
          myMicOn: false,
          myMicRequested: false,
          onMicTap: () {},
          onPoll: () {},
          onGift: () {},
          onShare: () {},
          onInvite: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Now playing card shows the pinner avatar and the video title',
      (tester) async {
    await tester.pumpWidget(_overlay([
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        'title': 'Big Buck Bunny',
        'sourceType': 'youtube',
        'pinnedBy': 'u1',
        'pinnedByName': 'QA Tester',
        'pinnedByAvatar': null,
      },
    ]));
    expect(find.text('Now playing'), findsNothing);
    expect(find.text('Big Buck Bunny'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is InIcon && w.icon == InIcons.tv),
        findsOneWidget);
    expect(find.byType(Avatar), findsOneWidget);
    expect(find.text('QT'), findsOneWidget);
  });

  testWidgets('Pinner falls back to the live roster when the message lacks it',
      (tester) async {
    await tester.pumpWidget(_overlay([
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'https://example.com/v',
        'title': 'Some Film',
        'sourceType': 'netflix',
        'pinnedBy': 'u2',
      },
    ], roster: [
      RosterEntry(userId: 'u2', name: 'Asha Rao'),
    ]));
    expect(find.text('Some Film'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is InIcon && w.icon == InIcons.tv),
        findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
  });

  testWidgets('Older messages without a pinner still render', (tester) async {
    await tester.pumpWidget(_overlay([
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'https://example.com/old',
        'title': 'Old Song',
        'sourceType': 'drive',
      },
    ]));
    expect(find.text('Old Song'), findsOneWidget);
    expect(find.byType(Avatar), findsNothing);
    expect(
        find.byWidgetPredicate((w) => w is InIcon && w.icon == InIcons.cloud),
        findsOneWidget);
  });
}
