import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/message.dart';
import 'package:fling/models/user.dart';
import 'package:fling/screens/messages/message_requests_screen.dart';
import 'package:fling/screens/messages/message_thread_screen.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends AuthProvider {
  final User _u = User.fromJson({'id': 'me', 'name': 'Test User'});
  @override
  User? get user => _u;
}

final _now = DateTime.now();

DirectMessage _m(String id, String from, String text,
        {int minutesAgo = 0,
        String? replyTo,
        Map<String, String> reactions = const {},
        bool read = false}) =>
    DirectMessage(
      id: id,
      senderId: from,
      recipientId: from == 'me' ? 'n' : 'me',
      text: text,
      createdAt: _now.subtract(Duration(minutes: minutesAgo)),
      readAt: read ? _now : null,
      replyToId: replyTo,
      reactions: reactions,
    );

final _thread = [
  _m('1', 'n', 'Did you finish the series we were watching?',
      minutesAgo: 60 * 26),
  _m('2', 'n', 'No spoilers please', minutesAgo: 30),
  _m('3', 'n', 'Seriously, none at all', minutesAgo: 29),
  _m('4', 'me', 'Two episodes left! Want to finish it together?',
      minutesAgo: 20, reactions: {'n': '❤️'}),
  _m('5', 'n', 'Yes!! Tonight at 9?', minutesAgo: 10, replyTo: '4'),
  _m('6', 'me', 'Perfect, I’ll send the invite', minutesAgo: 2, read: true),
];

ConversationSummary _req(
        String id, String name, String text, Map<String, dynamic> info) =>
    ConversationSummary.fromJson({
      'userId': id,
      'name': name,
      'lastMessage': text,
      'lastMessageAt': _now.toIso8601String(),
      'lastMessageIsMine': false,
      'unreadCount': 1,
      'isRequest': true,
      'requestInfo': info,
    });

Future<void> _render(
    WidgetTester t, Widget screen, Size size, double scale) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: _FakeAuth(),
    child: MaterialApp(
      theme: AppTheme.darkWithoutWebFonts(),
      builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: w!),
      home: screen,
    ),
  ));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.6),
  ]) {
    final tag = '${size.width.toInt()}@$scale';

    testWidgets('chat: days, replies, reactions, seen, composer $tag',
        (t) async {
      await _render(
          t,
          MessageThreadScreen(
              userId: 'n', name: 'Naina Raman', initialMessages: _thread),
          size,
          scale);
      expect(t.takeException(), isNull);
      expect(find.text('Invite to watch'), findsOneWidget);
      expect(find.text('Message Naina…'), findsOneWidget);
      expect(find.bySemanticsLabel('Send'), findsNothing); // mic until text
      // Opens at the newest message.
      expect(find.textContaining('Seen'), findsOneWidget);
      expect(find.text('Yes!! Tonight at 9?'), findsOneWidget);
      expect(find.text('You'), findsOneWidget); // reply quote of mine
      await t.scrollUntilVisible(find.bySemanticsLabel(RegExp('Reactions')), 60,
          scrollable: find.byType(Scrollable).first);
      await t.scrollUntilVisible(find.text('TODAY'), 60,
          scrollable: find.byType(Scrollable).first);
      await t.scrollUntilVisible(find.text('Yes!! Tonight at 9?'), -60,
          scrollable: find.byType(Scrollable).first);

      await t.enterText(find.byType(TextField), 'hello');
      await t.pump();
      expect(find.bySemanticsLabel('Send'), findsOneWidget);

      await t.longPress(find.text('Yes!! Tonight at 9?'));
      await t.pumpAndSettle();
      await t.tap(find.text('Reply'));
      await t.pumpAndSettle();
      expect(find.text('Replying to Naina'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('requests: cards and actions $tag', (t) async {
      await _render(
          t,
          MessageRequestsScreen(initialRequests: [
            _req('r', 'Riya', 'Hey! Loved your pick in movie night.', {
              'age': 24,
              'city': 'Chennai',
              'isVerified': true,
              'sharedInterests': 2,
              'followsYou': false,
            }),
            _req('k', 'Karthik With A Really Long Name', 'Retro games?',
                {'age': 27, 'followsYou': true}),
          ]),
          size,
          scale);
      expect(t.takeException(), isNull);
      expect(find.text('Message requests'), findsOneWidget);
      expect(find.text('2 requests'), findsOneWidget);
      await t.scrollUntilVisible(
          find.text('24 · Chennai · 2 shared interests'), 60,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('24 · Chennai · 2 shared interests'), findsOneWidget);
      expect(find.bySemanticsLabel('Verified'), findsOneWidget);
      await t.scrollUntilVisible(find.text('27 · Follows you'), 60,
          scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Delete all'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete all'));
      await t.pumpAndSettle();
      expect(find.text('Delete all requests?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
