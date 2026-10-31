import 'package:fling/screens/party/chat_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Closing the keyboard ends typing', (t) async {
    final focus = <bool>[];
    await t.pumpWidget(MaterialApp(
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
          onFocusChanged: focus.add,
        ),
      ),
    ));
    await t.tap(find.byType(TextField));
    await t.pump();
    expect(focus.last, isTrue);

    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    expect(focus.last, isTrue);

    t.view.viewInsets = FakeViewPadding.zero;
    await t.pump();
    expect(focus.last, isFalse);
  });
}
