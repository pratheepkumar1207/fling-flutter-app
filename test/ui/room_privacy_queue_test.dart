import 'package:insync/screens/party/chat_overlay.dart';
import 'package:insync/screens/party/privacy_pick_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _chat(List<Map<String, dynamic>> messages,
        {Widget? card, bool compact = false}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 600,
          child: ChatOverlay(
            messages: messages,
            onSend: (_, __, {replyTo}) {},
            myUserId: 'me',
            primaryColor: Colors.purple,
            textColor: Colors.white,
            roster: const [],
            myMicOn: false,
            myMicRequested: false,
            onMicTap: () {},
            onPoll: () {},
            onGift: () {},
            onShare: () {},
            onInvite: () {},
            newestCard: card,
            compact: compact,
          ),
        ),
      ),
    );

void main() {
  testWidgets('Queued songs show as their own line with who added them',
      (t) async {
    await t.pumpWidget(_chat([
      {
        'system': true,
        'type': 'queued',
        'title': 'Kaavaalaa',
        'sourceType': 'youtube',
        'addedBy': 'me',
        'text': 'x',
        'ts': 1,
      },
      {
        'system': true,
        'type': 'queued',
        'title': 'Naa Ready',
        'addedBy': 'a',
        'addedByName': 'Arun',
        'text': 'x',
        'ts': 2,
      },
    ]));
    expect(find.textContaining('Queued · Kaavaalaa · You', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Naa Ready · Arun', findRichText: true),
        findsOneWidget);
  });

  testWidgets('Privacy card sits in chat and sends the pick', (t) async {
    String? picked;
    await t.pumpWidget(_chat(const [], card: PrivacyPickCard(
      until: DateTime.now().add(const Duration(seconds: 15)),
      onPick: (v) async => picked = v,
    )));
    expect(find.text('Who can join?'), findsOneWidget);
    expect(find.textContaining('Goes public in'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Friends'));
    await t.pump();
    expect(picked, 'friends');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Narrow chat drops gift and invite', (t) async {
    await t.pumpWidget(_chat(const [], compact: true));
    expect(find.bySemanticsLabel('Send a gift'), findsNothing);
    expect(find.bySemanticsLabel('Invite people'), findsNothing);
    await t.pumpWidget(_chat(const []));
    expect(find.bySemanticsLabel('Send a gift'), findsOneWidget);
  });
}
