import '../../../core/active_room_holder.dart';
import '../../../core/socket_service.dart';
import '../application/party_session_controller.dart';
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
  PartySession? get current => ActiveRoomHolder.session?.current;

  @override
  Future<PartySession> join(String roomId) async {
    // Reattach instead of rejoining from scratch if this room is already
    // the active one — mirrors party_screen.dart's own initState comment
    // on ActiveRoomHolder (core/active_room_holder.dart).
    final existing = ActiveRoomHolder.session;
    if (existing?.roomId == roomId && existing?.current != null) {
      return existing!.current!;
    }
    // Switching to a genuinely different room (or no active session at all)
    // — tear the old runtime down first. Without this, its socket listeners
    // and Voice/Live controllers were left running in the background forever
    // once ActiveRoomHolder.session below gets overwritten, since nothing
    // else still held a reference to call leave()/dispose() on them.
    if (existing != null) {
      await existing.leave();
      existing.dispose();
    }
    final runtime = PartySessionController(
      socketService: socketService,
      currentUserId: currentUserId,
    );
    final session = await runtime.join(roomId);
    ActiveRoomHolder.setSession(runtime);
    return session;
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
    throw UnimplementedError(
        'changeMode($mode) is not wired to a real mode transition yet — see docs/INSYNC_MIGRATION_MAP.md');
  }

  @override
  Future<void> sendMessage(String text) async {
    ActiveRoomHolder.session?.roomController?.sendMessage(text);
  }

  @override
  Future<void> sendReaction(String reaction) async {
    // No `reaction:send` socket event exists on the backend today (see
    // FLING_AUDIT.md §3's full RoomSocketController event inventory) —
    // faking this as a chat message would silently misrepresent what the
    // backend actually supports.
    throw UnimplementedError(
        'sendReaction: no reaction:send event exists on the backend yet');
  }
}
