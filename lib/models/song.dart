/// A queued/playlist/liked/history song. Backend keeps this free-form, so
/// this model stays permissive rather than forcing a rigid schema.
class Song {
  final String? id;
  final String? videoUrl;
  final String? videoId;
  final String? title;
  final String? thumbnail;
  final String sourceType;
  final String mediaMode; // 'video' | 'audio'

  Song({
    this.id,
    this.videoUrl,
    this.videoId,
    this.title,
    this.thumbnail,
    this.sourceType = 'youtube',
    this.mediaMode = 'video',
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString(),
      videoUrl: json['videoUrl'] as String?,
      videoId: json['videoId'] as String?,
      title: json['title'] as String?,
      thumbnail: json['thumbnail'] as String?,
      sourceType: json['sourceType'] as String? ?? 'youtube',
      mediaMode: json['mediaMode'] as String? ?? 'video',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (videoId != null) 'videoId': videoId,
        'title': title,
        'thumbnail': thumbnail,
        'sourceType': sourceType,
        'mediaMode': mediaMode,
      };
}
