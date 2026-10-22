import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/app_colors.dart';
import '../widgets/app_image.dart';
import '../widgets/google_connect_gate.dart';
import '../widgets/spinner.dart';

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
  const AppSongListTab(
      {super.key,
      required this.endpoint,
      required this.onAdd,
      this.canAddSongs = true,
      this.carousel = false});

  @override
  State<AppSongListTab> createState() => _AppSongListTabState();
}

class _AppSongListTabState extends State<AppSongListTab> {
  List<Song> _songs = [];
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

  Widget _carousel() {
    return LayoutBuilder(builder: (context, constraints) {
      final tileWidth = constraints.maxWidth * 0.46;
      final tileHeight = tileWidth * 9 / 16;
      const gap = 4.0;
      return SizedBox(
        height: tileHeight * 2 + gap,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _songs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: tileWidth,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemBuilder: (context, i) {
            final s = _songs[i];
            final added = s.videoUrl != null && _added.contains(s.videoUrl);
            return Semantics(
              button: true,
              label:
                  '${s.title ?? 'Untitled'}${added ? ', added' : ', add to queue'}',
              child: GestureDetector(
                onTap: widget.canAddSongs && !added ? () => _add(s) : null,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(8),
                    border: added
                        ? Border.all(color: AppColors.accent, width: 2)
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (s.thumbnail != null)
                        AppImage(source: s.thumbnail, fit: BoxFit.cover)
                      else
                        const Center(child: Text('🎵')),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Text(s.title ?? 'Untitled',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ),
                      if (added)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(999)),
                            child: const Text('Added',
                                style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

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
        _songs = (data as List)
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
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
  const AppPlaylistsTab(
      {super.key, required this.onAdd, this.canAddSongs = true, this.onAddAll});

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
      final data = await ApiClient.get('/playlists');
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
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('My playlists',
                style: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600))),
        if (_playlists.isEmpty)
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No playlists yet.',
                  style: TextStyle(color: AppColors.textFaint))),
        ..._playlists.map(
          (p) => ExpansionTile(
            title: Text(p.name,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
            subtitle: Text(
                '${p.songs.length} song${p.songs.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 11)),
            trailing: widget.onAddAll != null && p.songs.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlayAllButtons(
                        onPlay: () => widget.onAddAll!(p.songs),
                        onShuffle: () =>
                            widget.onAddAll!([...p.songs]..shuffle()),
                      ),
                      const Icon(Icons.expand_more, color: AppColors.textDim),
                    ],
                  )
                : null,
            iconColor: AppColors.textDim,
            collapsedIconColor: AppColors.textDim,
            children: p.songs
                .map((s) => ListTile(
                      dense: true,
                      title: Text(s.title ?? 'Untitled',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                      trailing: widget.canAddSongs
                          ? TextButton(
                              onPressed: () => widget.onAdd(
                                  videoUrl: s.videoUrl ?? '',
                                  title: s.title ?? '',
                                  thumbnail: s.thumbnail,
                                  mediaMode: 'video',
                                  sourceType: s.sourceType),
                              child: const Text('+ Add',
                                  style: TextStyle(
                                      color: AppColors.primary, fontSize: 12)),
                            )
                          : null,
                    ))
                .toList(),
          ),
        ),
        const Padding(
            padding: EdgeInsets.fromLTRB(0, 16, 0, 6),
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
                const Icon(Icons.expand_more, color: AppColors.textDim),
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
                        videoUrl:
                            'https://www.youtube.com/watch?v=${v['videoId']}',
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
          icon: const Icon(Icons.play_circle_fill_rounded,
              color: AppColors.accent, size: 26),
        ),
        IconButton(
          tooltip: 'Shuffle',
          visualDensity: VisualDensity.compact,
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded,
              color: AppColors.textDim, size: 22),
        ),
      ],
    );
  }
}
