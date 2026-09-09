import 'playback_session.dart';
import 'playback_surface.dart';

/// One adapter per playable media source (Media3 for direct/HLS/DASH,
/// a future YouTube-native adapter, an authorized-provider adapter for
/// official OTT handoff). PlaybackSessionManager only ever talks to this
/// interface — it never knows which concrete adapter is behind it.
///
/// `setSurface` is the load-bearing method for spec Step 5's critical
/// rule: it is the ONLY way a surface transition (foreground/PiP/
/// background) reaches the adapter. Nothing in this interface exposes a
/// way for a lifecycle event to call play()/pause() — that separation is
/// enforced by construction, not by convention, because LifecycleCoordinator
/// (the only caller that reacts to OS lifecycle events) only ever calls
/// PlaybackSessionManager's surface methods, which only ever call
/// setSurface() here.
abstract interface class PlaybackAdapter {
  String get providerId;
  PlaybackCapabilities get capabilities;

  Future<void> initialize();
  Future<void> load(String mediaId);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<Duration> position();
  Future<void> setSurface(PlaybackSurface surface);
  Future<PlaybackSession> snapshot();
  Future<void> dispose();
}
