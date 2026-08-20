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
/// Deliberately not used for YouTube or DRM'd OTT platforms — see the
/// surrounding conversation for why: YouTube's embeddable-player terms
/// require it stay visible on screen, and OTT DRM streams can't be
/// extracted at all without violating anti-circumvention law. This handler
/// only ever plays this app's own Drive-hosted media.
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  BackgroundAudioHandler() {
    player.playbackEventStream.listen(_broadcastState, onError: (Object e, StackTrace st) {});
  }

  Future<void> loadAndPlay({
    required String url,
    required Map<String, String> headers,
    required Duration initialPosition,
    required String title,
    String? artUri,
  }) async {
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
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
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
