import 'package:flutter/foundation.dart';

import '../screens/party/live_broadcast_controller.dart';
import '../screens/party/room_socket_controller.dart';
import '../screens/party/voice_chat_controller.dart';
import '../features/party/application/party_session_controller.dart';
import 'background_audio_handler.dart';
import 'room_presence_service.dart';

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
  }

  /// Real teardown — only call this from an explicit "Leave Room" action,
  /// never from a plain screen pop (that's a minimize, not a leave).
  static void leave() {
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
    // with nothing left to reattach it to.
    backgroundAudioHandler.stopSource();
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
