import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
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
  final videoUrl = s.videoId != null
      ? 'https://www.youtube.com/watch?v=${s.videoId}'
      : s.videoUrl;
  final item = {
    'sourceType': s.sourceType,
    'videoUrl': videoUrl,
    'title': s.title,
    'thumbnail': s.thumbnail,
    'mediaMode': 'video',
  };

  try {
    final active =
        await ApiClient.get('/rooms/mine/active') as Map<String, dynamic>;
    final activeRoomId = active['roomId'] as String?;
    if (activeRoomId != null) {
      if (!context.mounted) return;
      final socket = context.read<SocketService>().socket;
      final added = await _addToQueueAndConfirm(socket, activeRoomId, item);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(added
              ? 'Added to "${active['title'] ?? 'your room'}"'
              : 'Could not add — only the host can add songs right now')));
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: activeRoomId)));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Started a new room')));
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this song')));
    }
  }
}

/// Same idea as [playSongSmart] but for a whole playlist at once (e.g. a
/// liked playlist on Home) — queues every song into whatever room the user
/// is already active in, or starts a new one seeded with the first song
/// and queues the rest into it, instead of making the user add each song
/// one at a time.
Future<void> playPlaylistSmart(BuildContext context, List<Song> songs) async {
  if (songs.isEmpty) return;
  Map<String, dynamic> toItem(Song s) => {
        'sourceType': s.sourceType,
        'videoUrl': s.videoId != null
            ? 'https://www.youtube.com/watch?v=${s.videoId}'
            : s.videoUrl,
        'title': s.title,
        'thumbnail': s.thumbnail,
        'mediaMode': 'video',
      };

  try {
    final active =
        await ApiClient.get('/rooms/mine/active') as Map<String, dynamic>;
    final activeRoomId = active['roomId'] as String?;
    if (activeRoomId != null) {
      if (!context.mounted) return;
      final socket = context.read<SocketService>().socket;
      // Only the first add needs to wait for a possible denial — if
      // songPermission is host-only and this user isn't the host, every
      // subsequent add in the same room would be denied identically, so
      // there's nothing more to learn from waiting on each one.
      final firstAdded = await _addToQueueAndConfirm(socket, activeRoomId, toItem(songs.first));
      if (firstAdded) {
        for (final s in songs.skip(1)) {
          socket?.emit('queue:add', {'roomId': activeRoomId, 'item': toItem(s)});
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(firstAdded
              ? 'Added ${songs.length} songs to "${active['title'] ?? 'your room'}"'
              : 'Could not add — only the host can add songs right now')));
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PartyScreen(roomId: activeRoomId)));
      return;
    }

    final first = songs.first;
    final firstItem = toItem(first);
    final room = await ApiClient.post('/rooms', body: {
      'roomType': 'watch',
      'sourceType': firstItem['sourceType'],
      'videoUrl': firstItem['videoUrl'],
      'videoTitle': first.title,
      'videoThumbnail': first.thumbnail,
      'visibility': 'public',
    }) as Map<String, dynamic>;
    if (!context.mounted) return;
    final roomId = room['id'] as String;
    if (songs.length > 1) {
      final socket = context.read<SocketService>().socket;
      for (final s in songs.skip(1)) {
        socket?.emit('queue:add', {'roomId': roomId, 'item': toItem(s)});
      }
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Started a new room')));
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this playlist')));
    }
  }
}

/// Emits queue:add and waits briefly to see whether the server accepted it
/// or rejected it via `queue:denied` (e.g. the room's songPermission is
/// host-only and this caller isn't the host) — previously both callers
/// above showed "Added to <room>" unconditionally right after firing the
/// emit, regardless of whether the server actually added anything. There's
/// no ack-based confirmation for a *successful* add (queue:state broadcasts
/// to the whole room, not a targeted response to this one request), so a
/// short grace window with no denial arriving is treated as success —
/// the same trust level this call already had, just no longer blind to an
/// explicit rejection.
///
/// Registers its listener with a named reference and removes only that
/// same reference afterward (`.off('queue:denied', onDenied)`, not the
/// no-argument form) — this is the app's one shared, app-wide socket, and
/// a live RoomSocketController for this same room may already have its own
/// `queue:denied` listener registered on it; removing by reference instead
/// of blanket-clearing the event avoids silently breaking that (see
/// PARTY.md's realtime-recovery section for the identical lesson learned
/// the first time this exact mistake was almost made).
Future<bool> _addToQueueAndConfirm(io.Socket? socket, String roomId, Map<String, dynamic> item) async {
  if (socket == null) return false;
  final completer = Completer<bool>();
  void onDenied(dynamic _) {
    if (!completer.isCompleted) completer.complete(false);
  }

  socket.on('queue:denied', onDenied);
  socket.emit('queue:add', {'roomId': roomId, 'item': item});
  unawaited(Future.delayed(const Duration(milliseconds: 600), () {
    if (!completer.isCompleted) completer.complete(true);
  }));
  final result = await completer.future;
  socket.off('queue:denied', onDenied);
  return result;
}
