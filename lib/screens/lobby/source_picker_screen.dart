import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_song_lists.dart';
import 'youtube_browse_screen.dart';
import 'drive_browse_screen.dart';
import 'webview_browse_screen.dart';
import 'watch_room_creator.dart';

/// Rave-style "pick a source" screen, used two ways:
///  - At room creation (Lobby -> "Choose what to watch"): [SourcePickerScreen]
///    wraps [SourcePickerBody] in its own Scaffold/AppBar.
///  - From inside an existing room (the Watch Party top bar's search icon,
///    via QueueSheetScreen): [SourcePickerBody] is embedded directly, with
///    [roomId] set — picking YouTube/Drive/Liked/History/Playlists content
///    adds it to the room's queue instead of creating a new room, and
///    picking a streaming platform switches the whole room's source
///    (with a confirmation — see webview_browse_screen.dart's _startHere).
/// Same tiles, same navigation pattern, either way — see SourcePickerBody.
///
/// Sign-in reliability varies by platform and isn't something this app
/// controls: Netflix is confirmed (live) to block fresh sign-in via its
/// own bot detection for a WebView that isn't already authenticated — a
/// real, known limitation of staying embedded, not a bug here. The others
/// aren't individually verified either way, but the app never attempts to
/// work around detection regardless of outcome. YouTube doesn't have this
/// problem at all, so YouTube Surf additionally upgrades to a normal
/// fully-synced room when you land on a real /watch?v= page (see
/// WebviewBrowseScreen's _startHere).
///
/// Crunchyroll/X stay disabled: same DRM ceiling as the rest, not worth a
/// bespoke screen until there's real demand.
class SourcePickerScreen extends StatelessWidget {
  final String visibility;
  final String? topic;

  const SourcePickerScreen({super.key, required this.visibility, this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Choose a source')),
      body: SourcePickerBody(visibility: visibility, topic: topic),
    );
  }
}

/// The actual tile grid + routing — see [SourcePickerScreen] for the two
/// contexts this gets used in.
class SourcePickerBody extends StatelessWidget {
  final String visibility;
  final String? topic;

  /// Non-null = in-room mode: picking a tile adds to/switches the room
  /// identified by [roomId] instead of creating a new one. [onAddToQueue]
  /// and [onSwitchSource] are required in that mode.
  final String? roomId;
  final SongAddCallback? onAddToQueue;
  final Future<void> Function(String sourceType, String videoUrl, {String? videoTitle, String? videoThumbnail})? onSwitchSource;

  const SourcePickerBody({
    super.key,
    this.visibility = 'public',
    this.topic,
    this.roomId,
    this.onAddToQueue,
    this.onSwitchSource,
  });

  bool get _inRoom => roomId != null;

