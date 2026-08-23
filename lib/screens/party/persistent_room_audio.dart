import 'package:flutter/material.dart';
import '../../core/active_room_holder.dart';
import '../../core/room_source_types.dart';
import 'room_socket_controller.dart';
import 'sync_video_player.dart';

/// Mounted once in AppShell (which stays alive underneath every route pushed
/// on top of it, PartyScreen included — see app_shell.dart) so it survives
/// navigating away from an active room's own screen. Renders nothing while
/// PartyScreen itself is showing (its own docked player is the one
/// producing audio then — see ActiveRoomHolder.isRoomScreenVisible); once
/// the user navigates elsewhere in-app, this mounts a hidden, silent
/// SyncVideoPlayer that keeps following the room's live queue/playback so
/// YouTube-sourced audio doesn't just cut out the way it used to when the
/// docked instance got disposed with the rest of PartyScreen's tree.
///
/// Drive-hosted and webview/OTT sources aren't handled here: Drive already
/// gets a real background session via background_audio_handler.dart, and
/// webview-embedded platforms (Netflix, Prime, etc.) have no playback sync
/// or audio-extraction story at all to keep alive.
class PersistentRoomAudio extends StatelessWidget {
  const PersistentRoomAudio({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: ActiveRoomHolder.activeLabel,
      builder: (context, label, _) {
        final rs = ActiveRoomHolder.controller;
        if (label == null || rs == null) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: ActiveRoomHolder.isRoomScreenVisible,
          builder: (context, roomScreenVisible, _) {
            if (roomScreenVisible) return const SizedBox.shrink();
            return AnimatedBuilder(
              animation: rs,
              builder: (context, _) => _buildPlayer(rs),
            );
          },
        );
      },
    );
  }

  Widget _buildPlayer(RoomSocketController rs) {
    final items = (rs.queue['items'] as List?) ?? [];
    final currentIndex = rs.queue['currentIndex'] as int? ?? 0;
    final currentItem = (items.isNotEmpty && currentIndex < items.length)
        ? Map<String, dynamic>.from(items[currentIndex] as Map)
        : null;
    final room = ActiveRoomHolder.room;
    final videoUrl =
        currentItem?['videoUrl'] as String? ?? room?['videoUrl'] as String?;
    final sourceType =
        currentItem?['sourceType'] as String? ?? room?['sourceType'] as String?;
    if (videoUrl == null ||
        sourceType == null ||
        sourceType == 'drive' ||
        webviewSourceTypes.contains(sourceType)) {
      return const SizedBox.shrink();
    }
    return SyncVideoPlayer(
      // Keyed by the video itself, same reasoning as party_screen.dart's
      // own playerKey — a new video means a genuinely new controller, but
      // switching room type or re-syncing shouldn't tear this down.
      key: ValueKey('persistent-audio-$videoUrl'),
      videoUrl: videoUrl,
      // Always false — this is a passive follower of the room's live
      // state, never a leader. The docked instance (when visible) is the
      // only one allowed to emit play/pause/seek back to the room.
      isHost: false,
      playback: rs.playback,
      mediaMode: 'audio',
      silent: true,
      onPlay: (_) {},
      onPause: (_) {},
      onSeek: (_) {},
      onRequestState: rs.requestState,
      onEnded: () {},
      onSkip: () {},
      liked: false,
      onToggleLike: () {},
    );
  }
}
