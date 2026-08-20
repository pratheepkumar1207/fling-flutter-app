import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
        // In-room, picking a video queues it (or plays immediately if
        // nothing's queued yet) — same as YouTube/Drive above — instead of
        // hard-replacing what the room's currently on.
        onAddToQueue: _inRoom
            ? ({required videoUrl, required title, thumbnail, required mediaMode, String sourceType = 'youtube'}) =>
                onAddToQueue!(videoUrl: videoUrl, title: title, thumbnail: thumbnail, mediaMode: mediaMode, sourceType: sourceType)
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
      childAspectRatio: 0.68,
      children: [
        _SourceTile(iconAsset: 'assets/icons/app/youtube.png', label: 'YouTube', available: true, onTap: () => _openYoutube(context)),
        _SourceTile(emoji: '❤️', label: 'Liked', available: true, onTap: () => _openAppSongList(context, title: 'Liked songs', endpoint: '/liked-songs')),
        _SourceTile(emoji: '🕘', label: 'History', available: true, onTap: () => _openAppSongList(context, title: 'History', endpoint: '/song-history')),
        _SourceTile(emoji: '📃', label: 'Playlists', available: true, onTap: () => _openPlaylists(context)),
        _SourceTile(iconAsset: 'assets/icons/app/youtube.png', label: 'YouTube Surf', available: true, onTap: () => _openWebviewSource(context, platform: 'youtube_surf', label: 'YouTube Surf', homeUrl: 'https://www.youtube.com')),
        _SourceTile(icon: FontAwesomeIcons.googleDrive, iconColor: const Color(0xFF0F9D58), label: 'Drive', available: true, onTap: () => _openDrive(context)),
        // Netflix/Crunchyroll and the India-specific platforms below have no
        // real logo glyph available in font_awesome_flutter's brand set —
        // rather than guess at reproducing their trademarked logo art from
        // memory, these use a colored letter-badge (see _SourceTile.letter)
        // instead of a real logo.
        _SourceTile(iconAsset: 'assets/icons/app/netflix.png', label: 'Netflix', available: true, onTap: () => _openWebviewSource(context, platform: 'netflix', label: 'Netflix', homeUrl: 'https://www.netflix.com/in/')),
        _SourceTile(letter: 'H', badgeColor: const Color(0xFF1F80E0), label: 'Hotstar', available: true, onTap: () => _openWebviewSource(context, platform: 'hotstar', label: 'Hotstar', homeUrl: 'https://www.hotstar.com/in/')),
        _SourceTile(iconAsset: 'assets/icons/app/amazon_prime.png', label: 'Prime Video', available: true, onTap: () => _openWebviewSource(context, platform: 'amazon', label: 'Prime Video', homeUrl: 'https://www.primevideo.com')),
        _SourceTile(letter: 'A', badgeColor: const Color(0xFFE4002B), label: 'Aha', available: true, onTap: () => _openWebviewSource(context, platform: 'aha', label: 'Aha', homeUrl: 'https://www.aha.video')),
        _SourceTile(letter: 'S', badgeColor: const Color(0xFFF7941D), label: 'SunNXT', available: true, onTap: () => _openWebviewSource(context, platform: 'sunnxt', label: 'SunNXT', homeUrl: 'https://www.sunnxt.com')),
        _SourceTile(letter: 'S', badgeColor: const Color(0xFF00A0DC), label: 'SonyLIV', available: true, onTap: () => _openWebviewSource(context, platform: 'sonyliv', label: 'SonyLIV', homeUrl: 'https://www.sonyliv.com')),
        _SourceTile(letter: 'A', badgeColor: const Color(0xFFE40000), label: 'Airtel Xstream', available: true, onTap: () => _openWebviewSource(context, platform: 'airtel_xstream', label: 'Airtel Xstream', homeUrl: 'https://www.airtelxstream.in')),
        const _SourceTile(letter: 'C', badgeColor: Color(0xFFF47521), label: 'Crunchyroll', available: false),
        _SourceTile(icon: FontAwesomeIcons.xTwitter, iconColor: AppColors.text, label: 'X', available: false),
      ],
    );
  }
}

/// Exactly one visual mode is set per tile:
///  - [icon]+[iconColor]: a real brand glyph (font_awesome_flutter's brand
///    icon set — only covers globally-recognized brands like YouTube/Drive/
///    Amazon/X).
///  - [letter]+[badgeColor]: a colored letter-badge, used for services with
///    no real logo available here (see the "Netflix/Crunchyroll" comment
///    at the call site for why — not guessing at trademarked logo art).
///  - [emoji]: app-internal categories (Liked/History/Playlists) that
///    aren't a third-party brand at all.
class _SourceTile extends StatelessWidget {
  final String? emoji;
  final FaIconData? icon;
  final Color? iconColor;
  final String? letter;
  final Color? badgeColor;
  final String? iconAsset;
  final String label;
  final bool available;
  final VoidCallback? onTap;

  const _SourceTile({
    this.emoji,
    this.icon,
    this.iconColor,
    this.letter,
    this.badgeColor,
    this.iconAsset,
    required this.label,
    required this.available,
    this.onTap,
  });

  Widget _visual() {
    if (iconAsset != null) return Image.asset(iconAsset!, width: 56, height: 56);
    if (icon != null) return FaIcon(icon, color: iconColor, size: 26);
    if (letter != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(letter!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      );
    }
    return Text(emoji ?? '', style: const TextStyle(fontSize: 28));
  }

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
              _visual(),
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
