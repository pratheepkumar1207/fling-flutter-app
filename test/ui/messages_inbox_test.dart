import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/message.dart';
import 'package:fling/models/user.dart';
import 'package:fling/screens/messages/messages_screen.dart';
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

ConversationSummary _c(String id, String name, String last,
        {bool mine = false,
        int unread = 0,
        bool request = false,
        bool seen = false,
        String type = 'text',
        Map<String, dynamic>? activity,
        bool pinned = false,
        bool muted = false,
        int minutesAgo = 5}) =>
    ConversationSummary.fromJson({
      'userId': id,
      'name': name,
      'lastMessage': last,
      'lastMessageAt':
          _now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      'lastMessageIsMine': mine,
      'unreadCount': unread,
      'isRequest': request,
      'lastMessageSeen': seen,
      'lastMessageType': type,
      'online': unread > 0,
      'activity': activity,
      'pinned': pinned,
      'mutedUntil':
          muted ? _now.add(const Duration(days: 7)).toIso8601String() : null,
    });

final _chats = [
  _c('n', 'Naina', 'Haha same! Tonight at 9?', unread: 2, activity: {
    'roomId': 'r1',
    'title': 'Movie night',
    'roomType': 'watch',
    'memberCount': 4,
    'nowPlayingTitle': 'A really long film title that has to be cut off',
    'canJoin': true,
  }),
  _c('b', 'Bala B', 'Voice message', unread: 1, type: 'voice', minutesAgo: 90),
  _c('v', 'Vikram', 'Sure, send me the link',
      mine: true,
      seen: true,
      minutesAgo: 60,
      activity: {
        'roomId': 'r2',
        'title': 'Ludo night',
        'roomType': 'game',
        'gameType': 'ludo',
        'canJoin': false,
      }),
  _c('c', 'Chitra C', 'See you in the watch room',
      mine: true, minutesAgo: 200, pinned: true, muted: true),
  _c('x', 'Stranger', 'hi there', unread: 1, request: true),
];

Future<void> _render(WidgetTester t, Size size, double scale) async {
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
      home: MessagesScreen(
        initialConversations: _chats,
        initialGroups: [
          {
            'id': 'g1',
            'name': 'Movie night crew',
            'lastMessage': 'Aditya: popcorn',
            'lastMessageAt':
                _now.subtract(const Duration(minutes: 50)).toIso8601String(),
            'unreadCount': 3,
          }
        ],
        initialMatches: [
          {'userId': 'm1', 'name': 'Riya'},
          {'userId': 'n', 'name': 'Naina'},
        ],
        initialLikes: 12,
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _scrollTo(WidgetTester t, Finder f, {bool up = false}) =>
    t.scrollUntilVisible(f, up ? -80 : 80,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);

Future<void> _top(WidgetTester t) async {
  await t.drag(find.byType(CustomScrollView), const Offset(0, 3000));
  await t.pumpAndSettle();
}

void main() {
  test('request line prefers distance over city', () {
    expect(const RequestInfo(age: 24, city: 'Chennai', distanceKm: 3).line,
        '24 · 3 km away');
    expect(const RequestInfo(age: 24, city: 'Chennai').line, '24 · Chennai');
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.6),
  ]) {
    final tag = '${size.width.toInt()}@$scale';

    testWidgets('your turn, live chips and requests banner $tag', (t) async {
      await _render(t, size, scale);
      expect(t.takeException(), isNull);
      await _scrollTo(t, find.text('1 message request'));
      await _scrollTo(t, find.text('Your turn'));
      await _scrollTo(t, find.text('Bala B'));
      expect(find.text('Reply'), findsNWidgets(2)); // Naina and Bala
      expect(find.text('Stranger'), findsNothing); // requests stay apart

      await _scrollTo(t, find.text('Vikram'));
      expect(find.text('Recent'), findsOneWidget);
      expect(find.textContaining('Watching A really long film'), findsWidgets);
      // canJoin false → no "· Join".
      expect(find.text('Playing Ludo'), findsOneWidget);
      expect(find.bySemanticsLabel('Seen'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('filters $tag', (t) async {
      await _render(t, size, scale);
      await _scrollTo(t, find.text('1 message request'));
      await t.ensureVisible(find.text('1 message request'));
      await t.pumpAndSettle();
      await t.tap(find.text('1 message request'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Message requests'), findsOneWidget);
      Navigator.of(t.element(find.text('Message requests'))).pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));

      await _top(t);
      await _scrollTo(t, find.text('Unread'));
      await t.ensureVisible(find.text('Unread'));
      await t.pumpAndSettle();
      await t.tap(find.text('Unread'));
      await t.pump();
      expect(find.text('Your turn'), findsNothing); // plain list here
      // Naina's name is also on her match tile up top.
      await _scrollTo(t, find.text('Haha same! Tonight at 9?'));
      expect(find.text('Haha same! Tonight at 9?'), findsOneWidget);
      expect(find.text('Chitra C'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('strip, groups, pinned first, long-press menu $tag', (t) async {
      await _render(t, size, scale);
      expect(t.takeException(), isNull);
      expect(find.text('Your note'), findsOneWidget);
      expect(find.bySemanticsLabel('12 people like you'), findsOneWidget);
      expect(find.bySemanticsLabel('New match Riya'), findsOneWidget);
      // Naina already has a chat, so no NEW badge.
      expect(find.bySemanticsLabel('Message Naina'), findsOneWidget);

      await _scrollTo(t, find.text('Movie night crew'));
      expect(find.text('Movie night crew'), findsOneWidget); // group mixed in
      await _scrollTo(t, find.text('Chitra C'));
      expect(find.bySemanticsLabel('Pinned'), findsOneWidget);
      expect(find.bySemanticsLabel('Muted'), findsOneWidget);
      // Pinned Chitra is above the newer group in Recent.
      expect(t.getTopLeft(find.text('Chitra C')).dy,
          lessThan(t.getTopLeft(find.text('Movie night crew')).dy));

      await t.longPress(find.text('Chitra C'));
      await t.pumpAndSettle();
      expect(find.text('Unpin chat'), findsOneWidget);
      expect(find.text('Unmute'), findsOneWidget);
      expect(find.text('1 week'), findsOneWidget);
      expect(find.text('Delete chat'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
