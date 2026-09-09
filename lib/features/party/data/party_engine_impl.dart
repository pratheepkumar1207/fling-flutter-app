import '../../../core/active_room_holder.dart';
import '../../../core/api_client.dart';
import '../../../core/playback/playback_session.dart';
import '../../../core/playback/playback_surface.dart';
import '../../../core/room_presence_service.dart';
import '../../../core/socket_service.dart';
import '../../../screens/party/room_socket_controller.dart';
import '../domain/party_engine.dart';
import '../domain/party_session.dart';

/// Concrete PartyEngine wrapping the real join/leave/socket flow — see
/// INSYNC_MIGRATION_MAP.md's PartySession row for why this wraps
/// ActiveRoomHolder + RoomSocketController rather than replacing them.
/// `join`/`leave` here do exactly what party_screen.dart's `_initSocket`/
/// `ActiveRoomHolder.leave()` already do; this class exists so future
/// screens can depend on the PartyEngine interface instead of reaching
/// into ActiveRoomHolder's static fields and Provider-scoped services
/// directly the way PartyScreen itself still does.
class PartyEngineImpl implements PartyEngine {
  final SocketService socketService;
  final String? Function() currentUserId;

  PartyEngineImpl({required this.socketService, required this.currentUserId});

  @override
  PartySession? get current {
    final controller = ActiveRoomHolder.controller;
    final roomId = ActiveRoomHolder.roomId;
    if (controller == null || roomId == null) return null;
    return _snapshotFrom(roomId, controller);
  }

  @override
  Future<PartySession> join(String roomId) async {
    // Reattach instead of rejoining from scratch if this room is already
    // the active one — mirrors party_screen.dart's own initState comment
    // on ActiveRoomHolder (core/active_room_holder.dart).
    final existing = ActiveRoomHolder.controller;
    if (ActiveRoomHolder.roomId == roomId && existing != null) {
      return _snapshotFrom(roomId, existing);
    }

    final room = await ApiClient.get('/rooms/$roomId') as Map<String, dynamic>;
    final controller = RoomSocketController(
      socket: socketService.socket,
      roomId: roomId,
      myUserId: currentUserId(),
    );
    await RoomPresenceService.start((room['title'] as String?) ?? 'Party');
    ActiveRoomHolder.set(roomId: roomId, controller: controller, room: room);
    return _snapshotFrom(roomId, controller);
  }

  @override
  Future<void> leave() async {
    ActiveRoomHolder.leave();
  }

  @override
  Future<void> changeMode(PartyMode mode) async {
    // Mode is still implicit today (which of RoomSocketController/
    // VoiceChatController/LiveBroadcastController is attached — see
    // FLING_AUDIT.md §3), not a single explicit state machine. Recording
    // the interface now and wiring a real transition is scoped as
    // follow-up work in INSYNC_MIGRATION_MAP.md, not silently faked here.
    throw UnimplementedError('changeMode($mode) is not wired to a real mode transition yet — see docs/INSYNC_MIGRATION_MAP.md');
  }

  @override
  Future<void> sendMessage(String text) async {
    ActiveRoomHolder.controller?.sendMessage(text);
  }

  @override
  Future<void> sendReaction(String reaction) async {
    // No `reaction:send` socket event exists on the backend today (see
    // FLING_AUDIT.md §3's full RoomSocketController event inventory) —
    // faking this as a chat message would silently misrepresent what the
    // backend actually supports.
    throw UnimplementedError('sendReaction: no reaction:send event exists on the backend yet');
  }

  PartySession _snapshotFrom(String roomId, RoomSocketController controller) {
    final playbackMap = controller.playback;
    PlaybackSession? playback;
    if (playbackMap != null) {
      final updatedAtMs = playbackMap['updatedAt'] as num?;
      playback = PlaybackSession(
        status: (playbackMap['isPlaying'] as bool? ?? false) ? PlaybackStatus.playing : PlaybackStatus.paused,
        position: Duration(milliseconds: (playbackMap['position'] as num? ?? 0).round()),
        updatedAt: updatedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs.toInt(), isUtc: true) : DateTime.now().toUtc(),
        playbackRate: 1,
        surface: PlaybackSurface.foreground,
      );
    }

    return PartySession(
      roomId: roomId,
      // The backend has no separate per-join session concept today (a
      // reconnect rejoins the same roomId, not a new session id) — using
      // roomId here is a real simplification, not a stand-in for data that
      // exists elsewhere.
      sessionId: roomId,
      hostId: controller.hostId ?? '',
      // Always `watch` until changeMode() is actually wired (see above) —
      // this snapshot doesn't yet know about an attached VoiceChatController
      // /LiveBroadcastController the way ActiveRoomHolder itself does.
      mode: PartyMode.watch,
      members: controller.roster
          .map((r) => PartyMember(userId: r.userId, role: r.isHost ? PartyRole.host : PartyRole.member))
          .toList(),
      playback: playback,
      queueVersion: 0,
      connected: socketService.isConnected,
    );
  }
}
