import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../screens/party/party_screen.dart';
import 'api_client.dart';
import 'socket_service.dart';

/// Tapping a song from someone's History/Liked/Playlist (i.e. from outside
/// any room screen — Profile, CreatorProfile) either drops it into whatever
/// room the current user is presently active in, or spins up a brand-new
/// watch party for it if they aren't in one. Mirrors the in-room "add to
/// queue" behavior already used by QueueSheet, just reachable from places
/// that aren't already inside a room's own socket/queue context.
Future<void> playSongSmart(BuildContext context, Song s) async {
  final videoUrl = s.videoId != null ? 'https://www.youtube.com/watch?v=${s.videoId}' : s.videoUrl;
  final item = {
    'sourceType': s.sourceType,
    'videoUrl': videoUrl,
    'title': s.title,
    'thumbnail': s.thumbnail,
    'mediaMode': 'video',
  };

  try {
    final active = await ApiClient.get('/rooms/mine/active') as Map<String, dynamic>;
    final activeRoomId = active['roomId'] as String?;
    if (activeRoomId != null) {
      if (context.mounted) {
        final socket = context.read<SocketService>().socket;
        socket?.emit('queue:add', {'roomId': activeRoomId, 'item': item});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to "${active['title'] ?? 'your room'}"')));
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: activeRoomId)));
      }
      return;
    }

    // 'title' isn't a real field on POST /rooms — it always auto-generates
    // the room's own name (see fallbackTitle in room.js) and silently
    // ignored whatever was sent here. videoTitle/videoThumbnail are what
    // actually seed the queue's "now playing" display — omitting them is
    // exactly what left the queue permanently empty (see
    // party_screen.dart's queue-seed guard, which requires a real title).
    final room = await ApiClient.post('/rooms', body: {
      'roomType': 'watch',
      'sourceType': item['sourceType'],
      'videoUrl': item['videoUrl'],
      'videoTitle': s.title,
      'videoThumbnail': s.thumbnail,
      'visibility': 'public',
    }) as Map<String, dynamic>;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started a new room')));
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play this song')));
    }
  }
}
