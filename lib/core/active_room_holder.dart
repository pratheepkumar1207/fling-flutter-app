import 'package:flutter/foundation.dart';

import '../screens/party/live_broadcast_controller.dart';
import '../screens/party/room_socket_controller.dart';
import '../screens/party/voice_chat_controller.dart';
import '../features/party/application/party_session_controller.dart';
import 'background_audio_handler.dart';
import 'room_presence_service.dart';
import 'room_source_types.dart';

/// Keeps a room's live connection (socket, roster, chat, playback state)
/// alive across in-app navigation, so switching to Home/Feed/Discover/
/// Messages doesn't drop you from the room or stop what's playing — only
/// an explicit "Leave Room" does that. See party_screen.dart's initState
/// (reattaches to an existing entry here instead of rejoining from
/// scratch) and dispose (only tears this down when _didLeaveRoom is true).
///
/// Deliberately a bare static holder, not a Provider/ChangeNotifier — the
/// room screen is the only UI that reads these controllers directly today;
/// AppShell's mini-bar (see app_shell.dart) only needs to know *whether*
/// a room is active, via [hasActive]/[roomIdNotifier].
class ActiveRoomHolder {
  /// The persistent Party owner. Legacy fields below are retained as
  /// read-compatible views while existing widgets migrate, but new code must
  /// create and tear down rooms through this runtime only.
  static PartySessionController? session;
  static String? roomId;
  static String? roomTitle;
  static RoomSocketController? controller;
  static VoiceChatController? voice;
  static LiveBroadcastController? live;
  static Map<String, dynamic>? room;

  static bool get hasActive => controller != null;

  /// AppShell's mini-bar listens to this instead of the bare fields above,
  /// since a static class has no ChangeNotifier of its own — this is the
  /// only thing that tells the mini-bar to show/hide/relabel itself.
  /// Value is the active room's title (or roomId as fallback), null when
  /// no room is active.
  static final ValueNotifier<String?> activeLabel = ValueNotifier(null);

  /// True while PartyScreen for the active room is the current on-screen
  /// route — set in its initState, cleared in its dispose (mirrors how
  /// RoomPresenceService.start/stop already bracket PartyScreen's own
  /// lifecycle). persistent_room_audio.dart reads this to know whether it's
  /// safe to mount its own hidden player: only when the docked one *isn't*
  /// showing, so the two never both produce audio at once.
  static final ValueNotifier<bool> isRoomScreenVisible = ValueNotifier(false);

  // The controller currently wired to _syncBackgroundMirror, so a repeat
  // set()/setSession()/refreshSessionReferences() call with the same
  // instance (the common case — a room's RoomSocketController doesn't
  // change until it's actually rejoined) doesn't detach and reattach the
  // listener for no reason.
  static RoomSocketController? _mirroredController;

  static void _attachMirrorListener(RoomSocketController newController) {
    if (identical(_mirroredController, newController)) return;
    _mirroredController?.removeListener(_syncBackgroundMirror);
    newController.addListener(_syncBackgroundMirror);
    _mirroredController = newController;
    // Reads `controller` fresh on every tap rather than closing over
    // newController directly — these three stay set for as long as this
    // class exists, so they must keep working correctly across whatever
    // RoomSocketController is active *at tap time*, not just the one active
    // when they were first assigned. isHost is already enforced inside
    // play/pause/queueSkip themselves (same as every other caller of
    // these), so a non-host's phone showing this notification is a safe,
    // silent no-op here, not a special case to handle.
    backgroundAudioHandler.onMirrorPlay =
        () => controller?.play(_currentElapsedSeconds());
    backgroundAudioHandler.onMirrorPause =
        () => controller?.pause(_currentElapsedSeconds());
    backgroundAudioHandler.onMirrorSkip = () => controller?.queueSkip();
    _syncBackgroundMirror();
  }

