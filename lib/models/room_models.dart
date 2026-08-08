/// Room list-card shape, as returned by GET /rooms/browse and similar.
class RoomSummary {
  final String id;
  final String title;
  final String? hostId;
  final String? hostName;
  final int memberCount;
  final bool isInvited;

  RoomSummary({
    required this.id,
    required this.title,
    this.hostId,
    this.hostName,
    this.memberCount = 0,
    this.isInvited = false,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    final room = json['room'] is Map ? json['room'] as Map<String, dynamic> : json;
    return RoomSummary(
      id: room['id'] as String,
      title: room['title'] as String? ?? 'Untitled room',
      hostId: room['hostId'] as String?,
      hostName: room['hostName'] as String?,
      memberCount: room['memberCount'] as int? ?? 0,
      isInvited: json['isInvited'] as bool? ?? false,
    );
  }
}

/// A live participant in the party roster (socket-pushed, not REST).
class RosterEntry {
  final String userId;
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool micOn;

  RosterEntry({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isHost = false,
    this.micOn = false,
  });

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    return RosterEntry(
      userId: json['userId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Guest',
      avatarUrl: json['avatarUrl'] as String?,
      isHost: json['isHost'] as bool? ?? false,
      micOn: json['micOn'] as bool? ?? false,
    );
  }
}
