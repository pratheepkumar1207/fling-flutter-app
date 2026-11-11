import 'package:insync/models/room_models.dart';
import 'package:insync/screens/party/chat_overlay.dart';
import 'package:insync/widgets/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _overlay(List<Map<String, dynamic>> messages,
    {List<RosterEntry> roster = const [],
    bool isHost = false,
    VoidCallback? onSkip,
    VoidCallback? onVoteSkip}) {
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
          onToggleLike: (_) {},
          isHost: isHost,
          onSkip: onSkip,
          onVoteSkip: onVoteSkip,
          skipVoteCount: 1,
          skipVoteRequired: 3,
        ),
      ),
    ),
  );
}

Finder _rich(String text) => find.textContaining(text, findRichText: true);

void main() {
  testWidgets('Now Playing line: label, title and who pinned it',
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
        'ts': 1,
      },
    ]));
    expect(_rich('Now Playing'), findsOneWidget);
    expect(_rich('Big Buck Bunny'), findsOneWidget);
    expect(_rich('QA Tester'), findsOneWidget);
    expect(find.byType(Avatar), findsOneWidget);
    expect(find.bySemanticsLabel('Like'), findsOneWidget);
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
        'ts': 1,
      },
    ], roster: [
      RosterEntry(userId: 'u2', name: 'Asha Rao'),
    ]));
    expect(_rich('Some Film'), findsOneWidget);
    expect(_rich('Asha Rao'), findsOneWidget);
  });

  testWidgets('Older messages without a pinner still render', (tester) async {
    await tester.pumpWidget(_overlay([
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'https://example.com/old',
        'title': 'Old Song',
        'sourceType': 'drive',
        'ts': 1,
      },
    ]));
    expect(_rich('Old Song'), findsOneWidget);
    expect(find.byType(Avatar), findsNothing);
  });

  testWidgets('Only the newest says Now Playing; skip only on it',
      (tester) async {
    var votes = 0;
    await tester.pumpWidget(_overlay([
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'a',
        'title': 'First Song',
        'ts': 1,
      },
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'b',
        'title': 'Second Song',
        'ts': 2,
      },
    ], onVoteSkip: () => votes++));
    expect(
        find.bySemanticsLabel(RegExp('^Played: First Song')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Now playing: Second Song')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Vote to skip, 1 of 3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Vote to skip, 1 of 3'));
    expect(votes, 1);
  });

  testWidgets('A long title is cut so the name still shows in 3 lines',
      (tester) async {
    await tester.pumpWidget(_overlay([
      {
        'system': true,
        'type': 'nowPlaying',
        'videoUrl': 'x',
        'title': 'Hukum – Thalaivar Alappara | Jailer | Superstar Rajinikanth '
            '| Sun Pictures | Anirudh Ravichander | Nelson Dilipkumar | '
            'Official Lyric Video 4K | Full Song With Lyrics',
        'pinnedByName': 'Priya',
        'ts': 1,
      },
    ]));
    final text = tester.widget<RichText>(_rich('Priya').first);
    expect(text.text.toPlainText(), contains('…'));
    expect(text.text.toPlainText(), contains('Priya'));
  });
}