  static double _currentElapsedSeconds() {
    final playback = controller?.playback;
    var position = ((playback?['position'] as num?) ?? 0).toDouble();
    final updatedAt = playback?['updatedAt'] as num?;
    if (playback?['isPlaying'] == true && updatedAt != null) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch - updatedAt) / 1000;
      if (elapsed > 0) position += elapsed;
    }
    return position;
  }

  // Keeps BackgroundAudioHandler's YouTube-mirror (see its own doc comment)
  // in step with the room's actual current source/playback state, from
  // whichever RoomSocketController is currently active — regardless of
  // whether PartyScreen or persistent_room_audio.dart's hidden instance
  // happens to be the one on screen right now, since either way this is
  // the one thing both ultimately share.
  static void _syncBackgroundMirror() {
    final rs = controller;
    final currentRoom = room;
    if (rs == null || currentRoom == null) {
      backgroundAudioHandler.stopMirroring();
      return;
    }
    final items = (rs.queue['items'] as List?) ?? const [];
    final currentIndex = rs.queue['currentIndex'] as int? ?? 0;
    final currentItem = (items.isNotEmpty && currentIndex < items.length)
        ? Map<String, dynamic>.from(items[currentIndex] as Map)
        : null;
    final sourceType = currentItem?['sourceType'] as String? ??
        currentRoom['sourceType'] as String?;
    // Same "goes through SyncVideoPlayer" test persistent_room_audio.dart
    // uses — Drive gets its own real background session (see
    // drive_video_player.dart), OTT/DRM sources have no audio-only story at
    // all, so YouTube is what's actually left once both are excluded.
    final isYoutubePath =
        sourceType != null && sourceType != 'drive' && !webviewSourceTypes.contains(sourceType);
    final playback = rs.playback;
    final isPlaying = playback?['isPlaying'] == true;
    if (!isYoutubePath || !isPlaying) {
      backgroundAudioHandler.stopMirroring();
      return;
    }
    backgroundAudioHandler.mirrorExternalPlayback(
      title: currentItem?['title'] as String? ??
          currentRoom['title'] as String? ??
          'Playing in Insync',
      artUri: currentItem?['thumbnail'] as String? ??
          currentRoom['videoThumbnail'] as String?,
      isPlaying: true,
      position:
          Duration(milliseconds: (_currentElapsedSeconds() * 1000).round()),
    );
  }

  /// Called once a fresh join has actually succeeded — see
  /// party_screen.dart's _initSocket.
  static void set({
    required String roomId,
    required RoomSocketController controller,
    required Map<String, dynamic> room,
    VoiceChatController? voice,
    LiveBroadcastController? live,
  }) {
    ActiveRoomHolder.roomId = roomId;
    ActiveRoomHolder.roomTitle = room['title'] as String?;
    ActiveRoomHolder.controller = controller;
    ActiveRoomHolder.room = room;
    ActiveRoomHolder.voice = voice;
    ActiveRoomHolder.live = live;
    activeLabel.value = ActiveRoomHolder.roomTitle ?? roomId;
    _attachMirrorListener(controller);
  }

  /// Installs a fully joined PartySession runtime. This is now the only
  /// creation path used by PartyEngine/PartyScreen.
  static void setSession(PartySessionController runtime) {
    session = runtime;
    final joinedRoomId = runtime.roomId;
    final joinedController = runtime.roomController;
    final joinedRoom = runtime.room;
    if (joinedRoomId == null ||
        joinedController == null ||
        joinedRoom == null) {
      return;
    }
    roomId = joinedRoomId;
    roomTitle = joinedRoom['title'] as String?;
    controller = joinedController;
    room = joinedRoom;
    voice = runtime.voice;
    live = runtime.live;
    activeLabel.value = roomTitle ?? joinedRoomId;
    _attachMirrorListener(joinedController);
  }

  /// Refreshes legacy compatibility references after the session creates an
  /// optional controller (for example the live broadcaster).
  static void refreshSessionReferences() {
    final runtime = session;
    if (runtime == null) return;
    controller = runtime.roomController;
    room = runtime.room;
    voice = runtime.voice;
    live = runtime.live;
    final rs = runtime.roomController;
    if (rs != null) _attachMirrorListener(rs);
  }

  /// Real teardown — only call this from an explicit "Leave Room" action,
  /// never from a plain screen pop (that's a minimize, not a leave).
  static void leave() {
    _mirroredController?.removeListener(_syncBackgroundMirror);
    _mirroredController = null;
    final runtime = session;
    session = null;
    if (runtime != null) {
      runtime.leave();
      runtime.dispose();
    } else {
      controller?.leave();
      controller?.dispose();
      voice?.dispose();
      live?.dispose();
      RoomPresenceService.stop();
    }
    // A real leave, not a minimize — stop any Drive audio that a room
    // screen's own dispose() may have just handed off to the background
    // session (see drive_video_player.dart), or it'd keep playing forever
    // with nothing left to reattach it to. Same for a YouTube mirror (see
    // BackgroundAudioHandler.mirrorExternalPlayback) — either way, nothing
    // should still claim to be "playing" once the room is genuinely gone.
    backgroundAudioHandler.stopSource();
    backgroundAudioHandler.stopMirroring();
    roomId = null;
    roomTitle = null;
    controller = null;
    room = null;
    voice = null;
    live = null;
    activeLabel.value = null;
    isRoomScreenVisible.value = false;
  }
}
