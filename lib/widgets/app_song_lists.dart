import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../core/youtube_util.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/app_colors.dart';
import '../widgets/app_image.dart';
import '../widgets/google_connect_gate.dart';
import '../widgets/spinner.dart';
import 'two_row_carousel.dart';
import 'yt_lists.dart';

/// Shared app-internal song list tabs — extracted from queue_sheet.dart so
/// both the in-room Queue sheet and the (Lobby/in-room) source picker can
/// show the same Liked/History/Playlists content, just wired to a
/// different `onAdd` (append to queue vs. create/switch a room).
typedef SongAddCallback = void Function(
    {required String videoUrl,
    required String title,
    String? thumbnail,
    required String mediaMode,
    String sourceType});

class AppSongListTab extends StatefulWidget {
  final String endpoint;
  final SongAddCallback onAdd;
  final bool canAddSongs;
  // In a room: a 2-row sideways carousel of 16:9 thumbnails (tap to add)
  // instead of the plain list.
  final bool carousel;
  // In a room: Play all / Shuffle queue the whole list.
  final void Function(List<Song> songs)? onAddAll;
  const AppSongListTab(
      {super.key,
      required this.endpoint,
      required this.onAdd,
      this.canAddSongs = true,
      this.carousel = false,
      this.onAddAll});

  @override
  State<AppSongListTab> createState() => _AppSongListTabState();
}

class _AppSongListTabState extends State<AppSongListTab> {
  List<Song> _songs = [];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  // Added during this visit — shown as "Added" on the carousel tile.
  final Set<String> _added = {};

  void _add(Song s) {
    widget.onAdd(
        videoUrl: s.videoUrl ?? '',
        title: s.title ?? '',
        thumbnail: s.thumbnail,
        mediaMode: 'video',
        sourceType: s.sourceType);
    if (s.videoUrl != null) setState(() => _added.add(s.videoUrl!));
  }

  Widget _carousel() => TwoRowCarousel(tiles: [
        for (final s in _songs)
          () {
            final added = s.videoUrl != null && _added.contains(s.videoUrl);
            return CarouselTile(
              title: s.title ?? 'Untitled',
              thumbnail: s.thumbnail,
              highlighted: added,
              badge: added ? 'Added' : null,
              onTap: widget.canAddSongs && !added ? () => _add(s) : null,
            );
          }(),
      ]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get(widget.endpoint);
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final e in data as List) Map<String, dynamic>.from(e as Map)
        ];
        _songs = _rows.map(Song.fromJson).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Spinner());
    if (!widget.carousel) {
      final history = widget.endpoint.startsWith('/song-history');
      return YtSongList(
        rows: _rows,
        history: history,
        onAdd: widget.canAddSongs ? (r) => _add(Song.fromJson(r)) : null,
        onAddAll: widget.onAddAll == null
            ? null
            : (rows) => widget.onAddAll!(rows.map(Song.fromJson).toList()),
        onRemove: (r) => ytRemove(widget.endpoint, r),
        onClear: history
            ? () async {
                try {
                  await ApiClient.delete('/song-history');
                } catch (_) {}
              }
            : null,
      );
    }
    if (_songs.isEmpty) {
      return const Center(
          child: Text('Nothing here yet.',
              style: TextStyle(color: AppColors.textFaint)));
    }
    if (widget.carousel) return _carousel();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _songs.length,
      itemBuilder: (context, i) {
        final s = _songs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: s.thumbnail != null
                    ? AppImage(source: s.thumbnail, fit: BoxFit.cover)
                    : const Center(child: Text('🎵')),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(s.title ?? 'Untitled',
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              if (widget.canAddSongs)
                TextButton(
                  onPressed: () => widget.onAdd(
                      videoUrl: s.videoUrl ?? '',
                      title: s.title ?? '',
                      thumbnail: s.thumbnail,
                      mediaMode: 'video',
                      sourceType: s.sourceType),
                  child: const Text('+ Add',
                      style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AppPlaylistsTab extends StatefulWidget {
  final SongAddCallback onAdd;
  final bool canAddSongs;
  // Non-null (in-room mode only — see source_picker_screen.dart) queues
  // every song in a playlist at once instead of requiring a tap per song.
  final void Function(List<Song> songs)? onAddAll;
  // Music rooms: only playlists (and songs) from YouTube Music.
  final bool music;
  const AppPlaylistsTab(
      {super.key,
      required this.onAdd,
      this.canAddSongs = true,
      this.onAddAll,
      this.music = false});

  @override
  State<AppPlaylistsTab> createState() => _AppPlaylistsTabState();
}

class _AppPlaylistsTabState extends State<AppPlaylistsTab> {
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get(
          widget.music ? '/playlists?music=1' : '/playlists');
      if (!mounted) return;
      setState(() {
        _playlists = (data as List)
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Spinner());
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_playlists.isEmpty)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No playlists yet.',
                  style: TextStyle(color: AppColors.textFaint))),
        YtPlaylistList(
          playlists: _playlists,
          subtitle: (p) =>
              'Yours \u00B7 ${p.songs.length} song${p.songs.length == 1 ? '' : 's'}',
          onOpen: (p) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => YtPlaylistScreen(
              playlist: p,
              onAdd: widget.canAddSongs
                  ? (s) => widget.onAdd(
                      videoUrl: s.videoUrl ?? '',
                      title: s.title ?? '',
                      thumbnail: s.thumbnail,
                      mediaMode: 'video',
                      sourceType: s.sourceType)
                  : null,
              onAddAll: widget.onAddAll,
            ),
          )),
        ),
        const Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 6),
            child: Text('YouTube playlists',
                style: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600))),
        SizedBox(
          height: 260,
          child: GoogleConnectGate(
              child: _YoutubePlaylistList(
                  onAdd: widget.onAdd,
                  canAddSongs: widget.canAddSongs,
                  onAddAll: widget.onAddAll != null
                      ? (items) => widget.onAddAll!(items
                          .map((v) => Song(
                                videoUrl:
                                    'https://www.youtube.com/watch?v=${v['videoId']}',
                                title: v['title'] as String?,
                                thumbnail: v['thumbnail'] as String?,
                                sourceType: 'youtube',
                              ))
                          .toList())
                      : null)),
        ),
      ],
    );
  }
}

