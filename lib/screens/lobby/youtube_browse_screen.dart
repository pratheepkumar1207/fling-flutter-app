import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/google_connect_gate.dart';
import '../../widgets/spinner.dart';
import 'watch_room_creator.dart';

/// Rave-style full-screen YouTube browse: Search (public, no sign-in
/// needed — same GET /youtube/search the old inline form used), Playlists
/// and Liked (need a connected Google account — see google_content_service
/// .dart and GET /youtube/playlists|liked). No "history" tab: YouTube's
/// API doesn't expose watch history to third parties at all, unlike
/// playlists/likes, so there's nothing to build there.
class YoutubeBrowseScreen extends StatefulWidget {
  final String visibility;
  final String? topic;

  /// When set, picking a video calls this instead of creating a room — the
  /// in-room "add to queue" path from the unified source picker (see
  /// SourcePickerBody in source_picker_screen.dart) reuses this same
  /// screen rather than duplicating YouTube search/playlists/liked.
  final void Function(Map<String, dynamic> item)? onSelectOverride;

  const YoutubeBrowseScreen({super.key, required this.visibility, this.topic, this.onSelectOverride});

  @override
  State<YoutubeBrowseScreen> createState() => _YoutubeBrowseScreenState();
}

class _YoutubeBrowseScreenState extends State<YoutubeBrowseScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  bool _creatingRoom = false;

  void _selectVideo(Map<String, dynamic> item) {
    if (_creatingRoom) return;
    if (widget.onSelectOverride != null) {
      widget.onSelectOverride!(item);
      return;
    }
    setState(() => _creatingRoom = true);
    createWatchRoomAndEnter(
      context,
      sourceType: 'youtube',
      videoUrl: 'https://www.youtube.com/watch?v=${item['videoId']}',
      visibility: widget.visibility,
      topic: widget.topic,
      videoTitle: item['title'] as String?,
      videoThumbnail: item['thumbnail'] as String?,
    ).whenComplete(() {
      if (mounted) setState(() => _creatingRoom = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('YouTube'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Search'), Tab(text: 'Playlists'), Tab(text: 'Liked')],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _SearchTab(onSelect: _selectVideo),
              _PlaylistsTab(onSelect: _selectVideo),
              _VideoListTab(endpoint: '/youtube/liked', emptyLabel: 'No liked videos found.', onSelect: _selectVideo),
            ],
          ),
          if (_creatingRoom) Container(color: Colors.black45, alignment: Alignment.center, child: const Spinner()),
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

// ---------- Search (public API key, no Google account needed) ----------
class _SearchTab extends StatefulWidget {
  final void Function(Map<String, dynamic> item) onSelect;
  const _SearchTab({required this.onSelect});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final data = await ApiClient.get('/youtube/search?q=${Uri.encodeQueryComponent(q)}');
      if (!mounted) return;
      setState(() => _results = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _queryController,
            onChanged: _onChanged,
            autofocus: true,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: 'Search YouTube for a video…'),
          ),
        ),
        if (_searching) const Padding(padding: EdgeInsets.all(8), child: Spinner(size: 18)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _results.map((item) => _VideoTile(item: item, onTap: () => widget.onSelect(item))).toList(),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }
}

// ---------- Playlists (needs a connected Google account) ----------
class _PlaylistsTab extends StatefulWidget {
  final void Function(Map<String, dynamic> item) onSelect;
  const _PlaylistsTab({required this.onSelect});

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  Map<String, dynamic>? _openPlaylist; // {id, title} once drilled in

  @override
  Widget build(BuildContext context) {
    if (_openPlaylist != null) {
      return Column(
        children: [
          ListTile(
            leading: const BackButtonIcon(),
            onTap: () => setState(() => _openPlaylist = null),
            title: Text(_openPlaylist!['title'] as String? ?? 'Playlist', style: const TextStyle(color: AppColors.text)),
          ),
          Expanded(
            child: _VideoListTab(
              key: ValueKey(_openPlaylist!['id']),
              endpoint: '/youtube/playlists/${_openPlaylist!['id']}/items',
              emptyLabel: 'This playlist is empty.',
              onSelect: widget.onSelect,
            ),
          ),
        ],
      );
    }
    return GoogleConnectGate(
      child: _EntityList(
        endpoint: '/youtube/playlists',
        emptyLabel: 'No playlists found.',
        itemBuilder: (item) => _PlaylistTile(item: item, onTap: () => setState(() => _openPlaylist = item)),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _PlaylistTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 44,
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: item['thumbnail'] != null ? AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('🎵')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${item['itemCount'] ?? 0} videos', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

// ---------- Liked videos (needs a connected Google account) ----------
class _VideoListTab extends StatelessWidget {
  final String endpoint;
  final String emptyLabel;
  final void Function(Map<String, dynamic> item) onSelect;
  const _VideoListTab({super.key, required this.endpoint, required this.emptyLabel, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GoogleConnectGate(
      child: _EntityList(
        endpoint: endpoint,
        emptyLabel: emptyLabel,
        itemBuilder: (item) => _VideoTile(item: item, onTap: () => onSelect(item)),
      ),
    );
  }
}

// ---------- Shared bits ----------

/// Generic "GET a list from `endpoint`, render each item via itemBuilder"
/// — shared by playlists and liked-videos, which only differ in endpoint
/// and how each row renders.
class _EntityList extends StatefulWidget {
  final String endpoint;
  final String emptyLabel;
  final Widget Function(Map<String, dynamic> item) itemBuilder;
  const _EntityList({required this.endpoint, required this.emptyLabel, required this.itemBuilder});

  @override
  State<_EntityList> createState() => _EntityListState();
}

class _EntityListState extends State<_EntityList> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.get(widget.endpoint);
      if (!mounted) return;
      setState(() => _items = (data as List).cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Spinner());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)));
    if (_items.isEmpty) return Center(child: Text(widget.emptyLabel, style: const TextStyle(color: AppColors.textFaint)));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _items.map(widget.itemBuilder).toList(),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _VideoTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 44,
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: item['thumbnail'] != null ? AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('📺')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (item['channelTitle'] != null) Text(item['channelTitle'] as String, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
