import 'playback_surface.dart';

/// A player's own local lifecycle state — distinct from the shared Party
/// playback state (PLAYING/PAUSED) tracked by RoomSocketController.playback.
/// The two can legitimately diverge for a moment: this viewer can be
/// `buffering` while the Party itself is `playing`.
enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  buffering,
  recovering,
  completed,
  error,
}

/// What a given media source/adapter combination actually supports —
/// mirrors the `backgroundAudio`/`pip`/`foregroundVideo` flags already on
/// MediaSource (see features/media/domain/media_source.dart), plus the two
/// the audit found nothing currently models: lock-screen and remote
/// (headset/Bluetooth) controls. Read by PlaybackSessionManager before
/// attempting a surface change — e.g. enterBackground() is a no-op if
/// backgroundAudio is false, exactly the DRM/YouTube ToS constraint
/// documented in FLING_AUDIT.md.
class PlaybackCapabilities {
  final bool foregroundVideo;
  final bool backgroundAudio;
  final bool pip;
  final bool lockScreenControls;
  final bool remoteControls;

  const PlaybackCapabilities({
    required this.foregroundVideo,
    required this.backgroundAudio,
    required this.pip,
    required this.lockScreenControls,
    required this.remoteControls,
  });

  static const none = PlaybackCapabilities(
    foregroundVideo: false,
    backgroundAudio: false,
    pip: false,
    lockScreenControls: false,
    remoteControls: false,
  );
}

/// Immutable snapshot of one PlaybackSession at a point in time.
/// `expectedPosition` is the same drift formula RoomClock uses for the
/// shared Party position (spec Step 6) — duplicated intentionally: this one
/// projects *this adapter's own* last-known position forward (useful the
/// instant before a fresh snapshot arrives), while RoomClock projects the
/// *authoritative server* position. They will usually agree; when they
/// don't, the server one wins (see PlaybackSessionManager).
class PlaybackSession {
  final String? mediaId;
  final PlaybackStatus status;
  final Duration position;
  final Duration? duration;
  final DateTime updatedAt;
  final double playbackRate;
  final PlaybackSurface surface;

  const PlaybackSession({
    this.mediaId,
    required this.status,
    required this.position,
    this.duration,
    required this.updatedAt,
    required this.playbackRate,
    required this.surface,
  });

  factory PlaybackSession.idle() => PlaybackSession(
        status: PlaybackStatus.idle,
        position: Duration.zero,
        updatedAt: DateTime.now().toUtc(),
        playbackRate: 1,
        surface: PlaybackSurface.foreground,
      );

  bool get isPlaying => status == PlaybackStatus.playing;

  Duration expectedPosition(DateTime serverNow) {
    if (!isPlaying) return position;
    final elapsed = serverNow.difference(updatedAt);
    return position + Duration(milliseconds: (elapsed.inMilliseconds * playbackRate).round());
  }
}
