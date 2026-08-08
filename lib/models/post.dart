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
    required this.createdAt,
  });

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
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
