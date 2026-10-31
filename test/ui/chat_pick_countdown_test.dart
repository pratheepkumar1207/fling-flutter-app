import 'package:fling/screens/party/chat_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _chat({DateTime? endsAt, bool waiting = false}) => MaterialApp(
      home: Scaffold(
        body: ChatOverlay(
          messages: const [],
          onSend: (_, __, {replyTo}) {},
          primaryColor: Colors.blue,
          textColor: Colors.white,
          roster: const [],
          myMicOn: false,
          myMicRequested: false,
          onMicTap: () {},
          onPoll: () {},
          onGift: () {},
          onShare: () {},
          onInvite: () {},
          pickEndsAt: endsAt,
          pickWaiting: waiting,
        ),
      ),
    );

void main() {
  testWidgets('The next-song countdown shows in the chat', (t) async {
    await t.pumpWidget(_chat());
    expect(find.text('Vote for what plays next'), findsNothing);

    await t.pumpWidget(
        _chat(endsAt: DateTime.now().add(const Duration(seconds: 7))));
    expect(find.text('Vote for what plays next'), findsOneWidget);

    await t.pumpWidget(_chat(waiting: true));
    expect(find.text('Pick what plays next'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