  void _openYoutube(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => YoutubeBrowseScreen(
        visibility: visibility,
        topic: topic,
        onSelectOverride: _inRoom
            ? (item) {
                onAddToQueue!(
                  videoUrl: 'https://www.youtube.com/watch?v=${item['videoId']}',
                  title: item['title'] as String? ?? '',
                  thumbnail: item['thumbnail'] as String?,
                  mediaMode: 'video',
                );
                Navigator.of(context).pop();
              }
            : null,
      ),
    ));
  }

  void _openDrive(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DriveBrowseScreen(
        visibility: visibility,
        topic: topic,
        onSelectOverride: _inRoom
            ? (item) {
                onAddToQueue!(
                  videoUrl: item['id'] as String,
                  title: item['name'] as String? ?? '',
                  thumbnail: item['thumbnail'] as String?,
                  mediaMode: 'video',
                  sourceType: 'drive',
                );
                Navigator.of(context).pop();
              }
            : null,
      ),
    ));
  }

  void _openWebviewSource(BuildContext context, {required String platform, required String label, required String homeUrl}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebviewBrowseScreen(
        platform: platform,
        label: label,
        homeUrl: homeUrl,
        visibility: visibility,
        topic: topic,
        onConfirmOverride: _inRoom
            ? (sourceType, videoUrl, {videoTitle, videoThumbnail}) async {
                await onSwitchSource!(sourceType, videoUrl, videoTitle: videoTitle, videoThumbnail: videoThumbnail);
                if (context.mounted) Navigator.of(context).pop();
              }
            : null,
      ),
    ));
  }

  void _handleAppSongPick(BuildContext context, {required String videoUrl, required String title, String? thumbnail, required String mediaMode, required String sourceType}) {
    if (_inRoom) {
      onAddToQueue!(videoUrl: videoUrl, title: title, thumbnail: thumbnail, mediaMode: mediaMode, sourceType: sourceType);
      Navigator.of(context).pop();
    } else {
      createWatchRoomAndEnter(
        context,
        sourceType: sourceType,
        videoUrl: videoUrl,
        visibility: visibility,
        topic: topic,
        videoTitle: title,
        videoThumbnail: thumbnail,
      );
    }
  }

  void _openAppSongList(BuildContext context, {required String title, required String endpoint}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: Text(title)),
        body: AppSongListTab(
          endpoint: endpoint,
          onAdd: ({required videoUrl, required title, thumbnail, required mediaMode, String sourceType = 'youtube'}) =>
              _handleAppSongPick(context, videoUrl: videoUrl, title: title, thumbnail: thumbnail, mediaMode: mediaMode, sourceType: sourceType),
        ),
      ),
    ));
  }

  void _openPlaylists(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Playlists')),
        body: AppPlaylistsTab(
          onAdd: ({required videoUrl, required title, thumbnail, required mediaMode, String sourceType = 'youtube'}) =>
              _handleAppSongPick(context, videoUrl: videoUrl, title: title, thumbnail: thumbnail, mediaMode: mediaMode, sourceType: sourceType),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _SourceTile(emoji: '▶️', label: 'YouTube', available: true, onTap: () => _openYoutube(context)),
        _SourceTile(emoji: '❤️', label: 'Liked', available: true, onTap: () => _openAppSongList(context, title: 'Liked songs', endpoint: '/liked-songs')),
        _SourceTile(emoji: '🕘', label: 'History', available: true, onTap: () => _openAppSongList(context, title: 'History', endpoint: '/song-history')),
        _SourceTile(emoji: '📃', label: 'Playlists', available: true, onTap: () => _openPlaylists(context)),
        _SourceTile(emoji: '🏄', label: 'YouTube Surf', available: true, onTap: () => _openWebviewSource(context, platform: 'youtube_surf', label: 'YouTube Surf', homeUrl: 'https://www.youtube.com')),
        _SourceTile(emoji: '📁', label: 'Drive', available: true, onTap: () => _openDrive(context)),
        _SourceTile(emoji: '🎬', label: 'Netflix', available: true, onTap: () => _openWebviewSource(context, platform: 'netflix', label: 'Netflix', homeUrl: 'https://www.netflix.com/in/')),
        _SourceTile(emoji: '⭐', label: 'Hotstar', available: true, onTap: () => _openWebviewSource(context, platform: 'hotstar', label: 'Hotstar', homeUrl: 'https://www.hotstar.com/in/')),
        _SourceTile(emoji: '📦', label: 'Prime Video', available: true, onTap: () => _openWebviewSource(context, platform: 'amazon', label: 'Prime Video', homeUrl: 'https://www.primevideo.com')),
        _SourceTile(emoji: '🅰️', label: 'Aha', available: true, onTap: () => _openWebviewSource(context, platform: 'aha', label: 'Aha', homeUrl: 'https://www.aha.video')),
        _SourceTile(emoji: '☀️', label: 'SunNXT', available: true, onTap: () => _openWebviewSource(context, platform: 'sunnxt', label: 'SunNXT', homeUrl: 'https://www.sunnxt.com')),
        _SourceTile(emoji: '📺', label: 'SonyLIV', available: true, onTap: () => _openWebviewSource(context, platform: 'sonyliv', label: 'SonyLIV', homeUrl: 'https://www.sonyliv.com')),
        _SourceTile(emoji: '📡', label: 'Airtel Xstream', available: true, onTap: () => _openWebviewSource(context, platform: 'airtel_xstream', label: 'Airtel Xstream', homeUrl: 'https://www.airtelxstream.in')),
        const _SourceTile(emoji: '🍥', label: 'Crunchyroll', available: false),
        const _SourceTile(emoji: '𝕏', label: 'X', available: false),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String emoji;
  final String label;
  final bool available;
  final VoidCallback? onTap;

  const _SourceTile({required this.emoji, required this.label, required this.available, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: available ? onTap : null,
      child: Opacity(
        opacity: available ? 1 : 0.35,
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              if (!available) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Coming soon', style: TextStyle(color: AppColors.textFaint, fontSize: 9))),
            ],
          ),
        ),
      ),
    );
  }
}
