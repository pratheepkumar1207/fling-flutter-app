import '../../core/ott_remote.dart';

/// Something with a Netflix/Prime player in it that a room can drive:
/// the platform's own app (through Android's media controls) or its web
/// player inside the room's WebView.
abstract class OttTarget {
  /// null while nothing is playing that we can see.
  Future<OttPlayerState?> state();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(double seconds);
}

/// The Netflix/Prime Video app, via core/ott_remote.dart.
class OttAppTarget implements OttTarget {
  final String package;
  OttAppTarget(this.package);

  @override
  Future<OttPlayerState?> state() => OttRemote.state(package);
  @override
  Future<void> play() => OttRemote.play(package);
  @override
  Future<void> pause() => OttRemote.pause(package);
  @override
  Future<void> seekTo(double seconds) => OttRemote.seekTo(package, seconds);
}

/// The one set of watch-party sync rules, shared by the in-room web player
/// and the platform app:
///  - Host: their player is the source of truth. A play/pause/jump there is
///    sent to the room; the room's own controls drive their player through
///    [hostCommand] (so it isn't reported back as a change).
///  - Everyone else: played/paused to match the room, and jumped back in
///    line when more than [tolerance] seconds off.
/// Call [tick] every second or two.
class OttSyncEngine {
  static const tolerance = 3.0;
  // After telling a player to do something, give it this long to happen
  // before judging it again — otherwise a slow player gets told twice.
  static const grace = Duration(milliseconds: 2500);

  OttTarget target;
  final bool Function() isHost;
  final bool Function() roomPlaying;
  final bool Function() hasRoomState;
  final double Function() roomPosition;
  final void Function(double) onPlay;
  final void Function(double) onPause;
  final void Function(double)? onSeek;

  OttSyncEngine({
    required this.target,
    required this.isHost,
    required this.roomPlaying,
    required this.hasRoomState,
    required this.roomPosition,
    required this.onPlay,
    required this.onPause,
    this.onSeek,
  });

  OttPlayerState? local;
  double offset = 0;
  DateTime _lastCommand = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _settling => DateTime.now().difference(_lastCommand) < grace;

  /// One sync pass. Returns the status to report ('in_sync', 'behind',
  /// 'ahead', or 'not_playing' while the player isn't showing anything).
  Future<String> tick() async {
    final now = await target.state();
    local = now;
    if (now == null) return 'not_playing';

    final roomPos = roomPosition();
    if (isHost()) {
      if (!_settling) {
        if (!hasRoomState() || now.playing != roomPlaying()) {
          now.playing ? onPlay(now.positionSec) : onPause(now.positionSec);
          _lastCommand = DateTime.now();
        } else if ((now.positionSec - roomPos).abs() > tolerance) {
          // Jumped around in the player: move the room's clock with it.
          now.playing
              ? (onSeek ?? onPlay)(now.positionSec)
              : onPause(now.positionSec);
          _lastCommand = DateTime.now();
        }
      }
      offset = 0;
      return 'in_sync';
    }

    if (!hasRoomState()) return 'in_sync';
    offset = now.positionSec - roomPos;
    if (!_settling) {
      if (now.playing != roomPlaying()) {
        roomPlaying() ? await target.play() : await target.pause();
        _lastCommand = DateTime.now();
      }
      if (offset.abs() > tolerance && now.canSeek) {
        await target.seekTo(roomPos);
        _lastCommand = DateTime.now();
      }
    }
    if (offset.abs() <= tolerance) return 'in_sync';
    return offset < 0 ? 'behind' : 'ahead';
  }

  /// The host used the room's own controls: do the same to their player.
  Future<void> hostCommand({required bool playing, double? seekTo}) async {
    _lastCommand = DateTime.now();
    if (seekTo != null && (local?.canSeek ?? false)) {
      await target.seekTo(seekTo);
    }
    playing ? await target.play() : await target.pause();
    _lastCommand = DateTime.now();
  }
}
