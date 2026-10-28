import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';
import 'post_detail_screen.dart';

/// Saved posts: collection cards (All posts, Reels, your own collections)
/// above a 3-column grid. Long-press a post to move it into a collection.
/// Bookmarks are private (GET /feed/saved, /feed/saved/collections).
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  bool _loading = true;
  List<Post> _posts = [];
  final Map<String, String?> _collectionOf = {};
  Map<String, dynamic> _summary = const {
    'all': 0,
    'reels': 0,
    'collections': []
  };
  // null = All posts, '__reels' = Reels, otherwise a collection name.
  String? _view;

  static const _reels = '__reels';

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get _collectionNames => [
        for (final c in (_summary['collections'] as List).cast<Map>())
          c['name'] as String
      ];

  Future<void> _load() async {
    try {
      final named = _view != null && _view != _reels;
      final results = await Future.wait([
        ApiClient.get(named
            ? '/feed/saved?collection=${Uri.encodeQueryComponent(_view!)}'
            : '/feed/saved'),
        ApiClient.get('/feed/saved/collections'),
      ]);
      if (!mounted) return;
      final list = (results[0] as List).cast<Map<String, dynamic>>();
      setState(() {
        _posts = list.map(Post.fromJson).toList();
        for (final m in list) {
          _collectionOf[m['id'] as String] = m['savedCollection'] as String?;
        }
        _summary = Map<String, dynamic>.from(results[1] as Map);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String? view) {
    setState(() {
      _view = view;
      _loading = true;
    });
    _load();
  }

  Future<String?> _askName() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'e.g. Movie picks'),
            onSubmitted: (v) => Navigator.of(d).pop(v.trim())),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(c.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
  }

  Future<void> _newCollection() async {
    final name = await _askName();
    if (name == null || name.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Long-press any saved post to add it to “$name”.')));
    setState(() => _pendingName = name);
  }

  // A collection you just named, offered first in the move sheet.
  String? _pendingName;

  Future<void> _move(Post p) async {
    final current = _collectionOf[p.id];
    final names = {
      if (_pendingName != null) _pendingName!,
      ..._collectionNames,
    }.toList();
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text('Move to collection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final n in names)
            ListTile(
              leading: const InIcon(InIcons.bookmark,
                  size: 20, color: AppColors.lilac),
              title: Text(n),
              trailing: n == current
                  ? const InIcon(InIcons.check,
                      size: 18, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.of(sheet).pop(n),
            ),
          ListTile(
            leading:
                const InIcon(InIcons.plus, size: 20, color: AppColors.lilac),
            title: const Text('New collection…'),
            onTap: () => Navigator.of(sheet).pop('__new'),
          ),
          if (current != null)
            ListTile(
              leading: const InIcon(InIcons.close,
                  size: 20, color: AppColors.textDim),
              title: const Text('Remove from collection'),
              onTap: () => Navigator.of(sheet).pop('__none'),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    String? target = pick;
    if (pick == '__new') {
      target = await _askName();
      if (target == null || target.isEmpty) return;
    }
    if (pick == '__none') target = null;
    try {
      await ApiClient.patch('/feed/saved/${p.id}',
          body: {'collection': target});
      _pendingName = null;
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  static const _placeholderGradients = [
    [Color(0xFFE0C79A), Color(0xFFC17F42)],
    [Color(0xFFE6D0F0), Color(0xFFC896DC)],
    [Color(0xFFE1EEDC), Color(0xFFC2E0B8)],
    [Color(0xFFD9C2E8), Color(0xFFA85CD6)],
  ];

  Widget _card(String title, int count, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Material(
          color: selected ? const Color(0xFF2B1640) : AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('$count saved',
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12)),
                  ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shown = _view == _reels
        ? _posts.where((p) => p.mediaType == 'reel').toList()
        : _posts;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Saved'), actions: [
        TextButton.icon(
          onPressed: _newCollection,
          icon: const InIcon(InIcons.plus, size: 16, color: AppColors.primary),
          label: const Text('New collection'),
        ),
      ]),
      body: Column(children: [
        SizedBox(
          // Card padding plus two lines of text at the current text size.
          height: 44 +
              MediaQuery.textScalerOf(context).scale(14) * 1.4 +
              MediaQuery.textScalerOf(context).scale(12) * 1.4,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: [
              _card('All posts', (_summary['all'] as num?)?.toInt() ?? 0,
                  _view == null, () => _open(null)),
              _card('Reels', (_summary['reels'] as num?)?.toInt() ?? 0,
                  _view == _reels, () => _open(_reels)),
              for (final c in (_summary['collections'] as List).cast<Map>())
                _card(c['name'] as String, (c['count'] as num).toInt(),
                    _view == c['name'], () => _open(c['name'] as String)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: Spinner())
              : shown.isEmpty
                  ? Center(
                      child: Text(
                          _view == null
                              ? 'Nothing saved yet.'
                              : 'Nothing in here yet.',
                          style: const TextStyle(color: AppColors.textFaint)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final p = shown[i];
                        final gradient = _placeholderGradients[
                            p.id.hashCode.abs() % _placeholderGradients.length];
                        return GestureDetector(
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) =>
                                      PostDetailScreen(postId: p.id)))
                              .then((_) => _load()),
                          onLongPress: () => _move(p),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (p.imageData != null)
                                AppImage(source: p.imageData, fit: BoxFit.cover)
                              else
                                Container(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: gradient))),
                              if (p.mediaType == 'video_link' ||
                                  p.mediaType == 'reel')
                                const Positioned(
                                    top: 6,
                                    right: 6,
                                    child: InIcon(InIcons.play,
                                        filled: true,
                                        color: Colors.white,
                                        size: 16)),
                              if (p.mediaType == 'poll')
                                const Positioned(
                                    top: 6,
                                    right: 6,
                                    child: InIcon(InIcons.chart,
                                        color: Colors.white, size: 16)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
