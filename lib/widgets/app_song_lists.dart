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
typedef SongAddCallback = void Function({required String videoUrl, required String title, String? thumbnail, required String mediaMode, String sourceType});

class AppSongListTab extends StatefulWidget {
  final String endpoint;
  final SongAddCallback onAdd;
  final bool canAddSongs;
  const AppSongListTab({super.key, required this.endpoint, required this.onAdd, this.canAddSongs = true});

  @override
  State<AppSongListTab> createState() => _AppSongListTabState();
}

class _AppSongListTabState extends State<AppSongListTab> {
  List<Song> _songs = [];
  bool _loading = true;

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
        _songs = (data as List).map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Spinner());
    if (_songs.isEmpty) return const Center(child: Text('Nothing here yet.', style: TextStyle(color: AppColors.textFaint)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _songs.length,
      itemBuilder: (context, i) {
        final s = _songs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: s.thumbnail != null ? AppImage(source: s.thumbnail, fit: BoxFit.cover) : const Center(child: Text('🎵')),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(s.title ?? 'Untitled', style: const TextStyle(color: AppColors.text, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (widget.canAddSongs)
                TextButton(
                  onPressed: () => widget.onAdd(videoUrl: s.videoUrl ?? '', title: s.title ?? '', thumbnail: s.thumbnail, mediaMode: 'video', sourceType: s.sourceType),
                  child: const Text('+ Add', style: TextStyle(color: AppColors.primary, fontSize: 12)),
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
  const AppPlaylistsTab({super.key, required this.onAdd, this.canAddSongs = true});

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
        _playlists = (data as List).map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
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
        const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('My playlists', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600))),
        if (_playlists.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('No playlists yet.', style: TextStyle(color: AppColors.textFaint))),
        ..._playlists.map(
          (p) => ExpansionTile(
            title: Text(p.name, style: const TextStyle(color: AppColors.text, fontSize: 13)),
            subtitle: Text('${p.songs.length} song${p.songs.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
            iconColor: AppColors.textDim,
            collapsedIconColor: AppColors.textDim,
            children: p.songs
                .map((s) => ListTile(
                      dense: true,
                      title: Text(s.title ?? 'Untitled', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                      trailing: widget.canAddSongs
                          ? TextButton(
                              onPressed: () => widget.onAdd(videoUrl: s.videoUrl ?? '', title: s.title ?? '', thumbnail: s.thumbnail, mediaMode: 'video', sourceType: s.sourceType),
                              child: const Text('+ Add', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            )
                          : null,
                    ))
                .toList(),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(0, 16, 0, 6), child: Text('YouTube playlists', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600))),
        SizedBox(
          height: 260,
          child: GoogleConnectGate(child: _YoutubePlaylistList(onAdd: widget.onAdd, canAddSongs: widget.canAddSongs)),
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
  const _YoutubePlaylistList({required this.onAdd, required this.canAddSongs});

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
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)));
    if (_playlists.isEmpty) return const Center(child: Text('No YouTube playlists found.', style: TextStyle(color: AppColors.textFaint)));
    return ListView(
      children: _playlists.map((p) => _YoutubePlaylistTile(playlist: p, onAdd: widget.onAdd, canAddSongs: widget.canAddSongs)).toList(),
    );
  }
}

class _YoutubePlaylistTile extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final SongAddCallback onAdd;
  final bool canAddSongs;
  const _YoutubePlaylistTile({required this.playlist, required this.onAdd, required this.canAddSongs});

  @override
  State<_YoutubePlaylistTile> createState() => _YoutubePlaylistTileState();
}

class _YoutubePlaylistTileState extends State<_YoutubePlaylistTile> {
  List<Map<String, dynamic>>? _items; // null until first expanded
  bool _loading = false;

  Future<void> _loadItems() async {
    if (_items != null || _loading) return;
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/youtube/playlists/${widget.playlist['id']}/items');
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

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      onExpansionChanged: (open) {
        if (open) _loadItems();
      },
      title: Text(widget.playlist['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13)),
      subtitle: Text('${widget.playlist['itemCount'] ?? 0} videos', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
      iconColor: AppColors.textDim,
      collapsedIconColor: AppColors.textDim,
      children: [
        if (_loading) const Padding(padding: EdgeInsets.all(8), child: Spinner(size: 18)),
        ...?_items?.map((v) => ListTile(
              dense: true,
              title: Text(v['title'] as String? ?? 'Untitled', style: const TextStyle(color: AppColors.textDim, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: widget.canAddSongs
                  ? TextButton(
                      onPressed: () => widget.onAdd(
                        videoUrl: 'https://www.youtube.com/watch?v=${v['videoId']}',
                        title: v['title'] as String? ?? '',
                        thumbnail: v['thumbnail'] as String?,
                        mediaMode: 'video',
                      ),
                      child: const Text('+ Add', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    )
                  : null,
            )),
      ],
    );
  }
}
