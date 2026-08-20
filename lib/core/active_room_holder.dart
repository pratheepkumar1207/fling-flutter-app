import 'package:flutter/foundation.dart';

import '../screens/party/live_broadcast_controller.dart';
import '../screens/party/room_socket_controller.dart';
import '../screens/party/voice_chat_controller.dart';
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

  /// Real teardown — only call this from an explicit "Leave Room" action,
  /// never from a plain screen pop (that's a minimize, not a leave).
  static void leave() {
    controller?.leave();
    controller?.dispose();
    voice?.dispose();
    live?.dispose();
    RoomPresenceService.stop();
    roomId = null;
    roomTitle = null;
    controller = null;
    room = null;
    voice = null;
    live = null;
    activeLabel.value = null;
  }
}
