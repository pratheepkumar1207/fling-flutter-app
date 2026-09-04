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
  final Future<void> Function(String sourceType, String videoUrl,
      {String? videoTitle, String? videoThumbnail})? onSwitchSource;

  /// Small (~3-row) variant used by QueueSheetScreen once something's
  /// already playing — smaller tiles, tighter grid, same tap targets. The
  /// full-size grid stays for the empty-queue case and the standalone
  /// SourcePickerScreen.
  final bool compact;

  /// Voice/Game rooms have no video to show — picking a source there is
  /// only ever about background music, and the full 14-tile grid (Netflix,
  /// Prime, Drive full videos, etc.) doesn't apply. Restricts the grid to
  /// just YouTube Music, browsed the same way YouTube Surf browses regular
  /// YouTube (see _openWebviewSource's 'youtube_surf' platform below —
  /// music.youtube.com's /watch?v= URLs match the exact same
  /// extractYouTubeId pattern, so no separate platform value is needed).
  final bool audioOnly;

  const SourcePickerBody({
    super.key,
    this.visibility = 'public',
    this.topic,
    this.roomId,
    this.onAddToQueue,
    this.onSwitchSource,
    this.compact = false,
    this.audioOnly = false,
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
                  videoUrl:
                      'https://www.youtube.com/watch?v=${item['videoId']}',
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

  void _openWebviewSource(BuildContext context,
      {required String platform,
      required String label,
      required String homeUrl}) {
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
            ? (
                    {required videoUrl,
                    required title,
                    thumbnail,
                    required mediaMode,
                    String sourceType = 'youtube'}) =>
                onAddToQueue!(
                    videoUrl: videoUrl,
                    title: title,
                    thumbnail: thumbnail,
                    mediaMode: mediaMode,
                    sourceType: sourceType)
            : null,
      ),
    ));
  }

  void _handleAppSongPick(BuildContext context,
      {required String videoUrl,
      required String title,
      String? thumbnail,
      required String mediaMode,
      required String sourceType}) {
    if (_inRoom) {
      onAddToQueue!(
          videoUrl: videoUrl,
          title: title,
          thumbnail: thumbnail,
          mediaMode: mediaMode,
          sourceType: sourceType);
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

  void _openAppSongList(BuildContext context,
      {required String title, required String endpoint}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: Text(title)),
        body: AppSongListTab(
          endpoint: endpoint,
          onAdd: (
                  {required videoUrl,
                  required title,
                  thumbnail,
                  required mediaMode,
                  String sourceType = 'youtube'}) =>
              _handleAppSongPick(context,
                  videoUrl: videoUrl,
                  title: title,
                  thumbnail: thumbnail,
                  mediaMode: mediaMode,
                  sourceType: sourceType),
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
          onAdd: (
                  {required videoUrl,
                  required title,
                  thumbnail,
                  required mediaMode,
                  String sourceType = 'youtube'}) =>
              _handleAppSongPick(context,
                  videoUrl: videoUrl,
                  title: title,
                  thumbnail: thumbnail,
                  mediaMode: mediaMode,
                  sourceType: sourceType),
          // Only offered in-room — queueing a whole playlist at once only
          // makes sense against an existing room's queue, not the "create
          // a new room" flow (which would otherwise try to create one new
          // room per song).
          onAddAll: _inRoom
              ? (songs) {
                  for (final s in songs) {
                    onAddToQueue!(
                        videoUrl: s.videoUrl ?? '',
                        title: s.title ?? '',
                        thumbnail: s.thumbnail,
                        mediaMode: 'video',
                        sourceType: s.sourceType);
                  }
                  Navigator.of(context).pop();
                }
              : null,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = compact;
    if (audioOnly) {
      // Just a search entry point, not a source grid — Voice/Game rooms
      // only ever have the one music source, so a whole tile naming it
      // (and requiring an extra tap to open) added nothing a plain search
      // icon doesn't already say. Tapping it goes straight into browsing.
      return Center(
        child: GestureDetector(
          onTap: () => _openWebviewSource(context,
              platform: 'youtube_surf',
              label: 'Search songs',
              homeUrl: 'https://music.youtube.com'),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: c ? 12 : 16, vertical: c ? 8 : 10),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded,
                    color: AppColors.textDim, size: c ? 16 : 18),
                const SizedBox(width: 6),
                Text('Search songs',
                    style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: c ? 11 : 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }
    return GridView.count(
      padding: EdgeInsets.all(c ? 10 : 16),
      crossAxisCount: c ? 5 : 3,
      mainAxisSpacing: c ? 8 : 12,
      crossAxisSpacing: c ? 8 : 12,
      childAspectRatio: c ? 0.85 : 0.68,
      children: [
        _SourceTile(
            compact: c,
            iconAsset: 'assets/icons/app/youtube.png',
            label: 'YouTube',
            available: true,
            onTap: () => _openYoutube(context)),
        _SourceTile(
            compact: c,
            emoji: '❤️',
            label: 'Liked',
            available: true,
            onTap: () => _openAppSongList(context,
                title: 'Liked songs', endpoint: '/liked-songs')),
        _SourceTile(
            compact: c,
            emoji: '🕘',
            label: 'History',
            available: true,
            onTap: () => _openAppSongList(context,
                title: 'History', endpoint: '/song-history')),
        _SourceTile(
            compact: c,
            emoji: '📃',
            label: 'Playlists',
            available: true,
            onTap: () => _openPlaylists(context)),
        _SourceTile(
            compact: c,
            iconAsset: 'assets/icons/app/youtube.png',
            label: 'YouTube Surf',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'youtube_surf',
                label: 'YouTube Surf',
                homeUrl: 'https://www.youtube.com')),
        _SourceTile(
            compact: c,
            icon: FontAwesomeIcons.googleDrive,
            iconColor: const Color(0xFF0F9D58),
            label: 'Drive',
            available: true,
            onTap: () => _openDrive(context)),
        // Netflix/Crunchyroll and the India-specific platforms below have no
        // real logo glyph available in font_awesome_flutter's brand set —
        // rather than guess at reproducing their trademarked logo art from
        // memory, these use a colored letter-badge (see _SourceTile.letter)
        // instead of a real logo.
        _SourceTile(
            compact: c,
            iconAsset: 'assets/icons/app/netflix.png',
            label: 'Netflix',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'netflix',
                label: 'Netflix',
                homeUrl: 'https://www.netflix.com/in/')),
        _SourceTile(
            compact: c,
            letter: 'H',
            badgeColor: const Color(0xFF1F80E0),
            label: 'Hotstar',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'hotstar',
                label: 'Hotstar',
                homeUrl: 'https://www.hotstar.com/in/')),
        _SourceTile(
            compact: c,
            iconAsset: 'assets/icons/app/amazon_prime.png',
            label: 'Prime Video',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'amazon',
                label: 'Prime Video',
                homeUrl: 'https://www.primevideo.com')),
        _SourceTile(
            compact: c,
            letter: 'A',
            badgeColor: const Color(0xFFE4002B),
            label: 'Aha',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'aha',
                label: 'Aha',
                homeUrl: 'https://www.aha.video')),
        _SourceTile(
            compact: c,
            letter: 'S',
            badgeColor: const Color(0xFFF7941D),
            label: 'SunNXT',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'sunnxt',
                label: 'SunNXT',
                homeUrl: 'https://www.sunnxt.com')),
        _SourceTile(
            compact: c,
            letter: 'S',
            badgeColor: const Color(0xFF00A0DC),
            label: 'SonyLIV',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'sonyliv',
                label: 'SonyLIV',
                homeUrl: 'https://www.sonyliv.com')),
        _SourceTile(
            compact: c,
            letter: 'A',
            badgeColor: const Color(0xFFE40000),
            label: 'Airtel Xstream',
            available: true,
            onTap: () => _openWebviewSource(context,
                platform: 'airtel_xstream',
                label: 'Airtel Xstream',
                homeUrl: 'https://www.airtelxstream.in')),
        _SourceTile(
            compact: c,
            letter: 'C',
            badgeColor: const Color(0xFFF47521),
            label: 'Crunchyroll',
            available: false),
        _SourceTile(
            compact: c,
            icon: FontAwesomeIcons.xTwitter,
            iconColor: AppColors.text,
            label: 'X',
            available: false),
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
  final bool compact;

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
    this.compact = false,
  });

  Widget _visual() {
    final iconSize = compact ? 30.0 : 56.0;
    final faSize = compact ? 18.0 : 26.0;
    final badgeSize = compact ? 24.0 : 32.0;
    final emojiSize = compact ? 18.0 : 28.0;
    if (iconAsset != null) {
      return Image.asset(iconAsset!, width: iconSize, height: iconSize);
    }
    if (icon != null) return FaIcon(icon, color: iconColor, size: faSize);
    if (letter != null) {
      return Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(letter!,
            style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 16,
                fontWeight: FontWeight.w800)),
      );
    }
    return Text(emoji ?? '', style: TextStyle(fontSize: emojiSize));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: available ? onTap : null,
      child: Opacity(
        opacity: available ? 1 : 0.35,
        child: Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(compact ? 10 : 14)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _visual(),
              SizedBox(height: compact ? 4 : 8),
              Text(label,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: compact ? 9.5 : 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (!available && !compact)
                const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Coming soon',
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 9))),
            ],
          ),
        ),
      ),
    );
  }
}
