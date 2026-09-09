import '../../../core/playback/playback_session.dart';
import '../../../core/room_source_types.dart';

/// Spec Step 9/88 — metadata describing what to play, never the stream
/// itself. `sourceType` is a plain String matching the backend's
/// `Room.sourceType` ENUM values directly (`youtube`, `drive`, `netflix`,
/// `amazon`, `youtube_surf`, `hotstar`, `aha`, `sunnxt`, `sonyliv`,
/// `airtel_xstream`) rather than a separate Dart enum — the existing
/// `webviewSourceTypes` set (core/room_source_types.dart) already treats
/// this as an open, string-keyed set that grows without a Dart-side enum
/// edit (see that file's own comment); duplicating it as a closed enum
/// here would just create a second place that can drift out of sync with
/// the backend's real ENUM.
class MediaSource {
  final String id;
  final String title;
  final String sourceType;
  final String? url;

  const MediaSource({
    required this.id,
    required this.title,
    required this.sourceType,
    this.url,
  });

  /// Derived from FLING_AUDIT.md §4-5's confirmed, verified-by-code
  /// behavior — not aspirational flags. `drive` is the only sourceType
  /// with a real background-audio handoff today (background_audio_handler
  /// .dart); `youtube`/`drive` are the only two with any playback sync at
  /// all (webview/OTT sourceTypes have none — DRM'd `<video>` elements
  /// expose no state to a WebView, per Room.js's own comment); PiP is
  /// rendering-only and available to any sourceType with a foreground
  /// video surface (i.e. not the audio-only voice/music/karaoke modes).
  PlaybackCapabilities get capabilities {
    if (sourceType == 'drive') {
      return const PlaybackCapabilities(
        foregroundVideo: true,
        backgroundAudio: true,
        pip: true,
        lockScreenControls: true,
        remoteControls: true,
      );
    }
    if (sourceType == 'youtube') {
      return const PlaybackCapabilities(
        foregroundVideo: true,
        backgroundAudio: false,
        pip: true,
        lockScreenControls: false,
        remoteControls: false,
      );
    }
    if (webviewSourceTypes.contains(sourceType)) {
      return const PlaybackCapabilities(
        foregroundVideo: true,
        backgroundAudio: false,
        pip: false,
        lockScreenControls: false,
        remoteControls: false,
      );
    }
    return PlaybackCapabilities.none;
  }
}
