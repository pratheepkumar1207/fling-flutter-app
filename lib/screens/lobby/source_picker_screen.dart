import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
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
  // Room name + mic/song settings chosen in the lobby — see WatchRoomOptions.
  final WatchRoomOptions? options;

  const SourcePickerScreen(
      {super.key, required this.visibility, this.topic, this.options});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('What are we watching?')),
      body: SourcePickerBody(
          visibility: visibility, topic: topic, options: options),
    );
  }
}

/// The actual tile grid + routing — see [SourcePickerScreen] for the two
/// contexts this gets used in.
class SourcePickerBody extends StatelessWidget {
  final String visibility;
  final String? topic;
  // Room name + mic/song settings chosen in the lobby — see WatchRoomOptions.
  final WatchRoomOptions? options;

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

  /// In-room: queues a whole playlist in one go and starts it now ("Play
  /// all" / "Shuffle") — see RoomSocketController.queueAddMany. Falls back
  /// to adding the songs one by one when not given.
  final void Function(List<Map<String, dynamic>> items)? onPlayAll;

  const SourcePickerBody({
    super.key,
    this.visibility = 'public',
    this.topic,
    this.options,
    this.roomId,
    this.onAddToQueue,
    this.onSwitchSource,
    this.compact = false,
    this.audioOnly = false,
    this.onPlayAll,
  });

  bool get _inRoom => roomId != null;

