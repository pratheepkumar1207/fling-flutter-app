import 'dart:convert';
import 'dart:io';

import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/post.dart';
import 'package:fling/models/user.dart';
import 'package:fling/screens/feed/hashtag_screen.dart';
import 'package:fling/screens/profile/close_friends_screen.dart';
import 'package:fling/screens/profile/profile_layout.dart';
import 'package:fling/screens/settings/privacy_screen.dart';
import 'package:fling/widgets/comments_sheet.dart';
import 'package:fling/widgets/people_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'package:fling/models/room_models.dart';
import 'package:fling/screens/party/game_room_body.dart';
import 'package:fling/screens/party/game_seat_prompts.dart';
import 'package:fling/screens/profile/profile_post_grid.dart';
import 'package:fling/widgets/game_board_view.dart';
import 'package:fling/widgets/game_seat.dart';
import 'package:fling/widgets/notes.dart';
import 'package:fling/widgets/reels_feed.dart';
import 'package:fling/widgets/room_settings_sheet.dart';
import 'package:fling/widgets/story_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the screens and widgets added for game rooms, profile and feed
/// at a small phone width with normal, large and very large system text,
/// plus a normal phone — any overflow or layout error fails the test.
/// (Release builds hide overflow stripes, so this is where they show up.)
const _sizes = [
  (Size(320, 640), 1.0),
  (Size(320, 640), 1.5),
  (Size(320, 640), 2.0),
  (Size(412, 915), 1.0),
];

late final Map<String, dynamic> _games;

const _long = 'Venkatalakshmi Ramasubramanian';

/// A signed-in user for screens that read one (no network involved).
class _FakeAuth extends AuthProvider {
  final User _u = User.fromJson({
    'id': 'me',
    'name': _long,
    'username': 'venkatalakshmi_r',
    'isVip': true,
    'roomActivityVisibility': 'friends',
  });
  @override
  User? get user => _u;
}

Future<void> _render(WidgetTester tester, Widget child,
    {required Size size, required double text, bool page = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: _FakeAuth(),
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: page ? child : Scaffold(body: child),
      ),
    ),
  ));
  // Lets failed network loads (there's no server in tests) settle into
  // their empty/error states before checking for layout errors.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
}

Widget _scope(Widget child, {bool host = false, bool requested = false}) =>
    GameSeatScope(
      isHost: host,
      requested: requested,
      invited: false,
      onSit: () {},
      onRequest: () {},
      onCancelRequest: () {},
      onInvite: host ? () {} : null,
      avatarFor: (_) => null,
      child: child,
    );

Widget _gameRoom(String type, Map<String, dynamic>? game,
        {bool host = false, List<Widget> banners = const []}) =>
    GameRoomBody(
      songPlayer: null,
      onAddSong: () {},
      banners: banners,
      board: _scope(
          GameBoardView(
            gameType: type == 'chess_waiting'
                ? 'chess'
                : type == 'truth_or_dare_waiting'
                    ? 'truth_or_dare'
                    : type,
            game: game,
            myUserId: 'me',
            isHost: host,
            onJoin: () {},
            onMove: (_) {},
            onReset: () {},
          ),
          host: host),
      chat: const Placeholder(),
      messages: [
        {'name': _long, 'text': 'a very long message ' * 6},
      ],
    );

Post _post(String id, String type, {String? text}) => Post.fromJson({
      'id': id,
      'author': {'id': 'p1', 'name': _long},
      'mediaType': type,
      'text': text,
      'pollOptions': type == 'poll' ? ['Leo', 'Jailer'] : null,
      'likesCount': 1200,
      'createdAt': '2026-10-21T10:00:00Z',
    });

