import 'party_session.dart';

/// Spec Step 3 — the interface PartyScreen/future mode-specific screens
/// depend on, instead of reaching into ActiveRoomHolder's static fields
/// directly. See PartyEngineImpl (features/party/data/party_engine_impl.dart)
/// for the concrete implementation wrapping the real join/leave/socket flow.
abstract interface class PartyEngine {
  PartySession? get current;

  Future<PartySession> join(String roomId);
  Future<void> leave();
  Future<void> changeMode(PartyMode mode);
  Future<void> sendMessage(String text);
  Future<void> sendReaction(String reaction);
}
