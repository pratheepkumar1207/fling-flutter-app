import 'playback_state.dart';
import 'video_source.dart';

/// Spec section 14 — every concrete player (Media3Adapter for direct/HLS/
/// DASH, a YouTube adapter, an authorized-provider adapter) implements
/// this same shape so PlayerController/SyncEngine never need to know which
/// one they're driving.
abstract class VideoPlayerAdapter {
  Future<void> initialize(VideoSource source);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setPlaybackRate(double rate);

  Future<void> dispose();

  Duration get position;

  Duration? get duration;

  bool get isPlaying;

  Stream<PlaybackStateSnapshot> get playbackState;
}
