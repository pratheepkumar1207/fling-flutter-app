import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final String visibility; // everyone | friends | followers | following
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    this.visibility = 'everyone',
    this.songs = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'everyone',
      songs: (json['songs'] as List?)?.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}

const kVisibilityLabels = {
  'everyone': '🌎 Everyone',
  'friends': '🤝 Friends',
  'followers': '👥 My followers',
  'following': '➡️ My following',
};