  void _openYoutube(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => YoutubeBrowseScreen(
        visibility: visibility,
        topic: topic,
        options: options,
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
        options: options,
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
        options: options,
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
        options: options,
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
          // In a room the list is a 2-row carousel of thumbnails.
          carousel: _inRoom,
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
        appBar: AppBar(title: Text('Playlists')),
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
                  if (onPlayAll != null) {
                    onPlayAll!([
                      for (final s in songs)
                        if ((s.videoUrl ?? '').isNotEmpty)
                          {
                            'videoUrl': s.videoUrl,
                            'title': s.title ?? '',
                            'thumbnail': s.thumbnail,
                            'sourceType': s.sourceType,
                            'mediaMode': audioOnly ? 'audio' : 'video',
                          }
                    ]);
                    Navigator.of(context).pop();
                    return;
                  }
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
    if (audioOnly && _inRoom) {
      return _MusicSourceRow(
        compact: c,
        onYoutube: () => _openYoutube(context),
        onPlaylists: () => _openPlaylists(context),
        onDrive: () => _openDrive(context),
        onAdd: onAddToQueue!,
      );
    }
    final tiles = <String, Widget>{
      'YouTube': _SourceTile(
          compact: c,
          iconAsset: 'assets/icons/app/youtube.png',
          label: 'YouTube',
          available: true,
          onTap: () => _openYoutube(context)),
      'Liked': _SourceTile(
          compact: c,
          inIcon: InIcons.heart,
          label: 'Liked',
          available: true,
          onTap: () => _openAppSongList(context,
              title: 'Liked songs', endpoint: '/liked-songs')),
      'History': _SourceTile(
          compact: c,
          inIcon: InIcons.undo,
          label: 'History',
          available: true,
          onTap: () => _openAppSongList(context,
              title: 'History', endpoint: '/song-history')),
      'Playlists': _SourceTile(
          compact: c,
          inIcon: InIcons.queue,
          label: 'Playlists',
          available: true,
          onTap: () => _openPlaylists(context)),
      'YouTube Surf': _SourceTile(
          compact: c,
          iconAsset: 'assets/icons/app/youtube.png',
          label: 'YouTube Surf',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'youtube_surf',
              label: 'YouTube Surf',
              homeUrl: 'https://www.youtube.com')),
      'Drive': _SourceTile(
          compact: c,
          icon: FontAwesomeIcons.googleDrive,
          iconColor: const Color(0xFF0F9D58),
          label: 'Drive',
          available: true,
          onTap: () => _openDrive(context)),
      'Netflix': _SourceTile(
          compact: c,
          iconAsset: 'assets/icons/app/netflix.png',
          label: 'Netflix',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'netflix',
              label: 'Netflix',
              homeUrl: 'https://www.netflix.com/in/')),
      'Hotstar': _SourceTile(
          compact: c,
          letter: 'H',
          badgeColor: const Color(0xFF1F80E0),
          label: 'Hotstar',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'hotstar',
              label: 'Hotstar',
              homeUrl: 'https://www.hotstar.com/in/')),
      'Prime Video': _SourceTile(
          compact: c,
          iconAsset: 'assets/icons/app/amazon_prime.png',
          label: 'Prime Video',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'amazon',
              label: 'Prime Video',
              homeUrl: 'https://www.primevideo.com')),
      'Aha': _SourceTile(
          compact: c,
          letter: 'A',
          badgeColor: const Color(0xFFE4002B),
          label: 'Aha',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'aha', label: 'Aha', homeUrl: 'https://www.aha.video')),
      'SunNXT': _SourceTile(
          compact: c,
          letter: 'S',
          badgeColor: const Color(0xFFF7941D),
          label: 'SunNXT',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'sunnxt',
              label: 'SunNXT',
              homeUrl: 'https://www.sunnxt.com')),
      'SonyLIV': _SourceTile(
          compact: c,
          letter: 'S',
          badgeColor: const Color(0xFF00A0DC),
          label: 'SonyLIV',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'sonyliv',
              label: 'SonyLIV',
              homeUrl: 'https://www.sonyliv.com')),
      'Airtel Xstream': _SourceTile(
          compact: c,
          letter: 'A',
          badgeColor: const Color(0xFFE40000),
          label: 'Airtel Xstream',
          available: true,
          onTap: () => _openWebviewSource(context,
              platform: 'airtel_xstream',
              label: 'Airtel Xstream',
              homeUrl: 'https://www.airtelxstream.in')),
      'Crunchyroll': _SourceTile(
          compact: c,
          letter: 'C',
          badgeColor: const Color(0xFFF47521),
          label: 'Crunchyroll',
          available: false),
      'X': _SourceTile(
          compact: c,
          icon: FontAwesomeIcons.xTwitter,
          iconColor: AppColors.text,
          label: 'X',
          available: false),
    };
    if (c) {
      return GridView.count(
        padding: const EdgeInsets.all(10),
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: tiles.values.toList(),
      );
    }
    Widget section(String title, List<String> names) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Text(title,
                  style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600)),
            ),
            // Fixed four per row; height follows the label (large text).
            LayoutBuilder(
              builder: (context, box) => Wrap(
                runSpacing: 12,
                children: [
                  for (final n in names)
                    SizedBox(width: box.maxWidth / 4, child: tiles[n]!),
                ],
              ),
            ),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        section('FREE', ['YouTube', 'YouTube Surf', 'Drive', 'X']),
        section('YOUR SUBSCRIPTIONS · EACH PERSON SIGNS IN', [
          'Netflix',
          'Prime Video',
          'Hotstar',
          'SonyLIV',
          'SunNXT',
          'Aha',
          'Airtel Xstream',
          'Crunchyroll',
        ]),
        section('FROM YOUR LIBRARY', ['Playlists', 'Liked', 'History']),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InIcon(InIcons.info, size: 18, color: AppColors.lilac),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Netflix and Prime play in the Insync player. The host’s play and pause keep everyone in sync.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                ),
              ]),
        ),
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
///  - [inIcon]: app-internal lists (Liked/History/Playlists) in the app's own line icons.
///    aren't a third-party brand at all.
class _SourceTile extends StatelessWidget {
  final InIconData? inIcon;
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
    this.inIcon,
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
    final iconSize = compact ? 26.0 : 40.0;
    final faSize = compact ? 18.0 : 26.0;
    final badgeSize = compact ? 24.0 : 32.0;
    if (iconAsset != null) {
      return Image.asset(iconAsset!, width: iconSize, height: iconSize);
    }
    if (icon != null) return FaIcon(icon, color: iconColor, size: faSize);
    if (inIcon != null) {
      return InIcon(inIcon!, size: faSize, color: AppColors.lilac);
    }
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
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final box = compact ? 44.0 : 64.0;
    return Semantics(
      button: available,
      enabled: available,
      label: available ? label : '$label, coming soon',
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Opacity(
          opacity: available ? 1 : 0.4,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: box,
                  height: box,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(compact ? 12 : 18)),
                  alignment: Alignment.center,
                  child: _visual(),
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(label,
                    style: TextStyle(
                        color: AppColors.text, fontSize: compact ? 9.5 : 12),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (!available && !compact)
                  const Text('Soon',
                      style:
                          TextStyle(color: AppColors.textFaint, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Voice/Game rooms: one row of the music sources only (no OTT apps — they
/// can't play as background music; pasting a link works in the YouTube
/// search). History and Liked open right here as a 2-row carousel under
/// the icons, so the queue below stays in view while you pick.
class _MusicSourceRow extends StatefulWidget {
  final bool compact;
  final VoidCallback onYoutube;
  final VoidCallback onPlaylists;
  final VoidCallback onDrive;
  final SongAddCallback onAdd;
  const _MusicSourceRow({
    required this.compact,
    required this.onYoutube,
    required this.onPlaylists,
    required this.onDrive,
    required this.onAdd,
  });

  @override
  State<_MusicSourceRow> createState() => _MusicSourceRowState();
}

class _MusicSourceRowState extends State<_MusicSourceRow> {
  // '/song-history' or '/liked-songs' while its carousel is open.
  String? _open;

  void _toggle(String endpoint) =>
      setState(() => _open = _open == endpoint ? null : endpoint);

  Widget _tile(Widget tile, {bool selected = false}) => Expanded(
        child: AspectRatio(
          aspectRatio: 0.9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: AppColors.purple, width: 1.5)
                  : null,
            ),
            child: tile,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8 : 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _tile(_SourceTile(
                  compact: true,
                  iconAsset: 'assets/icons/app/youtube.png',
                  label: 'YouTube',
                  available: true,
                  onTap: widget.onYoutube)),
              _tile(
                  _SourceTile(
                      compact: true,
                      inIcon: InIcons.heart,
                      label: 'Liked',
                      available: true,
                      onTap: () => _toggle('/liked-songs')),
                  selected: _open == '/liked-songs'),
              _tile(
                  _SourceTile(
                      compact: true,
                      inIcon: InIcons.undo,
                      label: 'History',
                      available: true,
                      onTap: () => _toggle('/song-history')),
                  selected: _open == '/song-history'),
              _tile(_SourceTile(
                  compact: true,
                  inIcon: InIcons.queue,
                  label: 'Playlists',
                  available: true,
                  onTap: widget.onPlaylists)),
              _tile(_SourceTile(
                  compact: true,
                  icon: FontAwesomeIcons.googleDrive,
                  iconColor: const Color(0xFF0F9D58),
                  label: 'Drive',
                  available: true,
                  onTap: widget.onDrive)),
            ],
          ),
          if (_open != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
              child: Text(_open == '/liked-songs' ? 'Liked songs' : 'History',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            AppSongListTab(
              key: ValueKey(_open),
              endpoint: _open!,
              carousel: true,
              onAdd: widget.onAdd,
            ),
          ],
        ],
      ),
    );
  }
}