/// The user's own connected-Google YouTube playlists — separate from the
/// app-internal ones above, backed by GET /youtube/playlists (see
/// src/routes/youtube.js and google_content_service.dart). Reuses the same
/// GoogleConnectGate as the Rave-style watch-party source picker.
class _YoutubePlaylistList extends StatefulWidget {
  final SongAddCallback onAdd;
  final bool canAddSongs;
  final void Function(List<Map<String, dynamic>> items)? onAddAll;
  const _YoutubePlaylistList(
      {required this.onAdd, required this.canAddSongs, this.onAddAll});

  @override
  State<_YoutubePlaylistList> createState() => _YoutubePlaylistListState();
}

class _YoutubePlaylistListState extends State<_YoutubePlaylistList> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/youtube/playlists');
      if (!mounted) return;
      setState(() {
        _playlists = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Spinner());
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12)));
    }
    if (_playlists.isEmpty) {
      return const Center(
          child: Text('No YouTube playlists found.',
              style: TextStyle(color: AppColors.textFaint)));
    }
    return ListView(
      children: _playlists
          .map((p) => _YoutubePlaylistTile(
              playlist: p,
              onAdd: widget.onAdd,
              canAddSongs: widget.canAddSongs,
              onAddAll: widget.onAddAll))
          .toList(),
    );
  }
}

class _YoutubePlaylistTile extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final SongAddCallback onAdd;
  final bool canAddSongs;
  final void Function(List<Map<String, dynamic>> items)? onAddAll;
  const _YoutubePlaylistTile(
      {required this.playlist,
      required this.onAdd,
      required this.canAddSongs,
      this.onAddAll});

  @override
  State<_YoutubePlaylistTile> createState() => _YoutubePlaylistTileState();
}

class _YoutubePlaylistTileState extends State<_YoutubePlaylistTile> {
  List<Map<String, dynamic>>? _items; // null until first expanded
  bool _loading = false;
  bool _addingAll = false;

  Future<void> _loadItems() async {
    if (_items != null || _loading) return;
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get(
          '/youtube/playlists/${widget.playlist['id']}/items');
      if (!mounted) return;
      setState(() {
        _items = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
    }
  }

  // Items are normally only fetched once the tile expands — this fetches
  // them first (if not already loaded) so "Add all" works as one tap even
  // from a collapsed tile, instead of requiring an expand first.
  Future<void> _addAll({bool shuffle = false}) async {
    setState(() => _addingAll = true);
    await _loadItems();
    if (!mounted) return;
    setState(() => _addingAll = false);
    final items = _items;
    if (items != null && items.isNotEmpty) {
      widget.onAddAll!(shuffle ? ([...items]..shuffle()) : items);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      onExpansionChanged: (open) {
        if (open) _loadItems();
      },
      title: Text(widget.playlist['title'] as String? ?? '',
          style: const TextStyle(color: AppColors.text, fontSize: 13)),
      subtitle: Text('${widget.playlist['itemCount'] ?? 0} videos',
          style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
      trailing: widget.onAddAll != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _addingAll
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Spinner(size: 14),
                      )
                    : _PlayAllButtons(
                        onPlay: () => _addAll(),
                        onShuffle: () => _addAll(shuffle: true),
                      ),
                const InIcon(InIcons.down, color: AppColors.textDim),
              ],
            )
          : null,
      iconColor: AppColors.textDim,
      collapsedIconColor: AppColors.textDim,
      children: [
        if (_loading)
          const Padding(padding: EdgeInsets.all(8), child: Spinner(size: 18)),
        ...?_items?.map((v) => ListTile(
              dense: true,
              title: Text(v['title'] as String? ?? 'Untitled',
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: widget.canAddSongs
                  ? TextButton(
                      onPressed: () => widget.onAdd(
                        videoUrl: youtubeWatchUrl(v['videoId'],
                            playlistId: widget.playlist['id']),
                        title: v['title'] as String? ?? '',
                        thumbnail: v['thumbnail'] as String?,
                        mediaMode: 'video',
                      ),
                      child: const Text('+ Add',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 12)),
                    )
                  : null,
            )),
      ],
    );
  }
}

/// "Play all" + "Shuffle" for a whole playlist — the room queues every song
/// and plays them one after another.
class _PlayAllButtons extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  const _PlayAllButtons({required this.onPlay, required this.onShuffle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Play all',
          visualDensity: VisualDensity.compact,
          onPressed: onPlay,
          icon: const InIcon(InIcons.play,
              filled: true, color: AppColors.accent, size: 26),
        ),
        IconButton(
          tooltip: 'Shuffle',
          visualDensity: VisualDensity.compact,
          onPressed: onShuffle,
          icon: const InIcon(InIcons.swap, color: AppColors.textDim, size: 22),
        ),
      ],
    );
  }
}
