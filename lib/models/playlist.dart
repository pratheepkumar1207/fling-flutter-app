import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final String visibility; // everyone | friends | followers | following
  final List<Song> songs;
  // Only populated by GET /playlists/user/:id (someone else's playlist) —
  // own playlists via GET /playlists don't carry these.
  final int likeCount;
  final bool isLiked;

  Playlist({
    required this.id,
    required this.name,
    this.visibility = 'everyone',
    this.songs = const [],
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'everyone',
      songs: (json['songs'] as List?)
              ?.map((s) => Song.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}

const kVisibilityLabels = {
  'everyone': '🌎 Everyone',
  'friends': '🤝 Friends',
  'followers': '👥 My followers',
  'following': '➡️ My following',
};
