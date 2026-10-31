import 'package:fling/core/room_person_scope.dart';
import 'package:fling/models/room_models.dart';
import 'package:fling/screens/party/room_person_sheets.dart';
import 'package:fling/widgets/voice_stage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _roster = [
  RosterEntry(userId: 'h', name: 'Bala'),
  RosterEntry(userId: 's', name: 'Divya'),
  RosterEntry(userId: 'c', name: 'Anu'),
  RosterEntry(userId: 'l', name: 'Chitra'),
  RosterEntry(userId: 'me', name: 'Test User'),
];

Widget _stage({
  String? me = 'me',
  List<String> pending = const [],
  void Function(String)? onTap,
  void Function(String)? onHold,
  double scale = 1,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: RoomPersonScope(
          onTap: onTap ?? (_) {},
          onLongPress: (id, _) => onHold?.call(id),
          child: Scaffold(
            body: SingleChildScrollView(
              child: VoiceStageView(
                roster: _roster,
                activeMics: const ['s', 'c'],
                pendingRequests: pending,
                maxSlots: 8,
                hostId: 'h',
                coHostId: 'c',
                myUserId: me,
                onApprove: (_) {},
                onDeny: (_) {},
                onOpenListeners: () {},
                onAskToSpeak: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      ),
    );

List<PersonAction> _actions({
  bool host = true,
  bool coHost = false,
  bool owner = true,
  bool self = false,
  bool targetHost = false,
  bool targetCoHost = false,
  bool onStage = true,
  bool muted = false,
}) =>
    personActions(
      iAmHost: host,
      iAmCoHost: coHost,
      iOwnRoom: owner,
      isSelf: self,
      targetIsHost: targetHost,
      targetIsCoHost: targetCoHost,
      voice: true,
      onStage: onStage,
      muted: muted,
    );

void main() {
  test('Host seat 1, co-host seat 2, then speakers in order', () {
    expect(
        voiceSeatOrder(
            inRoom: const ['s', 'c', 'h', 'x'],
            hostId: 'h',
            coHostId: 'c',
            activeMics: const ['s', 'c']),
        ['h', 'c', 's']);
    // The co-host holding the host's seat isn't shown twice.
    expect(
        voiceSeatOrder(
            inRoom: const ['c', 's'],
            hostId: 'c',
            coHostId: 'c',
            activeMics: const ['c', 's']),
        ['c', 's']);
    // Someone who left doesn't keep a seat.
    expect(
        voiceSeatOrder(
            inRoom: const ['h'],
            hostId: 'h',
            coHostId: 'c',
            activeMics: const ['s']),
        ['h']);
  });

  test('Long-press options', () {
    expect(_actions(), [
      PersonAction.mute,
      PersonAction.makeCoHost,
      PersonAction.moveToListeners,
      PersonAction.remove,
      PersonAction.ban,
    ]);
    expect(_actions(onStage: false), [
      PersonAction.inviteToSpeak,
      PersonAction.makeCoHost,
      PersonAction.remove,
      PersonAction.ban,
    ]);
    expect(_actions(muted: true).first, PersonAction.unmute);
    expect(_actions(targetCoHost: true), contains(PersonAction.removeCoHost));
    // Co-host: Mute, Move to listeners, Remove only.
    expect(_actions(host: false, coHost: true, owner: false), [
      PersonAction.mute,
      PersonAction.moveToListeners,
      PersonAction.remove,
    ]);
    expect(_actions(host: false, coHost: true, targetHost: true), isEmpty);
    expect(_actions(self: true), isEmpty);
    expect(_actions(host: false), isEmpty);
    // Keeping the seat for an absent owner doesn't let you ban for them.
    expect(_actions(owner: false), isNot(contains(PersonAction.ban)));
  });

  testWidgets('A listener sees the seats, count and Ask to speak', (t) async {
    await t.pumpWidget(_stage());
    expect(find.text('Bala'), findsOneWidget);
    expect(find.text('Anu'), findsOneWidget);
    expect(find.text('Ask to speak'), findsOneWidget);
    expect(find.text('Empty'), findsNWidgets(4));
    expect(find.text('2 listening'), findsOneWidget);
    expect(find.text('You’re hosting'), findsNothing);
  });

  testWidgets('Host: header, request card, Invite seats', (t) async {
    await t.pumpWidget(_stage(me: 'h', pending: const ['l', 'me']));
    expect(find.text('You’re hosting'), findsOneWidget);
    expect(find.text('Chitra wants to speak · 2 waiting'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Invite'), findsNWidgets(5));
  });

  testWidgets('Co-host: note, no settings', (t) async {
    await t.pumpWidget(_stage(me: 'c'));
    expect(find.text('You’re a co-host'), findsOneWidget);
    expect(find.textContaining('Bala made you a co-host'), findsOneWidget);
    expect(find.byTooltip('Room settings'), findsNothing);
    await t.tap(find.byTooltip('Close'));
    await t.pump();
    expect(find.textContaining('Bala made you a co-host'), findsNothing);
  });

  testWidgets('Tap opens the card, long press the options', (t) async {
    String? tapped, held;
    await t.pumpWidget(
        _stage(onTap: (id) => tapped = id, onHold: (id) => held = id));
    await t.tap(find.text('Anu'));
    expect(tapped, 'c');
    await t.longPress(find.text('Divya'));
    expect(held, 's');
  });

  testWidgets('Fits a small phone with big text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_stage(me: 'c', pending: const ['l'], scale: 1.6));
    expect(t.takeException(), isNull);
  });

  group('Profile card', () {
    Future<void> open(WidgetTester t, Map<String, dynamic> p) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showRoomPersonCard(c,
                person: _roster[3],
                isMe: false,
                status: 'Listening',
                onMessage: () {},
                initialProfile: p),
            child: const Text('open'),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('Friend: Message and Following', (t) async {
      await open(t, {
        'friendStatus': 'friends',
        'isFollowedByMe': true,
        'postCount': 12,
        'followerCount': 1200,
        'followingCount': 3,
        'username': 'chitra',
        'followedBy': {
          'names': ['Anu'],
          'count': 3
        },
      });
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Following'), findsNWidgets(2)); // button and count
      expect(find.text('@chitra · Listening'), findsOneWidget);
      expect(find.text('Followed by Anu and 2 others'), findsOneWidget);
      expect(find.text('View full profile'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Not a friend: Add friend, no Message', (t) async {
      await open(t, {'friendStatus': 'none'});
      expect(find.text('Add friend'), findsOneWidget);
      expect(find.text('Message'), findsNothing);
    });

    testWidgets('Requested says when they can message', (t) async {
      await open(t, {'friendStatus': 'pending_sent'});
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('You can message Chitra once you’re friends'),
          findsOneWidget);
    });
  });
}
