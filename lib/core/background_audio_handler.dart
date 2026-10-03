import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// The actual playback engine behind real background/lock-screen audio for
/// Drive-hosted rooms (see drive_video_player.dart's AppLifecycleState
/// handoff — video_player itself has no background-survival story on
/// Android, this is a separate native media session that does). Wraps
/// just_audio; audio_service mirrors its state onto the Android media
/// notification and lock-screen controls automatically once broadcast via
/// mediaItem/playbackState below.
///
/// Real playback (loadAndPlay/player above) is Drive-only — YouTube's
/// embeddable-player terms require the player stay visible on screen, and
/// OTT DRM streams can't be extracted at all without violating
/// anti-circumvention law, so neither ever gets a real audio source loaded
/// here.
///
/// mirrorExternalPlayback below is a deliberate, knowingly-taken exception
/// for YouTube specifically (product decision, not a technical loophole —
/// see the surrounding conversation): it holds the same real Android
/// foreground service and lock-screen notification this handler already
/// provides for Drive, but WITHOUT loading anything into `player` — the
/// actual audio keeps coming from the existing hidden YouTube WebView (see
/// persistent_room_audio.dart/sync_video_player.dart's embedPlayer.js,
/// which already fights Chromium suspending it on visibility loss); this
/// only needs to keep the *process* alive through Doze/background limits so
/// that WebView is never torn down by the OS in the first place. Reporting
/// `playing: true` through audio_service's own state broadcast is what
/// actually triggers its foreground-service promotion — it doesn't care
/// whether real PCM is flowing through `player` to do that. This
/// intentionally continues playing YouTube audio with the screen off,
/// which is exactly what YouTube's Player API terms ask apps not to do;
/// accepted knowingly, not something to extend to any other source without
/// the same explicit conversation.
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();
  // True while mirrorExternalPlayback owns the broadcast state instead of
  // `player`'s own event stream — guards _broadcastState below from
  // clobbering the mirrored "playing" state with `player`'s own (genuinely
  // idle, since nothing is loaded into it) state the instant something
  // nudges its stream.
  bool _mirroring = false;

  // Set by active_room_holder.dart whenever it's the one currently mirroring
  // — routes a tap on the notification's play/pause/skip controls to the
  // room's real socket commands (rs.play/rs.pause/rs.queueSkip) instead of
  // this handler's own (idle, in mirror mode) `player`. Function fields
  // rather than this file importing ActiveRoomHolder directly, since
  // active_room_holder.dart already imports this file — an import the other
  // way would be circular. Left null (and every call below guarded) outside
  // of mirror mode.
  void Function()? onMirrorPlay;
  void Function()? onMirrorPause;
  void Function()? onMirrorSkip;

  BackgroundAudioHandler() {
    player.playbackEventStream.listen(_broadcastState, onError: (Object e, StackTrace st) {});
  }

  /// Holds the foreground service + lock-screen notification for a YouTube
  /// room's audio, which is actually being produced by the hidden WebView
  /// elsewhere — see the class doc above for why this exists and what it
  /// deliberately does NOT do (load real media into `player`). Safe to call
  /// repeatedly with updated position/isPlaying as the room's own playback
  /// state changes; each call just re-broadcasts state, same as
  /// _broadcastState does for the real player.
  void mirrorExternalPlayback({
    required String title,
    String? artUri,
    required bool isPlaying,
    required Duration position,
  }) {
    _mirroring = true;
    mediaItem.add(MediaItem(
      id: 'youtube-room-mirror',
      title: title,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
    ));
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1],
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: position,
    ));
  }

  /// Releases the foreground service held by mirrorExternalPlayback — call
  /// once the YouTube room is no longer active (paused for good, source
  /// changed, or the room was actually left) rather than leaving a stale
  /// "still playing" notification with nothing really keeping it accurate.
  /// Distinct from stopSource(), which tears down a real Drive handoff —
  /// calling this while a real Drive handoff is active would be wrong, but
  /// the two are never active at once (a room has exactly one source type).
  void stopMirroring() {
    if (!_mirroring) return;
    _mirroring = false;
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  Future<void> loadAndPlay({
    required String url,
    required Map<String, String> headers,
    required Duration initialPosition,
    required String title,
    String? artUri,
  }) async {
    // A real Drive handoff always wins over a stale YouTube mirror — the
    // two are never meant to be simultaneous, but clearing this first
    // means _broadcastState (guarded above) resumes reporting `player`'s
    // own real state right away instead of staying stuck on mirrored state.
    _mirroring = false;
    mediaItem.add(MediaItem(
      id: url,
      title: title,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
    ));
    await player.setAudioSource(
      AudioSource.uri(Uri.parse(url), headers: headers),
      initialPosition: initialPosition,
    );
    await player.play();
  }

  /// Stops and releases the current source without tearing down the whole
  /// handler/notification — used when handing playback back to the video
  /// player in the foreground rather than ending the session outright.
  Future<void> stopSource() => player.stop();

  Duration get position => player.position;
  bool get isPlaying => player.playing;

  @override
  Future<void> play() {
    if (_mirroring) {
      onMirrorPlay?.call();
      return Future.value();
    }
    return player.play();
  }

  @override
  Future<void> pause() {
    if (_mirroring) {
      onMirrorPause?.call();
      return Future.value();
    }
    return player.pause();
  }

  @override
  Future<void> skipToNext() {
    if (_mirroring) {
      onMirrorSkip?.call();
      return Future.value();
    }
    return super.skipToNext();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    _mirroring = false;
    await player.stop();
    return super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    // While mirroring, `player` is genuinely idle (nothing loaded into it —
    // see mirrorExternalPlayback) — its own event stream still fires and
    // would otherwise immediately overwrite the mirrored "playing" state
    // with that idle state.
    if (_mirroring) return;
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }
}

/// Set once in main.dart via AudioService.init before runApp — every room
/// screen shares this one handler/notification rather than each spinning
/// up its own media session.
late final BackgroundAudioHandler backgroundAudioHandler;
