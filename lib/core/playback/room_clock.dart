/// NTP-lite server-clock estimate for one Party (spec Step 6), the same
/// math already implemented ad hoc in RoomSocketController.correctedNowMs
/// (`serverTimeOffsetMs`, synced via a `time:sync` round trip — see
/// room_socket_controller.dart) — this is the shared, reusable form of it
/// that PlaybackSessionManager-based adapters use instead of each
/// reimplementing the offset arithmetic.
class RoomClock {
  int serverOffsetMs;

  RoomClock({this.serverOffsetMs = 0});

  DateTime get serverNow => DateTime.now().toUtc().add(Duration(milliseconds: serverOffsetMs));

  /// expectedPosition = serverPosition + (serverNow - updatedAt) * rate.
  /// Callers apply this as: <0.3s drift -> ignore, 0.3-1.5s -> nudge
  /// playback rate, >=1.5s -> hard seek (already the exact tiering used in
  /// sync_video_player.dart/drive_video_player.dart's _checkDrift methods
  /// — this is the one place that logic should live once the players are
  /// migrated onto PlaybackSessionManager).
  Duration expectedPosition({
    required Duration position,
    required DateTime updatedAt,
    required bool isPlaying,
    double playbackRate = 1,
  }) {
    if (!isPlaying) return position;
    final elapsed = serverNow.difference(updatedAt.toUtc());
    return position + Duration(milliseconds: (elapsed.inMilliseconds * playbackRate).round());
  }
}
