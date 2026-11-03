import 'package:flutter_test/flutter_test.dart';
import 'package:insync/core/ott_remote.dart';
import 'package:insync/screens/party/ott_sync_engine.dart';

/// A player the engine drives, recording what it was told to do.
class _FakePlayer implements OttTarget {
  OttPlayerState? now;
  final told = <String>[];
  _FakePlayer(this.now);

  @override
  Future<OttPlayerState?> state() async => now;
  @override
  Future<void> play() async => told.add('play');
  @override
  Future<void> pause() async => told.add('pause');
  @override
  Future<void> seekTo(double seconds) async =>
      told.add('seek ${seconds.round()}');
}

OttPlayerState _at(double pos, {bool playing = true, bool ad = false}) =>
    OttPlayerState(playing: playing, positionSec: pos, canSeek: true, inAd: ad);

void main() {
  late List<String> room;
  OttSyncEngine engine(_FakePlayer p,
          {required bool host, double roomPos = 600, bool playing = true}) =>
      OttSyncEngine(
        target: p,
        isHost: () => host,
        roomPlaying: () => playing,
        hasRoomState: () => true,
        roomPosition: () => roomPos,
        onPlay: (s) => room.add('play ${s.round()}'),
        onPause: (s) => room.add('pause ${s.round()}'),
        onSeek: (s) => room.add('seek ${s.round()}'),
      );

  setUp(() => room = []);

  test('a host coming back lines up with the room instead of restarting it',
      () async {
    final p = _FakePlayer(_at(0.5));
    await engine(p, host: true).tick();
    expect(p.told, contains('seek 600'));
    expect(room, isEmpty, reason: 'the room must not be dragged to 0');
  });

  test('a host who really jumps still moves the room', () async {
    final p = _FakePlayer(_at(900));
    await engine(p, host: true).tick();
    expect(room, ['seek 900']);
  });

  test('an ad moves nobody, on either side', () async {
    final host = _FakePlayer(_at(12, ad: true));
    expect(await engine(host, host: true).tick(), 'ad');
    expect(room, isEmpty);
    final viewer = _FakePlayer(_at(3, ad: true));
    expect(await engine(viewer, host: false).tick(), 'ad');
    expect(viewer.told, isEmpty);
  });

  test('after the ad, a viewer catches up with the room', () async {
    final viewer = _FakePlayer(_at(300));
    await engine(viewer, host: false).tick();
    expect(viewer.told, contains('seek 600'));
  });
}
