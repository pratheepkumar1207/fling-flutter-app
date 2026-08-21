import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../core/youtube_util.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/mention_text_field.dart';
import '../../widgets/post_composer_sheet.dart';
import '../../widgets/post_likes_sheet.dart';
import '../../widgets/reels_feed.dart';
import '../../widgets/share_row.dart';
import '../../widgets/spinner.dart';
import '../../widgets/story_bar.dart';
import '../../widgets/story_viewer_screen.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _tab = 'posts';
  bool _loading = true;
  List<Post> _posts = [];
  List<StoryEntry> _stories = [];
  final Map<String, Map<String, dynamic>> _pollResults = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadStories();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/feed');
      if (!mounted) return;
      setState(() {
        _posts = (data as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
      for (final post in _posts) {
        if (post.mediaType == 'poll' && post.myVote != null) _loadPollResults(post.id);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStories() async {
    try {
      final data = await ApiClient.get('/feed/stories');
      if (!mounted) return;
      setState(() => _stories = (data as List).map((e) => StoryEntry.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {
      // Stories are a non-critical preview strip — silently skip on failure.
    }
  }

  Future<void> _toggleLike(Post post) async {
    setState(() {
      final i = _posts.indexWhere((p) => p.id == post.id);
      if (i != -1) {
        _posts[i] = Post(
          id: post.id,
          author: post.author,
          mediaType: post.mediaType,
          text: post.text,
          imageData: post.imageData,
          voiceData: post.voiceData,
          videoUrl: post.videoUrl,
          videoData: post.videoData,
          pollOptions: post.pollOptions,
          myVote: post.myVote,
          likesCount: post.likedByMe ? post.likesCount - 1 : post.likesCount + 1,
          commentsCount: post.commentsCount,
          likedByMe: !post.likedByMe,
          savedByMe: post.savedByMe,
          isOwn: post.isOwn,
          createdAt: post.createdAt,
        );
      }
    });
    try {
      await ApiClient.post('/feed/${post.id}/like');
    } catch (_) {
      _load();
    }
  }

  Future<void> _loadPollResults(String postId) async {
    try {
      final data = await ApiClient.get('/feed/$postId/results') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _pollResults[postId] = data);
    } catch (_) {
      // Non-critical — vote buttons just won't show percentages yet.
    }
  }

  Future<void> _votePoll(Post post, int optionIndex) async {
    if (post.myVote != null) return;
    setState(() {
      final i = _posts.indexWhere((p) => p.id == post.id);
      if (i != -1) {
        _posts[i] = Post(
          id: post.id,
          author: post.author,
          mediaType: post.mediaType,
          text: post.text,
          pollOptions: post.pollOptions,
          myVote: optionIndex,
          likesCount: post.likesCount,
          commentsCount: post.commentsCount,
          likedByMe: post.likedByMe,
          savedByMe: post.savedByMe,
          isOwn: post.isOwn,
          createdAt: post.createdAt,
        );
      }
    });
    try {
      await ApiClient.post('/feed/${post.id}/vote', body: {'optionIndex': optionIndex});
      _loadPollResults(post.id);
    } catch (_) {
      _load();
    }
  }

  Future<void> _toggleSave(Post post) async {
    try {
      await ApiClient.post('/feed/${post.id}/save');
      _load();
    } catch (_) {
      _snack('Failed to save post');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // "Your story" leading tile — was entirely missing before (StoryBar was
  // only ever given `stories`, no way to add one), matches
  // HomeFeedDark.dc.html's dashed-ring + gradient-plus-badge tile.
  Widget _yourStoryTile() {
    final user = context.watch<AuthProvider>().user;
    return GestureDetector(
      onTap: () => showPostComposerSheet(context, onPosted: () { _load(); _loadStories(); }, initialIsStory: true),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5, style: BorderStyle.solid)),
                    padding: const EdgeInsets.all(6),
                    child: Avatar(src: user?.avatarUrl, name: user?.name, size: AvatarSize.md),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: AppGradients.brand),
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('Your story', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _openStoryViewer(StoryEntry entry) {
    final index = _stories.indexWhere((s) => s.userId == entry.userId);
    if (index == -1) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewerScreen(groups: _stories, startGroupIndex: index)));
  }

  void _openPostDetail(Post post) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id))).then((_) => _load());
  }

  void _openComments(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(postId: post.id, onCommented: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StoryBar(stories: _stories, onOpen: _openStoryViewer, leading: _yourStoryTile()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      _tabButton('posts', 'Posts'),
                      _tabButton('reels', 'Reels'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => showPostComposerSheet(context, onPosted: _load),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(gradient: AppGradients.volaCtaDiagonal, borderRadius: BorderRadius.circular(999)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Spinner()))
          else if (_tab == 'posts') ...[
            if (_regularPosts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Your feed is empty.\nFollow people or add friends to see their posts here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint)),
                ),
              )
            else
              ..._regularPosts.map((post) => _postCard(post)),
          ] else
            ReelsFeed(reels: _reels, onLike: _toggleLike, onOpenComments: _openComments, onSave: _toggleSave),
        ],
      ),
    );
  }

  List<Post> get _regularPosts => _posts.where((p) => p.mediaType != 'reel').toList();
  List<Post> get _reels => _posts.where((p) => p.mediaType == 'reel').toList();

  Widget _tabButton(String key, String label) {
    final selected = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(gradient: selected ? AppGradients.volaCtaDiagonal : null, borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textDim, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }

  // Flat, borderless card (no rounded container) with a hairline divider
  // between posts — matches the redesign's Instagram-style feed layout
  // instead of the previous bordered card.
  Widget _postCard(Post post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => openProfile(context, post.author.id),
            child: Row(
              children: [
                Avatar(src: post.author.avatarUrl, name: post.author.name, size: AvatarSize.sm),
                const SizedBox(width: 10),
                Expanded(child: Text(post.author.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5))),
                Text(formatRelativeTime(post.createdAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.more_horiz_rounded, color: AppColors.textFaint, size: 19),
              ],
            ),
          ),
          if (post.text != null && post.text!.isNotEmpty && post.imageData == null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(post.text!, style: const TextStyle(color: AppColors.text))),
          if (post.imageData != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: () => _openPostDetail(post),
                child: SizedBox(
                  width: double.infinity,
                  child: AspectRatio(aspectRatio: 1, child: AppImage(source: post.imageData, fit: BoxFit.cover)),
                ),
              ),
            ),
          if (post.mediaType == 'voice' && post.voiceData != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [Icon(Icons.graphic_eq, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('Voice note', style: TextStyle(color: AppColors.textDim, fontSize: 12))]),
              ),
            ),
          if (post.mediaType == 'video_link' && post.videoUrl != null) _videoLinkTile(post.videoUrl!),
          if (post.mediaType == 'poll' && post.pollOptions != null) _pollOptions(post),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Icon(post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: post.likedByMe ? AppColors.danger : AppColors.text, size: 24),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _openComments(post),
                  child: const Icon(Icons.mode_comment_outlined, color: AppColors.text, size: 23),
                ),
                const SizedBox(width: 16),
                ShareRow(text: post.text),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleSave(post),
                  child: Icon(post.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: AppColors.text, size: 22),
                ),
              ],
            ),
          ),
          if (post.likesCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => showPostLikesSheet(context, postId: post.id),
                child: Text('${post.likesCount} likes', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          if (post.text != null && post.text!.isNotEmpty && post.imageData != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '${post.author.name}  ', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
                    TextSpan(text: post.text!, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  ],
                ),
              ),
            ),
          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => _openPostDetail(post),
                child: Text('View all ${post.commentsCount} comments', style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _videoLinkTile(String url) {
    final youtubeId = extractYouTubeId(url);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              image: youtubeId != null
                  ? DecorationImage(image: NetworkImage('https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'), fit: BoxFit.cover)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: GlassIcon.circle(
              size: 52,
              colors: const [AppColors.accent2, AppColors.primary],
              glowColor: AppColors.primary.withValues(alpha: 0.4),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pollOptions(Post post) {
    final options = post.pollOptions!.cast<String>();
    final results = _pollResults[post.id];
    final counts = results?['counts'] as List?;
    final total = (results?['total'] as int?) ?? 0;
    final voted = post.myVote != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: List.generate(options.length, (i) {
          final pct = (voted && total > 0 && counts != null) ? ((counts[i] as int) / total * 100).round() : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: voted ? null : () => _votePoll(post, i),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  ),
                  if (voted)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(options[i], style: TextStyle(color: post.myVote == i ? AppColors.primary : AppColors.text, fontWeight: post.myVote == i ? FontWeight.w700 : FontWeight.normal)),
                        if (voted) Text('$pct%', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onCommented;
  const _CommentsSheet({required this.postId, required this.onCommented});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/feed/${widget.postId}/comments');
      if (!mounted) return;
      setState(() {
        _comments = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiClient.post('/feed/${widget.postId}/comments', body: {'text': text});
      _controller.clear();
      _load();
      widget.onCommented();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Comments', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold))),
            Expanded(
              child: _loading
                  ? const Center(child: Spinner())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _comments.length,
                      itemBuilder: (context, i) {
                        final c = _comments[i];
                        final author = c['author'] as Map?;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: '${author?['name'] ?? 'Unknown'}  ', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13)),
                                TextSpan(text: c['text'] as String? ?? '', style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: MentionTextField(controller: _controller, hintText: 'Add a comment… (@ to mention someone)')),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