void _noop() {}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((b) => ByteData.sublistView(b)));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(File('test/fixtures/materialicons-regular.otf')
        .readAsBytes()
        .then((b) => ByteData.sublistView(b)));
    await icons.load();
    _games = jsonDecode(File('test/fixtures/game_states.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  for (final (size, text) in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()} @${text}x';

    for (final type in [
      'tictactoe',
      'ludo',
      'chess',
      'chess_waiting',
      'uno',
      'truth_or_dare',
      'truth_or_dare_waiting',
    ]) {
      testWidgets('game room $type renders cleanly at $label', (tester) async {
        await _render(
            tester,
            _gameRoom(type, Map<String, dynamic>.from(_games[type] as Map),
                host: true,
                banners: [
                  GameSeatBanner(
                    person: RosterEntry(userId: 'p2', name: _long),
                    text: '$_long wants to play',
                    acceptLabel: 'Let in',
                    onAccept: () {},
                    onDecline: () {},
                    more: 3,
                  ),
                ]),
            size: size,
            text: text);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('guest asking to play renders at $label', (tester) async {
      await _render(
          tester,
          _gameRoom('chess_waiting',
              Map<String, dynamic>.from(_games['chess_waiting'] as Map)),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('story bar renders at $label', (tester) async {
      await _render(
          tester,
          StoryBar(
            stories: [
              for (var i = 0; i < 6; i++)
                StoryEntry(
                    userId: 'u$i',
                    name: i.isEven ? _long : 'Bala',
                    items: [
                      StoryItem(
                          id: 's$i',
                          mediaType: 'text',
                          createdAt: DateTime(2026),
                          closeFriends: i == 1),
                    ]),
            ],
          ),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile post grid renders at $label', (tester) async {
      await _render(
          tester,
          ProfilePostGrid(
            posts: [
              _post('1', 'text', text: 'Movie night #WatchParty ' * 8),
              _post('2', 'poll', text: 'Which one?'),
              _post('3', 'voice'),
              _post('4', 'video_link', text: 'Trailer'),
            ],
            emptyText: 'No posts yet',
          ),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
      await _render(
          tester,
          ProfilePostGrid(posts: [_post('5', 'reel')], reels: true, emptyText: ''),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('note bubble renders at $label', (tester) async {
      await _render(
          tester,
          const Center(
              child: NoteBubble(
                  text: 'watching Leo tonight with everyone, come join')),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full-screen reels render at $label', (tester) async {
      await _render(
          tester,
          ReelsScreen(
            reels: [_post('r1', 'reel', text: 'Dance practice ' * 10)],
            onLike: (p) async => p,
            onSave: (p) async => p,
            onOpenComments: (_) {},
            onCreate: () {},
          ),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
    });

    for (final (name, screen) in [
      ('privacy', const PrivacyScreen()),
      ('arrange profile', const ArrangeProfileScreen()),
      ('close friends', const CloseFriendsScreen()),
      ('archive', const ArchiveScreen()),
      ('hashtag', const HashtagScreen(tag: 'watchpartywithfriendstonight')),
    ]) {
      testWidgets('$name screen renders at $label', (tester) async {
        await _render(tester, screen, size: size, text: text, page: true);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('comments sheet renders at $label', (tester) async {
      await _render(
          tester,
          const CommentsSheet(
              postId: 'p1', onCommented: _noop, authorName: _long),
          size: size,
          text: text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('people picker renders at $label', (tester) async {
      await _render(
          tester,
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPeoplePicker(context,
                    title: 'Invite collaborator to this post'),
                child: const Text('open'),
              ),
            ),
          ),
          size: size,
          text: text);
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('room settings sheet renders at $label', (tester) async {
      await _render(
          tester,
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showRoomSettingsSheet(context,
                    room: {
                      'id': 'r1',
                      'roomType': 'game',
                      'gameType': 'chess',
                      'visibility': 'subscribers',
                      'boostedUntil': DateTime.now()
                          .add(const Duration(hours: 5))
                          .toIso8601String(),
                    },
                    onChanged: () {}),
                child: const Text('open'),
              ),
            ),
          ),
          size: size,
          text: text);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
