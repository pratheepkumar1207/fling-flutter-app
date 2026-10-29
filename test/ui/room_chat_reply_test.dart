import 'package:fling/models/room_models.dart';
import 'package:fling/screens/party/chat_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Room chat: left/right, reply, @ suggestions', (t) async {
    t.view.physicalSize = const Size(390, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final sent = <List<Object?>>[];
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
            onShare: () {},
            onInvite: () {},
          ),
        ),
      ),
    ));
    // Mine on the right, theirs on the left.
    final mine = t.getCenter(find.text('hello', findRichText: true));
    final theirs =
        t.getCenter(find.textContaining('Bala Kumar  hi', findRichText: true));
    expect(mine.dx, greaterThan(theirs.dx));
    // The reply quote shows inside my message.
    expect(find.text('Bala Kumar'), findsWidgets);

    // Long-press Bala's message to reply.
    await t.longPress(
        find.textContaining('Bala Kumar  hi', findRichText: true).first);
    await t.pump();
    expect(find.text('Replying to Bala Kumar'), findsOneWidget);

    // @ suggestions: name + handle, tap to tag.
    await t.enterText(find.byType(TextField), 'thanks @ba');
    await t.pump();
    expect(find.text('Tap someone to tag them'), findsOneWidget);
    expect(find.text('@bala'), findsOneWidget);
    await t.tap(find.text('@bala'));
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump();
    if (sent.isEmpty) {
      await t.tap(find.bySemanticsLabel(RegExp('Send')).first);
      await t.pump();
    }
    expect(sent.single[0], 'thanks @bala');
    expect(sent.single[1], ['b']);
    expect(sent.single[2], 'm1');
    expect(find.text('Replying to Bala Kumar'), findsNothing);
  });
}
