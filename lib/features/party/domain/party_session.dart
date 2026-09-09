import '../../../core/playback/playback_session.dart';

/// Spec Step 3 — the one thing missing from the existing ActiveRoomHolder
/// (core/active_room_holder.dart, see FLING_AUDIT.md §3): an explicit,
/// first-class mode. Today mode is implicit in which controller
/// (RoomSocketController/VoiceChatController/LiveBroadcastController) is
/// non-null; this makes it a real field so "changing mode" can become one
/// well-defined operation instead of ad hoc controller swapping.
enum PartyMode { watch, voice, music, karaoke, game, live }

/// Mirrors RoomSocketController's roster roles 1:1 (see
/// room_socket_controller.dart's `isHost`/host-gated methods and the
/// backend's makeHost/kick handlers) plus the two roles that exist only in
/// voice mode (speaker/listener aren't tracked as PartyRole values today —
/// VoiceChatController manages those separately; `speaker` here is a
/// placeholder for when that gets unified, not yet wired to anything).
enum PartyRole { host, coHost, moderator, speaker, member }

class PartyMember {
  final String userId;
  final PartyRole role;
  final bool connected;

  const PartyMember({
    required this.userId,
    this.role = PartyRole.member,
    this.connected = true,
  });
}

/// Immutable snapshot of a Party at a point in time — produced on demand
/// from ActiveRoomHolder + RoomSocketController's live state by
/// PartyEngineImpl (features/party/data/party_engine_impl.dart), not a
/// replacement for either. See INSYNC_MIGRATION_MAP.md's PartySession row
/// for why this wraps rather than replaces the existing static holder.
class PartySession {
  final String roomId;
  final String sessionId;
  final String hostId;
  final PartyMode mode;
  final List<PartyMember> members;
  final PlaybackSession? playback;
  final int queueVersion;
  final bool connected;

  const PartySession({
    required this.roomId,
    required this.sessionId,
    required this.hostId,
    required this.mode,
    this.members = const [],
    this.playback,
    this.queueVersion = 0,
    this.connected = false,
  });

  bool isHost(String userId) => userId == hostId;
}
