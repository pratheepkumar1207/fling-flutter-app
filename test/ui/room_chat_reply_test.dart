import 'package:insync/models/room_models.dart';
import 'package:insync/screens/party/chat_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Room chat: sides, reply, tags by name, events, gift', (t) async {
    t.view.physicalSize = const Size(390, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final sent = <List<Object?>>[];
    String? giftFor = 'not asked';
    final roster = [
      RosterEntry(
          userId: 'me',
          name: 'Me',
          username: 'me_here',
          isHost: false,
          micOn: false),
      RosterEntry(
          userId: 'b',
          name: 'Bala Kumar',
          username: 'bala',
          isHost: true,
          micOn: false),
    ];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox(
          height: 700,
          child: ChatOverlay(
            messages: const [
              {
                'system': true,
                'event': 'joined',
                'userId': 'b',
                'text': 'Bala Kumar joined',
                'ts': 0
              },
              {
                'id': 'm1',
                'senderId': 'b',
                'name': 'Bala Kumar',
                'text': 'hi @me_here',
                'ts': 1
              },
              {
                'id': 'm2',
                'senderId': 'me',
                'name': 'Me',
                'text': 'hello',
                'ts': 2,
                'replyTo': {
                  'senderId': 'b',
                  'name': 'Bala Kumar',
                  'text': 'hi @me_here'
                }
              },
              {
                'system': true,
                'event': 'removed',
                'userId': 'x',
                'text': 'Ravi was removed',
                'ts': 3
              },
            ],
            onSend: (text, ids, {replyTo}) =>
                sent.add([text, ids, replyTo?['id']]),
            myUserId: 'me',
            primaryColor: Colors.purple,
            textColor: Colors.white,
            roster: roster,
            myMicOn: false,
            myMicRequested: false,
            onMicTap: () {},
            onPoll: () {},
            onGift: () {},
            onGiftFor: (id) => giftFor = id,
            onShare: () {},
            onInvite: () {},
          ),
        ),
      ),
    ));
    // Mine on the right, theirs on the left; a tag shows the person's name.
    final mine = t.getCenter(find.text('hello', findRichText: true));
    final theirs = t.getCenter(find.text('hi @Me', findRichText: true));
    expect(mine.dx, greaterThan(theirs.dx));
    expect(find.text('You'), findsOneWidget);
    // Joins and removals show as their own lines.
    expect(find.text('Bala Kumar joined'), findsOneWidget);
    expect(find.text('Ravi was removed by the host'), findsOneWidget);

    // Gift with nobody tagged: the sheet asks who.
    await t.tap(find.bySemanticsLabel('Send a gift'));
    expect(giftFor, isNull);

    // Long-press Bala's message: the sheet offers reactions, Reply, Copy.
    await t.longPress(find.text('hi @Me', findRichText: true));
    await t.pumpAndSettle();
    await t.tap(find.text('Reply'));
    await t.pumpAndSettle();
    expect(find.text('Replying to Bala Kumar'), findsOneWidget);

    // @ suggestions: tap to tag; the name goes in the box.
    await t.enterText(find.byType(TextField), 'thanks @ba');
    await t.pump();
    expect(find.text('Tap someone to tag them'), findsOneWidget);
    await t.tap(find.text('@bala'));
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump();
    if (sent.isEmpty) {
      await t.tap(find.bySemanticsLabel(RegExp('Send')).first);
      await t.pump();
    }
    expect(sent.single[0], 'thanks @Bala Kumar');
    expect(sent.single[1], ['b']);
    expect(sent.single[2], 'm1');
    expect(find.text('Replying to Bala Kumar'), findsNothing);
  });

  testWidgets('Gift goes to whoever is tagged in the box', (t) async {
    String? giftFor;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: ChatOverlay(
            messages: const [],
            onSend: (_, __, {replyTo}) {},
            myUserId: 'me',
            primaryColor: Colors.purple,
            textColor: Colors.white,
            roster: [
              RosterEntry(userId: 'p', name: 'Priya', username: 'priya'),
            ],
            myMicOn: false,
            myMicRequested: false,
            onMicTap: () {},
            onPoll: () {},
            onGift: () {},
            onGiftFor: (id) => giftFor = id,
            onShare: () {},
            onInvite: () {},
          ),
        ),
      ),
    ));
    await t.enterText(find.byType(TextField), '@pri');
    await t.pump();
    await t.tap(find.text('@priya'));
    await t.pump();
    // Typing hides gift; close the keyboard to see it again.
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.tap(find.bySemanticsLabel('Send a gift'));
    expect(giftFor, 'p');
  });
}
