import '../../../core/playback/playback_adapter.dart';
import '../../../core/playback/playback_session.dart';
import '../../../core/playback/playback_surface.dart';
import '../../media/domain/media_source.dart';
import '../domain/video_source.dart';
import 'media3_player_adapter.dart';

/// Adapts the existing Media3PlayerAdapter (built and Gradle-compile-
/// verified in a prior session — see git history) to the shared
/// PlaybackAdapter interface (core/playback/playback_adapter.dart), rather
/// than reshaping the native-channel-facing class itself. See
/// INSYNC_MIGRATION_MAP.md's PlaybackSessionManager row for why this is a
/// wrapper and not a second competing implementation: Media3PlayerAdapter
/// already does the real work (native platform-view channel calls,
/// position/duration caching from the event stream) — this class only
/// translates that into the shape PlaybackSessionManager expects.
///
/// One instance is scoped to one MediaSource for its lifetime (constructed
/// after the underlying platform view already exists — see
/// Media3PlayerView's onPlatformViewCreated) rather than being reusable
/// across arbitrary mediaIds; `load()` validates the id matches instead of
/// silently switching sources, since `capabilities` (read once, at
/// construction, from the MediaSource) would otherwise go stale.
///
/// `setSurface`: only PiP is meaningful for a Media3 source today
/// (backgroundAudio for non-Drive sources is handled by a separate
/// background_audio_handler.dart hand-off, not by this adapter itself —
/// see FLING_AUDIT.md §5 and PLAYBACK.md for the planned reconciliation).
/// Setting `foreground`/`pip` here is a no-op beyond bookkeeping, since the
/// native PlayerView surface itself doesn't need reconfiguring for PiP —
/// the *Flutter widget tree* around it changes size/visibility (see
/// party_screen.dart's existing bare-video-Scaffold-on-PiP branch), not
/// the underlying ExoPlayer instance.
class Media3PlaybackAdapter implements PlaybackAdapter {
  final MediaSource source;
  final Media3PlayerAdapter _underlying;

  Media3PlaybackAdapter({required this.source, required Media3PlayerAdapter underlying}) : _underlying = underlying;

  @override
  String get providerId => 'media3';

  @override
  PlaybackCapabilities get capabilities => source.capabilities;

  @override
  Future<void> initialize() async {
    // Already initialized by construction — the underlying
    // Media3PlayerAdapter requires a live platform-view viewId to exist at
    // all, which only happens once Media3PlayerView's AndroidView has
    // already been created (see that widget's onPlatformViewCreated).
    // There is no meaningful "initialize" step left to do here.
  }

  @override
  Future<void> load(String mediaId) async {
    if (mediaId != source.id) {
      throw StateError('Media3PlaybackAdapter is scoped to ${source.id}, got load($mediaId) — construct a new adapter per media item instead of reusing this one.');
    }
    final url = source.url;
    if (url == null) {
      throw StateError('MediaSource ${source.id} has no url to load');
    }
    await _underlying.initialize(VideoSource(
      url: url,
      type: _sourceTypeFor(source.sourceType),
    ));
  }

  @override
  Future<void> play() => _underlying.play();

  @override
  Future<void> pause() => _underlying.pause();

  @override
  Future<void> seek(Duration position) => _underlying.seek(position);

  @override
  Future<Duration> position() async => _underlying.position;

  @override
  Future<void> setSurface(PlaybackSurface surface) async {
    // No-op beyond the surface being tracked by PlaybackSessionManager
    // itself — see this class's own doc comment above for why nothing
    // native needs to change here for a Media3-backed source.
  }

  @override
  Future<PlaybackSession> snapshot() async {
    final duration = _underlying.duration;
    return PlaybackSession(
      mediaId: source.id,
      status: _statusFrom(_underlying.isPlaying),
      position: _underlying.position,
      duration: duration,
      updatedAt: DateTime.now().toUtc(),
      playbackRate: 1,
      surface: PlaybackSurface.foreground,
    );
  }

  @override
  Future<void> dispose() => _underlying.dispose();

  static PlaybackStatus _statusFrom(bool isPlaying) => isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused;

  static VideoSourceType _sourceTypeFor(String sourceType) {
    switch (sourceType) {
      case 'hls':
        return VideoSourceType.hls;
      case 'dash':
        return VideoSourceType.dash;
      default:
        return VideoSourceType.direct;
    }
  }
}
