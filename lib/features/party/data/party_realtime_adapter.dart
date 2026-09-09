/// Spec Step 4 — a generic realtime facade behind which the existing
/// Socket.IO implementation sits. See SocketPartyRealtimeAdapter (this
/// directory) for the concrete implementation, and
/// INSYNC_MIGRATION_MAP.md's PartyRealtimeAdapter row for why this is a
/// secondary generic-access facade alongside RoomSocketController's typed
/// methods, not a replacement for them: `emit`/`events` here are for
/// generic/cross-cutting consumers (logging, a future generic event bus),
/// while every real UI call site keeps using RoomSocketController's typed
/// `play()`/`queueAdd()`/`voteSkip()`/etc. directly.
abstract interface class PartyRealtimeAdapter {
  Future<void> connect(String roomId);
  Future<void> reconnect(String roomId);
  Future<void> disconnect(String roomId);

  Stream<Map<String, dynamic>> events(String roomId);

  void emit(String event, Map<String, dynamic> payload);
}
