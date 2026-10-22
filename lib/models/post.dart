class PostAuthor {
  final String id;
  final String name;
  final String? avatarUrl;

  PostAuthor({required this.id, required this.name, this.avatarUrl});

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Mirrors serializePost() in the backend's src/routes/feed.js.
class Post {
  final String id;
  final PostAuthor author;
  final String mediaType;
  final String? text;
  final String? imageData;
  final String? voiceData;
  final String? videoUrl;
  final String? videoData;
  final List<dynamic>? pollOptions;
  final int? myVote;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool savedByMe;
  final bool isOwn;
  // The author hid their like counts — only they see the number.
  final bool likesHidden;
  final String? location;
  // [{id, name, username, avatarUrl}]
  final List<Map<String, dynamic>> taggedUsers;
  final Map<String, dynamic>? collaborator;
  // The post this one re-shares: {id, mediaType, text, imageData, author}.
  final Map<String, dynamic>? repostOf;
  final bool commentsDisabled;
  final bool hideLikes;
  final bool archived;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.author,
    required this.mediaType,
    this.text,
    this.imageData,
    this.voiceData,
    this.videoUrl,
    this.videoData,
    this.pollOptions,
    this.myVote,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.isOwn = false,
    this.likesHidden = false,
    this.location,
    this.taggedUsers = const [],
    this.collaborator,
    this.repostOf,
    this.commentsDisabled = false,
    this.hideLikes = false,
    this.archived = false,
    required this.createdAt,
  });

  /// Same post with some fields changed — keeps everything else as is.
  Post copyWith({
    int? likesCount,
    bool? likedByMe,
    bool? savedByMe,
    int? myVote,
    bool? commentsDisabled,
    bool? hideLikes,
    bool? archived,
  }) =>
      Post(
        id: id,
        author: author,
        mediaType: mediaType,
        text: text,
        imageData: imageData,
        voiceData: voiceData,
        videoUrl: videoUrl,
        videoData: videoData,
        pollOptions: pollOptions,
        myVote: myVote ?? this.myVote,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        isOwn: isOwn,
        likesHidden: likesHidden,
        location: location,
        taggedUsers: taggedUsers,
        collaborator: collaborator,
        repostOf: repostOf,
        commentsDisabled: commentsDisabled ?? this.commentsDisabled,
        hideLikes: hideLikes ?? this.hideLikes,
        archived: archived ?? this.archived,
        createdAt: createdAt,
      );

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      mediaType: json['mediaType'] as String? ?? 'text',
      text: json['text'] as String?,
      imageData: json['imageData'] as String?,
      voiceData: json['voiceData'] as String?,
      videoUrl: json['videoUrl'] as String?,
      videoData: json['videoData'] as String?,
      pollOptions: json['pollOptions'] as List?,
      myVote: json['myVote'] as int?,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
      isOwn: json['isOwn'] as bool? ?? false,
      likesHidden: json['likesHidden'] as bool? ?? false,
      location: json['location'] as String?,
      taggedUsers: ((json['taggedUsers'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      collaborator: json['collaborator'] is Map
          ? Map<String, dynamic>.from(json['collaborator'] as Map)
          : null,
      repostOf: json['repostOf'] is Map
          ? Map<String, dynamic>.from(json['repostOf'] as Map)
          : null,
      commentsDisabled: json['commentsDisabled'] as bool? ?? false,
      hideLikes: json['hideLikes'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
