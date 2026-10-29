class DirectMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final String messageType; // 'text' | 'sticker' | 'gif' | 'image' | 'voice'
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  /// The message this one replies to, if any.
  final String? replyToId;

  /// userId → emoji.
  final Map<String, String> reactions;

  /// View-once photo: no image is sent with it; the recipient opens it
  /// once. [viewed] once they have.
  final bool viewOnce;
  final bool viewed;
  final DateTime? viewedAt;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    this.messageType = 'text',
    this.mediaUrl,
    required this.createdAt,
    this.readAt,
    this.replyToId,
    this.reactions = const {},
    this.viewOnce = false,
    this.viewed = false,
    this.viewedAt,
  });

  DirectMessage copyWith(
          {DateTime? readAt,
          Map<String, String>? reactions,
          bool? viewed,
          DateTime? viewedAt}) =>
      DirectMessage(
        id: id,
        senderId: senderId,
        recipientId: recipientId,
        text: text,
        messageType: messageType,
        mediaUrl: mediaUrl,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        replyToId: replyToId,
        reactions: reactions ?? this.reactions,
        viewOnce: viewOnce,
        viewed: viewed ?? this.viewed,
        viewedAt: viewedAt ?? this.viewedAt,
      );

  /// One line for a reply quote or a preview.
  String get summary => switch (messageType) {
        'image' when viewOnce => 'View once photo',
        'file' => 'Document',
        'location' => 'Location',
        'image' => 'Photo',
        'voice' => 'Voice message',
        'gif' => 'GIF',
        'sticker' => 'Sticker',
        _ => text,
      };

  static Map<String, String> reactionsFrom(dynamic raw) => raw is Map
      ? {for (final e in raw.entries) '${e.key}': '${e.value}'}
      : const {};

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      text: json['text'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'text',
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      replyToId: json['replyToId'] as String?,
      reactions: reactionsFrom(json['reactions']),
      viewOnce: json['viewOnce'] == true,
      viewed: json['viewed'] == true || json['viewedAt'] != null,
      viewedAt: json['viewedAt'] != null
          ? DateTime.tryParse(json['viewedAt'].toString())
          : null,
    );
  }
}

/// Mirrors GET /messages/conversations — one row per participant.
class ConversationSummary {
  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;
  final bool online;

  /// Someone who isn't a friend or match started this and you haven't
  /// replied yet — shown under Requests.
  final bool isRequest;

  /// 'text' | 'image' | 'voice' | 'sticker' | 'gif'.
  final String lastMessageType;

  /// My last message has been read by them.
  final bool lastMessageSeen;

  /// The room they're in right now, when their privacy settings allow.
  final ConversationActivity? activity;

  /// Who a message request is from (requests only).
  final RequestInfo? requestInfo;

  /// A request containing one of your hidden words (Safety centre).
  final bool hiddenRequest;

  /// My own settings for this chat (long-press menu).
  final bool pinned;
  final DateTime? mutedUntil;
  final bool markedUnread;

  bool get muted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  /// Counts as unread: real unread messages, or marked unread by hand.
  bool get isUnread => unreadCount > 0 || markedUnread;

  ConversationSummary({
    required this.userId,
    required this.name,
    this.username,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    this.unreadCount = 0,
    this.online = false,
    this.isRequest = false,
    this.lastMessageType = 'text',
    this.lastMessageSeen = false,
    this.activity,
    this.requestInfo,
    this.hiddenRequest = false,
    this.pinned = false,
    this.mutedUntil,
    this.markedUnread = false,
  });

  ConversationSummary copyWith(
          {bool? pinned,
          DateTime? mutedUntil,
          bool clearMute = false,
          bool? markedUnread}) =>
      ConversationSummary(
        userId: userId,
        name: name,
        username: username,
        avatarUrl: avatarUrl,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        lastMessageIsMine: lastMessageIsMine,
        unreadCount: unreadCount,
        online: online,
        isRequest: isRequest,
        lastMessageType: lastMessageType,
        lastMessageSeen: lastMessageSeen,
        activity: activity,
        requestInfo: requestInfo,
        hiddenRequest: hiddenRequest,
        pinned: pinned ?? this.pinned,
        mutedUntil: clearMute ? null : (mutedUntil ?? this.mutedUntil),
        markedUnread: markedUnread ?? this.markedUnread,
      );

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
              DateTime.now(),
      lastMessageIsMine: json['lastMessageIsMine'] as bool? ?? false,
      online: json['online'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isRequest: json['isRequest'] as bool? ?? false,
      lastMessageType: json['lastMessageType'] as String? ?? 'text',
      lastMessageSeen: json['lastMessageSeen'] as bool? ?? false,
      activity: json['activity'] is Map
          ? ConversationActivity.fromJson(
              Map<String, dynamic>.from(json['activity'] as Map))
          : null,
      pinned: json['pinned'] as bool? ?? false,
      hiddenRequest: json['hiddenRequest'] as bool? ?? false,
      mutedUntil: DateTime.tryParse('${json['mutedUntil'] ?? ''}'),
      markedUnread: json['markedUnread'] as bool? ?? false,
      requestInfo: json['requestInfo'] is Map
          ? RequestInfo.fromJson(
              Map<String, dynamic>.from(json['requestInfo'] as Map))
          : null,
    );
  }
}

class RequestInfo {
  final int? age;
  final String? city;
  final int? distanceKm;
  final bool isVerified;
  final int sharedInterests;
  final bool followsYou;

  const RequestInfo(
      {this.age,
      this.city,
      this.distanceKm,
      this.isVerified = false,
      this.sharedInterests = 0,
      this.followsYou = false});

  factory RequestInfo.fromJson(Map<String, dynamic> json) => RequestInfo(
        age: (json['age'] as num?)?.toInt(),
        city: json['city'] as String?,
        distanceKm: (json['distanceKm'] as num?)?.toInt(),
        isVerified: json['isVerified'] as bool? ?? false,
        sharedInterests: (json['sharedInterests'] as num?)?.toInt() ?? 0,
        followsYou: json['followsYou'] as bool? ?? false,
      );

  /// "24 · 3 km away · 2 shared interests · Follows you" (the city when
  /// either of you doesn't share location).
  String get line => [
        if (age != null) '$age',
        if (distanceKm != null)
          '$distanceKm km away'
        else if (city != null && city!.isNotEmpty)
          city!,
        if (sharedInterests > 0)
          sharedInterests == 1
              ? '1 shared interest'
              : '$sharedInterests shared interests',
        if (followsYou) 'Follows you',
      ].join(' · ');
}

/// What someone in your inbox is doing now: the public room they're in.
class ConversationActivity {
  final String roomId;
  final String title;
  final String roomType; // watch | voice | live | game
  final String? gameType;
  final int memberCount;
  final String? nowPlayingTitle;
  final bool canJoin;

  const ConversationActivity({
    required this.roomId,
    required this.title,
    required this.roomType,
    this.gameType,
    this.memberCount = 0,
    this.nowPlayingTitle,
    this.canJoin = true,
  });

  factory ConversationActivity.fromJson(Map<String, dynamic> json) =>
      ConversationActivity(
        roomId: json['roomId'] as String,
        title: json['title'] as String? ?? 'a room',
        roomType: json['roomType'] as String? ?? 'voice',
        gameType: json['gameType'] as String?,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        nowPlayingTitle: json['nowPlayingTitle'] as String?,
        canJoin: json['canJoin'] as bool? ?? true,
      );
}
