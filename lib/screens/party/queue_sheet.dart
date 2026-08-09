import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';

/// Consolidated queue + song-discovery screen — combines the web app's
/// QueueSheet (search + reorderable queue) and SongDiscoveryScreen
/// (Search/Liked/History/Playlist tabs) into one screen with the queue
/// always visible at the bottom, search/liked/history/playlists as tabs
/// above it. Search stays the first tab per the "search tab on top" spec.
class QueueSheetScreen extends StatefulWidget {
  final Map<String, dynamic> queue;
  final bool isHost;
  final int participantCount;
  final void Function(Map<String, dynamic> item) onAdd;
  final void Function(int index) onJump;
  final void Function(int index) onRemove;
  final void Function(int fromIndex, int toIndex) onReorder;
  final VoidCallback onOpenRoster;
  final bool audioOnly;
  final bool canPin;
  final bool canAddSongs;

  const QueueSheetScreen({
    super.key,
    required this.queue,
    required this.isHost,
    required this.participantCount,
    required this.onAdd,
    required this.onJump,
    required this.onRemove,
    required this.onReorder,
    required this.onOpenRoster,
    this.audioOnly = false,
    bool? canPin,
    this.canAddSongs = true,
  }) : canPin = canPin ?? isHost;

  @override
  State<QueueSheetScreen> createState() => _QueueSheetScreenState();
}

class _QueueSheetScreenState extends State<QueueSheetScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _addToQueue({required String videoUrl, required String title, String? thumbnail, required String mediaMode, String sourceType = 'youtube'}) {
    widget.onAdd({'sourceType': sourceType, 'videoUrl': videoUrl, 'title': title, 'thumbnail': thumbnail, 'mediaMode': widget.audioOnly ? 'audio' : mediaMode});
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.queue['items'] as List?) ?? [];
    final currentIndex = widget.queue['currentIndex'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Queue'),
        actions: [
          TextButton(
            onPressed: widget.onOpenRoster,
            child: Text('👥 ${widget.participantCount}', style: const TextStyle(color: AppColors.textDim)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textFaint,
          tabs: const [Tab(text: 'Search'), Tab(text: 'Liked'), Tab(text: 'History'), Tab(text: 'Playlists')],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                _SearchTab(onAdd: _addToQueue, audioOnly: widget.audioOnly, canAddSongs: widget.canAddSongs),
                _SongListTab(endpoint: '/liked-songs', onAdd: _addToQueue, canAddSongs: widget.canAddSongs),
                _SongListTab(endpoint: '/song-history', onAdd: _addToQueue, canAddSongs: widget.canAddSongs),
                _PlaylistsTab(onAdd: _addToQueue, canAddSongs: widget.canAddSongs),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Queue', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                Text('${items.length} item${items.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Nothing queued yet.', style: TextStyle(color: AppColors.textFaint)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    onReorder: widget.isHost
                        ? (from, to) {
                            final adjustedTo = to > from ? to - 1 : to;
                            widget.onReorder(from, adjustedTo);
                          }
                        : (_, __) {},
                    itemBuilder: (context, i) {
                      final item = Map<String, dynamic>.from(items[i] as Map);
                      final isCurrent = i == currentIndex;
                      return Container(
                        key: ValueKey('queue-$i-${item['videoUrl']}'),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                          border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            if (widget.isHost) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.drag_handle, color: AppColors.textFaint, size: 18)),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                              clipBehavior: Clip.antiAlias,
                              child: item['thumbnail'] != null ? AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('📺')),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'] as String? ?? 'Video', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (isCurrent || item['mediaMode'] == 'audio')
                                    Text(
                                      [if (isCurrent) 'Now playing', if (item['mediaMode'] == 'audio') '🎧 Audio only'].join(' · '),
                                      style: const TextStyle(color: AppColors.primary, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            if (!isCurrent && widget.canPin)
                              TextButton(onPressed: () => widget.onJump(i), child: const Text('Play', style: TextStyle(fontSize: 11))),
                            if (!isCurrent && widget.isHost)
                              IconButton(onPressed: () => widget.onRemove(i), icon: const Icon(Icons.close, color: AppColors.danger, size: 16)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _SearchTab extends StatefulWidget {
  final void Function({required String videoUrl, required String title, String? thumbnail, required String mediaMode}) onAdd;
  final bool audioOnly;
  final bool canAddSongs;
  const _SearchTab({required this.onAdd, this.audioOnly = false, this.canAddSongs = true});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final data = await ApiClient.get('/youtube/search?q=${Uri.encodeQueryComponent(q)}');
      if (!mounted) return;
      setState(() {
        _results = (data as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: 'Search YouTube for a song or video…'),
          ),
        ),
        if (_searching) const Padding(padding: EdgeInsets.all(8), child: Spinner(size: 20)),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final item = _results[i];
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
                      child: item['thumbnail'] != null ? AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('📺')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(item['channelTitle'] as String? ?? '', style: const TextStyle(color: AppColors.textFaint, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (widget.canAddSongs)
                      widget.audioOnly
                          ? _smallButton('🎧 + Add', () => widget.onAdd(
                                videoUrl: 'https://www.youtube.com/watch?v=${item['videoId']}',
                                title: item['title'] as String? ?? '',
                                thumbnail: item['thumbnail'] as String?,
                                mediaMode: 'audio',
                              ))
                          : Column(
                              children: [
                                _smallButton('+ Video', () => widget.onAdd(
                                      videoUrl: 'https://www.youtube.com/watch?v=${item['videoId']}',
                                      title: item['title'] as String? ?? '',
                                      thumbnail: item['thumbnail'] as String?,
                                      mediaMode: 'video',
                                    )),
                                const SizedBox(height: 4),
                                _smallButton('🎧 Audio', () => widget.onAdd(
                                      videoUrl: 'https://www.youtube.com/watch?v=${item['videoId']}',
                                      title: item['title'] as String? ?? '',
                                      thumbnail: item['thumbnail'] as String?,
                                      mediaMode: 'audio',
                                    )),
                              ],
                            ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _smallButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

class _SongListTab extends StatefulWidget {
  final String endpoint;
  final void Function({required String videoUrl, required String title, String? thumbnail, required String mediaMode}) onAdd;
  final bool canAddSongs;
  const _SongListTab({required this.endpoint, required this.onAdd, this.canAddSongs = true});

  @override
  State<_SongListTab> createState() => _SongListTabState();
}

class _SongListTabState extends State<_SongListTab> {
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
                  onPressed: () => widget.onAdd(videoUrl: s.videoUrl ?? '', title: s.title ?? '', thumbnail: s.thumbnail, mediaMode: 'video'),
                  child: const Text('+ Add', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaylistsTab extends StatefulWidget {
  final void Function({required String videoUrl, required String title, String? thumbnail, required String mediaMode}) onAdd;
  final bool canAddSongs;
  const _PlaylistsTab({required this.onAdd, this.canAddSongs = true});

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
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
        if (_playlists.isEmpty) const Text('No playlists yet.', style: TextStyle(color: AppColors.textFaint)),
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
                              onPressed: () => widget.onAdd(videoUrl: s.videoUrl ?? '', title: s.title ?? '', thumbnail: s.thumbnail, mediaMode: 'video'),
                              child: const Text('+ Add', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            )
                          : null,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
