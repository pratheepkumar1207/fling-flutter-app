import 'package:flutter/foundation.dart';

import '../../../core/api_client.dart';
import '../../../core/playback/playback_session.dart';
import '../../../core/playback/playback_surface.dart';
import '../../../core/room_presence_service.dart';
import '../../../core/socket_service.dart';
import '../../../screens/party/live_broadcast_controller.dart';
import '../../../screens/party/room_socket_controller.dart';
import '../../../screens/party/voice_chat_controller.dart';
import '../domain/party_session.dart';

/// Persistent runtime owner for one Party. Widgets may mount and unmount,
/// but this controller owns the room socket, voice/live sessions and presence
/// until [leave] is explicitly called. It is the bridge between the existing
/// typed Socket.IO controller and the new immutable [PartySession] contract.
class PartySessionController extends ChangeNotifier {
  PartySessionController({
    required this.socketService,
    required this.currentUserId,
  });

  final SocketService socketService;
  final String? Function() currentUserId;

  String? _roomId;
  Map<String, dynamic>? _room;
  RoomSocketController? _roomController;
  VoiceChatController? _voice;
  LiveBroadcastController? _live;
  PartySession? _session;

  String? get roomId => _roomId;
  Map<String, dynamic>? get room => _room;
  RoomSocketController? get roomController => _roomController;
  VoiceChatController? get voice => _voice;
  LiveBroadcastController? get live => _live;
  PartySession? get current => _session;

  Future<PartySession> join(String roomId) async {
    if (_roomId == roomId && _roomController != null && _session != null) {
      return _session!;
    }

    await leave();
    final room = await ApiClient.get('/rooms/$roomId') as Map<String, dynamic>;
    final controller = RoomSocketController(
      socket: socketService.socket,
      roomId: roomId,
      myUserId: currentUserId(),
    );
    controller.addListener(_onRoomStateChanged);

    _roomId = roomId;
    _room = room;
    _roomController = controller;
    // The existing room UI creates this lazily. Keeping it in the persistent
    // session instead prevents a route change from creating a second engine.
    _voice = VoiceChatController(roomId: roomId);
    await RoomPresenceService.start((room['title'] as String?) ?? 'Party');
    _publishSnapshot();
    return _session!;
  }

  /// Refreshes mutable room metadata after a server-authorized settings or
  /// source change. The socket remains untouched: this is metadata refresh,
  /// not a second join or a second playback authority.
  Future<void> refreshRoom() async {
    final roomId = _roomId;
    if (roomId == null) return;
    _room = await ApiClient.get('/rooms/$roomId') as Map<String, dynamic>;
    _publishSnapshot();
  }

  /// Live needs the resolved room type and current host identity, both of
  /// which are owned by this runtime. Calling it repeatedly is safe.
  void ensureLive() {
    final roomId = _roomId;
    final room = _room;
    final controller = _roomController;
    if (roomId == null || room == null || controller == null) return;
    if (room['roomType'] != 'live' || _live != null) return;
    _live = LiveBroadcastController(roomId: roomId, isHost: controller.isHost);
    _publishSnapshot();
  }

  Future<void> leave() async {
    final controller = _roomController;
    if (controller != null) {
      controller.removeListener(_onRoomStateChanged);
      controller.leave();
      controller.dispose();
    }
    _voice?.dispose();
    _live?.dispose();
    _roomId = null;
    _room = null;
    _roomController = null;
    _voice = null;
    _live = null;
    _session = null;
    RoomPresenceService.stop();
    notifyListeners();
  }

  void _onRoomStateChanged() => _publishSnapshot();

  void _publishSnapshot() {
    final roomId = _roomId;
    final controller = _roomController;
    if (roomId == null || controller == null) return;
    final playbackMap = controller.playback;
    final updatedAt = playbackMap?['updatedAt'];
    final queueVersion = controller.queue['version'];
    _session = PartySession(
      roomId: roomId,
      sessionId: roomId,
      hostId: controller.hostId ?? '',
      mode: _modeForRoom(_room?['roomType'] as String?),
      members: controller.roster
          .map((member) => PartyMember(
                userId: member.userId,
                role: member.isHost ? PartyRole.host : PartyRole.member,
              ))
          .toList(growable: false),
      playback: playbackMap == null
          ? null
          : PlaybackSession(
              status: playbackMap['isPlaying'] == true
                  ? PlaybackStatus.playing
                  : PlaybackStatus.paused,
              position: Duration(
                milliseconds: ((playbackMap['position'] as num?) ?? 0).round(),
              ),
              updatedAt: updatedAt is num
                  ? DateTime.fromMillisecondsSinceEpoch(updatedAt.toInt(),
                      isUtc: true)
                  : DateTime.now().toUtc(),
              playbackRate: 1,
              surface: PlaybackSurface.foreground,
            ),
      queueVersion: queueVersion is num ? queueVersion.toInt() : 0,
      connected: socketService.isConnected,
    );
    notifyListeners();
  }

  PartyMode _modeForRoom(String? roomType) => switch (roomType) {
        'voice' => PartyMode.voice,
        'game' => PartyMode.game,
        'live' => PartyMode.live,
        'music' => PartyMode.music,
        'karaoke' => PartyMode.karaoke,
        _ => PartyMode.watch,
      };

  @override
  void dispose() {
    _roomController?.removeListener(_onRoomStateChanged);
    _roomController?.dispose();
    _voice?.dispose();
    _live?.dispose();
    super.dispose();
  }
}
