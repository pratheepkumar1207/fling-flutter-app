import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/google_connect_gate.dart';
import '../../widgets/spinner.dart';
import 'watch_room_creator.dart';

/// Rave-style full-screen Google Drive browse: breadcrumb folder
/// navigation + name search, backed by GET /drive/browse (the CALLING
/// user's own OAuth-connected Drive — see google_connect_gate.dart and
/// src/routes/drive.js). Selecting a video creates the room with just the
/// raw Drive file id as videoUrl; playback later streams through
/// GET /drive/stream/:fileId using the room HOST's stored OAuth token.
class DriveBrowseScreen extends StatefulWidget {
  final String visibility;
  final String? topic;

  /// When set, picking a file calls this instead of creating a room — used
  /// by the unified source picker's in-room "add to queue" path (see
  /// SourcePickerBody in source_picker_screen.dart).
  final void Function(Map<String, dynamic> item)? onSelectOverride;

  const DriveBrowseScreen({super.key, required this.visibility, this.topic, this.onSelectOverride});

  @override
  State<DriveBrowseScreen> createState() => _DriveBrowseScreenState();
}

class _DriveBrowseScreenState extends State<DriveBrowseScreen> {
  final List<Map<String, String>> _breadcrumbs = [
    {'id': 'root', 'name': 'My Drive'},
  ];
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  bool _creatingRoom = false;

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
      final params = _searchQuery.isNotEmpty
          ? 'q=${Uri.encodeQueryComponent(_searchQuery)}'
          : 'folderId=${Uri.encodeQueryComponent(_breadcrumbs.last['id']!)}';
      final data = await ApiClient.get('/drive/browse?$params');
      if (!mounted) return;
      setState(() => _items = (data as List).cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = q.trim());
      _load();
    });
  }

  void _openFolder(Map<String, dynamic> item) {
    setState(() {
      _breadcrumbs.add({'id': item['id'] as String, 'name': item['name'] as String? ?? ''});
      _searchController.clear();
      _searchQuery = '';
    });
    _load();
  }

  void _goToBreadcrumb(int index) {
    if (index == _breadcrumbs.length - 1 && _searchQuery.isEmpty) return;
    setState(() {
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      _searchController.clear();
      _searchQuery = '';
    });
    _load();
  }

  void _selectVideo(Map<String, dynamic> item) {
    if (_creatingRoom) return;
    if (widget.onSelectOverride != null) {
      widget.onSelectOverride!(item);
      return;
    }
    setState(() => _creatingRoom = true);
    createWatchRoomAndEnter(
      context,
      sourceType: 'drive',
      videoUrl: item['id'] as String,
      visibility: widget.visibility,
      topic: widget.topic,
      videoTitle: item['name'] as String?,
      videoThumbnail: item['thumbnail'] as String?,
    ).whenComplete(() {
      if (mounted) setState(() => _creatingRoom = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Google Drive')),
      body: GoogleConnectGate(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(hintText: 'Search your Drive…', prefixIcon: Icon(Icons.search, color: AppColors.textFaint)),
                  ),
                ),
                if (_searchQuery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < _breadcrumbs.length; i++) ...[
                          if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 14, color: AppColors.textFaint)),
                          GestureDetector(
                            onTap: () => _goToBreadcrumb(i),
                            child: Text(
                              _breadcrumbs[i]['name']!,
                              style: TextStyle(
                                color: i == _breadcrumbs.length - 1 ? AppColors.text : AppColors.primary,
                                fontSize: 12,
                                fontWeight: i == _breadcrumbs.length - 1 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Expanded(child: _buildList()),
              ],
            ),
            if (_creatingRoom) Container(color: Colors.black45, alignment: Alignment.center, child: const Spinner()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: Spinner());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)));
    if (_items.isEmpty) return const Center(child: Text('Nothing here.', style: TextStyle(color: AppColors.textFaint)));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _items.map((item) {
        final isFolder = item['type'] == 'folder';
        return GestureDetector(
          onTap: isFolder ? () => _openFolder(item) : () => _selectVideo(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Text(isFolder ? '📁' : '🎬', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(item['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isFolder) const Icon(Icons.chevron_right, color: AppColors.textFaint),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
