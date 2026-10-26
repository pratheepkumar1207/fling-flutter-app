import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/story_bar.dart';
import '../../widgets/story_viewer_screen.dart';

/// A story highlight on a profile — a named set of the owner's stories.
class Highlight {
  final String id;
  final String title;
  final List<StoryItem> items;
  const Highlight({required this.id, required this.title, required this.items});

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        items: ((j['items'] as List?) ?? [])
            .map((e) => StoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

Widget _storyThumb(StoryItem? item, double size) {
  if (item?.imageData != null) {
    return AppImage(source: item!.imageData, fit: BoxFit.cover);
  }
  return Container(
    color: AppColors.surface2,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(4),
    child: Text(
      item?.text?.isNotEmpty == true ? item!.text! : '★',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textDim, fontSize: size * 0.16),
    ),
  );
}

/// The row of highlight circles on a profile. On your own profile it ends
/// with "New", and long-pressing a highlight offers to delete it.
class HighlightsRow extends StatefulWidget {
  final String userId;
  final bool isMine;
  final String? ownerName;
  final String? ownerAvatar;
  const HighlightsRow(
      {super.key,
      required this.userId,
      required this.isMine,
      this.ownerName,
      this.ownerAvatar});

  @override
  State<HighlightsRow> createState() => _HighlightsRowState();
}

class _HighlightsRowState extends State<HighlightsRow> {
  List<Highlight> _highlights = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await ApiClient.get('/highlights/user/${widget.userId}') as List;
      if (!mounted) return;
      setState(() {
        _highlights = data
            .map((e) => Highlight.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _open(int index) {
    final groups = [
      for (final h in _highlights)
        StoryEntry(
            userId: widget.userId,
            name: h.title,
            avatarUrl: widget.ownerAvatar,
            items: h.items),
    ];
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            StoryViewerScreen(groups: groups, startGroupIndex: index)));
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const NewHighlightScreen()));
    if (created == true) _load();
  }

  Future<void> _delete(Highlight h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete "${h.title}"?'),
        content: const Text('The stories stay in your archive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.delete('/highlights/${h.id}');
      _load();
    } catch (_) {}
  }

  Widget _circle(Widget child, String label,
      {VoidCallback? onTap, VoidCallback? onLongPress, bool dashed = false}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: dashed ? AppColors.textFaint : AppColors.border,
                    width: 1.5),
              ),
              child: ClipOval(child: child),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || (_highlights.isEmpty && !widget.isMine)) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _highlights.length; i++)
            _circle(_storyThumb(_highlights[i].items.firstOrNull, 58),
                _highlights[i].title,
                onTap: () => _open(i),
                onLongPress:
                    widget.isMine ? () => _delete(_highlights[i]) : null),
          if (widget.isMine)
            _circle(
                const ColoredBox(
                    color: AppColors.bg,
                    child: InIcon(InIcons.plus, color: AppColors.text)),
                'New',
                onTap: _create,
                dashed: true),
        ],
      ),
    );
  }
}

/// Pick stories (expired ones too) and name the highlight.
class NewHighlightScreen extends StatefulWidget {
  const NewHighlightScreen({super.key});

  @override
  State<NewHighlightScreen> createState() => _NewHighlightScreenState();
}

class _NewHighlightScreenState extends State<NewHighlightScreen> {
  List<StoryItem> _stories = [];
  final List<String> _picked = [];
  final _title = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/feed/my-stories') as List;
      if (!mounted) return;
      setState(() {
        _stories = data
            .map((e) => StoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick at least one story and give it a name')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.post('/highlights',
          body: {'title': title, 'postIds': _picked});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : "Couldn't save")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('New highlight'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Done',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _title,
              maxLength: 30,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'Highlight name'),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stories.isEmpty
                    ? const Center(
                        child: Text('Post a story first, then add it here.',
                            style: TextStyle(color: AppColors.textFaint)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 2,
                                crossAxisSpacing: 2,
                                childAspectRatio: 9 / 16),
                        itemCount: _stories.length,
                        itemBuilder: (context, i) {
                          final s = _stories[i];
                          final order = _picked.indexOf(s.id);
                          return GestureDetector(
                            onTap: () => setState(() => order == -1
                                ? _picked.add(s.id)
                                : _picked.remove(s.id)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _storyThumb(s, 110),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: order == -1
                                          ? Colors.black38
                                          : AppColors.accent,
                                      border: Border.all(color: Colors.white),
                                    ),
                                    alignment: Alignment.center,
                                    child: order == -1
                                        ? null
                                        : Text('${order + 1}',
                                            style: const TextStyle(
                                                color: AppColors.ink,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                  ),
                                ),
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
}
