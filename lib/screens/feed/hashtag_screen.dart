import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/insync_clay.dart';
import '../profile/profile_post_grid.dart';

/// One hashtag's posts — Top, Recent and Reels — with a Follow button.
class HashtagScreen extends StatefulWidget {
  final String tag;
  const HashtagScreen({super.key, required this.tag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  static const _tabs = [
    ('top', 'Top'),
    ('recent', 'Recent'),
    ('reels', 'Reels')
  ];
  String _tab = 'top';
  final Map<String, List<Post>> _posts = {};
  int _total = 0;
  bool _following = false;
  bool _loading = true;

  String get _tag => widget.tag.replaceFirst('#', '').toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get(
              '/feed/hashtag/${Uri.encodeComponent(_tag)}?tab=$_tab')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _posts[_tab] = ((data['posts'] as List?) ?? [])
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _total = data['total'] as int? ?? 0;
        _following = data['following'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _following = !_following);
    try {
      final res = await ApiClient.post(
              '/feed/hashtag/${Uri.encodeComponent(_tag)}/follow')
          as Map<String, dynamic>;
      if (mounted) setState(() => _following = res['following'] == true);
    } catch (_) {
      if (mounted) setState(() => _following = !_following);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts[_tab] ?? const <Post>[];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: InsyncPageTitle('#$_tag')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: AppColors.surface2, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('#',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_total ${_total == 1 ? 'post' : 'posts'}',
                          style: const TextStyle(color: AppColors.textDim)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                          onPressed: _toggleFollow,
                          style: FilledButton.styleFrom(
                            backgroundColor: _following
                                ? AppColors.surface2
                                : AppColors.accent,
                            foregroundColor:
                                _following ? AppColors.text : AppColors.ink,
                          ),
                          child: Text(_following ? 'Following' : 'Follow'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final (key, label) in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _tab == key,
                      onSelected: (_) {
                        setState(() => _tab = key);
                        if (!_posts.containsKey(key)) _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading && posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ProfilePostGrid(
                      posts: posts,
                      reels: _tab == 'reels',
                      emptyText: 'No posts with #$_tag yet',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
