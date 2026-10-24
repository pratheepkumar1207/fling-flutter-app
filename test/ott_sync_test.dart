import 'package:fling/screens/party/ott_sync_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Netflix/Prime sync, with the Android side (OttRemoteChannel.kt) faked:
/// the "Netflix app" is just this map, and every command sent to it is
/// recorded.
const _channel = MethodChannel('com.fling.app/ott_remote');

late Map<String, dynamic>? netflix;
late List<MethodCall> calls;
bool installed = true;
bool access = true;

void _fakeAndroid() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    calls.add(call);
    switch (call.method) {
      case 'isInstalled':
        return installed;
      case 'hasAccess':
        return access;
      case 'getState':
        return netflix;
      case 'play':
        netflix?['playing'] = true;
        return true;
      case 'pause':
        netflix?['playing'] = false;
        return true;
      case 'seekTo':
        netflix?['positionMs'] = call.arguments['positionMs'];
        return true;
    }
    return null;
  });
}

Iterable<String> sent() => calls
    .map((c) => c.method)
    .where((m) => !['isInstalled', 'hasAccess', 'getState'].contains(m));

Future<List<(String, double)>> _mount(
  WidgetTester tester, {
  required bool isHost,
  required bool roomPlaying,
  required double roomPosition,
  bool hasRoomState = true,
  List<(String, double)>? hostSent,
}) async {
  final statuses = <(String, double)>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        height: 100,
        child: OttSyncPanel(
          platform: 'netflix',
          label: 'Netflix',
          titleUrl: 'https://www.netflix.com/watch/1',
          isHost: isHost,
          roomPlaying: roomPlaying,
          hasRoomState: hasRoomState,
          roomPosition: () => roomPosition,
          onPlay: (p) => hostSent?.add(('play', p)),
          onPause: (p) => hostSent?.add(('pause', p)),
          onSeek: (p) => hostSent?.add(('seek', p)),
          onStatus: (s, o) => statuses.add((s, o)),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  return statuses;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    calls = [];
    installed = true;
    access = true;
    netflix = null;
    _fakeAndroid();
  });

  testWidgets('member: paused and behind -> played and jumped to the room',
      (tester) async {
    netflix = {'playing': false, 'positionMs': 90000, 'canSeek': true};
    final statuses = await _mount(tester,
        isHost: false, roomPlaying: true, roomPosition: 100);
    expect(sent(), containsAll(['play', 'seekTo']));
    final seek = calls.firstWhere((c) => c.method == 'seekTo');
    expect(seek.arguments['positionMs'], 100000);
    expect(statuses.last.$1, 'behind');
    expect(find.textContaining('behind'), findsOneWidget);
  });

  testWidgets('member: within 3 seconds -> left alone, reported in sync',
      (tester) async {
    netflix = {'playing': true, 'positionMs': 101500, 'canSeek': true};
    final statuses = await _mount(tester,
        isHost: false, roomPlaying: true, roomPosition: 100);
    expect(sent(), isEmpty);
    expect(statuses.last.$1, 'in_sync');
    expect(find.text('In sync with the host'), findsOneWidget);
  });

  testWidgets('member: room paused -> their Netflix is paused', (tester) async {
    netflix = {'playing': true, 'positionMs': 100000, 'canSeek': true};
    await _mount(tester, isHost: false, roomPlaying: false, roomPosition: 100);
    expect(sent(), ['pause']);
  });

  testWidgets(
      'member: no seek support -> only play/pause, asks to move by hand',
      (tester) async {
    netflix = {'playing': true, 'positionMs': 40000, 'canSeek': false};
    await _mount(tester, isHost: false, roomPlaying: true, roomPosition: 100);
    expect(sent(), isEmpty);
    expect(find.textContaining('room timer'), findsOneWidget);
  });

  testWidgets('host: their Netflix playing while room is paused -> room plays',
      (tester) async {
    netflix = {'playing': true, 'positionMs': 50000, 'canSeek': true};
    final hostSent = <(String, double)>[];
    await _mount(tester,
        isHost: true, roomPlaying: false, roomPosition: 50, hostSent: hostSent);
    expect(hostSent, [('play', 50.0)]);
    // Never commands its own Netflix from the room — it IS the room.
    expect(sent(), isEmpty);
  });

  testWidgets('host: jumped ahead in Netflix -> room clock moves too',
      (tester) async {
    netflix = {'playing': true, 'positionMs': 300000, 'canSeek': true};
    final hostSent = <(String, double)>[];
    await _mount(tester,
        isHost: true, roomPlaying: true, roomPosition: 120, hostSent: hostSent);
    expect(hostSent, [('seek', 300.0)]);
  });

  testWidgets('host: no repeat while the room catches up', (tester) async {
    netflix = {'playing': true, 'positionMs': 50000, 'canSeek': true};
    final hostSent = <(String, double)>[];
    await _mount(tester,
        isHost: true, roomPlaying: false, roomPosition: 50, hostSent: hostSent);
    await tester.pump(const Duration(milliseconds: 1600)); // next tick
    expect(hostSent.length, 1);
  });

  testWidgets('steps: install, then allow, then open the title',
      (tester) async {
    installed = false;
    final s1 =
        await _mount(tester, isHost: false, roomPlaying: true, roomPosition: 0);
    expect(find.text('Get the Netflix app'), findsOneWidget);
    expect(s1.last.$1, 'no_app');

    installed = true;
    access = false;
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Let Insync play/pause Netflix'), findsOneWidget);

    access = true;
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Open the title in Netflix'), findsOneWidget);
  });

  testWidgets('iPhone: falls back to "press play too"', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _mount(tester, isHost: false, roomPlaying: true, roomPosition: 0);
      expect(find.text('Netflix plays in its own app'), findsOneWidget);
      expect(calls, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('status labels', () {
    expect(
        OttSyncPanelState.statusLabel(
            {'status': 'behind', 'offsetSec': -4}, 'Netflix'),
        '4s behind');
    expect(OttSyncPanelState.statusLabel({'status': 'no_app'}, 'Netflix'),
        'Needs the Netflix app');
  });
}
