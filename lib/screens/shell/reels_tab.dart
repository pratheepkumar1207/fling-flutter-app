import 'package:flutter/material.dart';
import '../../widgets/insync_brand.dart';

import '../../core/api_client.dart';
import '../../models/post.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/reels_feed.dart';
import '../create/create_flow.dart';

/// The Reels tab: everyone's ranked reels, full screen, right in the tab.
/// Built only while the tab is showing (see AppShell), so videos stop when
/// you leave it.
class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key});

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> {
  List<Post>? _reels;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Post>> _page(int page) async {
    final data =
        await ApiClient.get('/feed/reels?page=$page') as Map<String, dynamic>;
    return (data['reels'] as List)
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final r = await _page(0);
      if (mounted) setState(() => _reels = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<Post?> _toggle(Post post, String action) async {
    try {
      await ApiClient.post('/feed/${post.id}/$action');
      return action == 'like'
          ? post.copyWith(
              likedByMe: !post.likedByMe,
              likesCount:
                  post.likedByMe ? post.likesCount - 1 : post.likesCount + 1)
          : post.copyWith(savedByMe: !post.savedByMe);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reels = _reels;
    if (reels == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: _failed
              ? TextButton(
                  onPressed: _load,
                  child: const Text("Couldn't load reels. Try again"))
              : const InsyncSpinner(size: 32),
        ),
      );
    }
    return ReelsScreen(
      reels: reels,
      loadPage: _page,
      showBack: false,
      onLike: (p) => _toggle(p, 'like'),
      onSave: (p) => _toggle(p, 'save'),
      onOpenComments: (post) => showCommentsSheet(context,
          postId: post.id,
          onCommented: () {},
          commentsDisabled: post.commentsDisabled && !post.isOwn,
          authorName: post.author.name),
      onCreate: () => openCreateFlow(context, mode: CreateMode.reel),
    );
  }
}
