import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../widgets/insync_clay.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../core/youtube_util.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/post_composer_sheet.dart';
import '../../widgets/post_likes_sheet.dart';
import '../../widgets/reels_feed.dart';
import '../../widgets/share_row.dart';
import '../../widgets/spinner.dart';
import '../../widgets/story_bar.dart';
import '../../widgets/story_viewer_screen.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/report_user_sheet.dart';
import 'hashtag_screen.dart';
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
        _posts = (data as List)
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      for (final post in _posts) {
        if (post.mediaType == 'poll' && post.myVote != null) {
          _loadPollResults(post.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStories() async {
    try {
      final data = await ApiClient.get('/feed/stories');
      if (!mounted) return;
      setState(() => _stories = (data as List)
          .map((e) => StoryEntry.fromJson(e as Map<String, dynamic>))
          .toList());
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
          likesCount:
              post.likedByMe ? post.likesCount - 1 : post.likesCount + 1,
          commentsCount: post.commentsCount,
          likedByMe: !post.likedByMe,
          savedByMe: post.savedByMe,
          isOwn: post.isOwn,
          likesHidden: post.likesHidden,
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
      final data =
          await ApiClient.get('/feed/$postId/results') as Map<String, dynamic>;
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
          likesHidden: post.likesHidden,
          createdAt: post.createdAt,
        );
      }
    });
    try {
      await ApiClient.post('/feed/${post.id}/vote',
          body: {'optionIndex': optionIndex});
      _loadPollResults(post.id);
    } catch (_) {
      _load();
    }
  }

  Post _flipped(Post post, {bool like = false, bool save = false}) => Post(
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
        likesCount: like
            ? (post.likedByMe ? post.likesCount - 1 : post.likesCount + 1)
            : post.likesCount,
        commentsCount: post.commentsCount,
        likedByMe: like ? !post.likedByMe : post.likedByMe,
        savedByMe: save ? !post.savedByMe : post.savedByMe,
        isOwn: post.isOwn,
        likesHidden: post.likesHidden,
        createdAt: post.createdAt,
      );

  // Full-screen reels; likes/saves made there update this feed too.
  void _openReels() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReelsScreen(
        reels: _reels,
        onLike: (post) async {
          final next = _flipped(post, like: true);
          await _toggleLike(post);
          return next;
        },
        onSave: (post) async {
          try {
            await ApiClient.post('/feed/${post.id}/save');
            _load();
            return _flipped(post, save: true);
          } catch (_) {
            _snack('Failed to save post');
            return null;
          }
        },
        onOpenComments: _openComments,
        onCreate: () => showPostComposerSheet(context, onPosted: _load),
      ),
    ));
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // "Your story" leading tile — was entirely missing before (StoryBar was
  // only ever given `stories`, no way to add one), matches
  // HomeFeedDark.dc.html's dashed-ring + gradient-plus-badge tile.
  Widget _yourStoryTile() {
    final user = context.watch<AuthProvider>().user;
    return GestureDetector(
      onTap: () => showPostComposerSheet(context, onPosted: () {
        _load();
        _loadStories();
      }, initialIsStory: true),
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
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.border,
                            width: 1.5,
                            style: BorderStyle.solid)),
                    padding: const EdgeInsets.all(6),
                    child: Avatar(
                        src: user?.avatarUrl,
                        name: user?.name,
                        size: AvatarSize.md),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            const LinearGradient(colors: AppGradients.brand),
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('Your story',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _openStoryViewer(StoryEntry entry) {
    final index = _stories.indexWhere((s) => s.userId == entry.userId);
    if (index == -1) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            StoryViewerScreen(groups: _stories, startGroupIndex: index)));
  }

  void _openPostDetail(Post post) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: post.id)))
        .then((_) => _load());
  }

  void _openComments(Post post) {
    showCommentsSheet(context,
        postId: post.id,
        onCommented: _load,
        commentsDisabled: post.commentsDisabled && !post.isOwn,
        authorName: post.author.name);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              const InsyncSectionBanner(
                  title: 'In the loop',
                  subtitle: 'Little moments from your people.',
                  icon: Icons.auto_awesome_rounded),
              StoryBar(
                  stories: _stories,
                  onOpen: _openStoryViewer,
                  leading: _yourStoryTile()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: insyncClay(radius: 22),
                      child: Row(
                        children: [
                          _tabButton('posts', 'Posts'),
                          _tabButton('reels', 'Reels', onTap: _openReels),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () =>
                        showPostComposerSheet(context, onPosted: _load),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          gradient: AppGradients.volaCtaDiagonal,
                          borderRadius: BorderRadius.circular(999)),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Post',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ]),
                    ),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
                child: Padding(padding: EdgeInsets.all(24), child: Spinner()))
          else ...[
            if (_regularPosts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                      'Your feed is empty.\nFollow people or add friends to see their posts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textFaint)),
                ),
              )
            else
              ..._regularPosts.map((post) => _postCard(post)),
          ],
        ],
      ),
    );
  }

  List<Post> get _regularPosts =>
      _posts.where((p) => p.mediaType != 'reel').toList();
  List<Post> get _reels => _posts.where((p) => p.mediaType == 'reel').toList();

  Widget _tabButton(String key, String label, {VoidCallback? onTap}) {
    final selected = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              gradient: selected ? AppGradients.volaCtaDiagonal : null,
              borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppColors.textDim,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      ),
    );
  }

  // #tags and @mentions in captions stand out (tappable once hashtag
  // pages land); the rest of the caption is plain.
  List<InlineSpan> _captionSpans(String text) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'([#@][\w]{2,40})');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      spans.add(TextSpan(
          text: token,
          style: const TextStyle(color: Color(0xFF6F9BFF)),
          recognizer: token.startsWith('#')
              ? (TapGestureRecognizer()
                ..onTap = () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HashtagScreen(tag: token.substring(1)))))
              : null));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  Future<void> _postAction(Future<dynamic> Function() call, String done,
      {bool reload = true}) async {
    try {
      await call();
      _snack(done);
      if (reload) _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Something went wrong');
    }
  }

  Future<void> _setOption(Post post, Map<String, dynamic> body, String done) =>
      _postAction(
          () => ApiClient.patch('/feed/${post.id}/options', body: body), done);

  // Repost to your followers, or (toStory) share it into your story.
  void _repost(Post post, {bool toStory = false}) {
    showPostComposerSheet(context, onPosted: () {
      _load();
      _loadStories();
    }, initialIsStory: toStory, repostOf: {
      'id': post.id,
      'text': post.text,
      'imageData': post.imageData,
      'author': {'id': post.author.id, 'name': post.author.name},
    });
  }

  void _postMenu(Post post) {
    Widget tile(IconData icon, String label, VoidCallback onTap,
            {bool danger = false}) =>
        ListTile(
          leading:
              Icon(icon, color: danger ? AppColors.danger : AppColors.text),
          title: Text(label,
              style:
                  TextStyle(color: danger ? AppColors.danger : AppColors.text)),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final (icon, label, action) in [
                      (
                        post.savedByMe
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        post.savedByMe ? 'Unsave' : 'Save',
                        () => _toggleSave(post)
                      ),
                      (Icons.repeat_rounded, 'Repost', () => _repost(post)),
                      (
                        Icons.add_circle_outline_rounded,
                        'Add to story',
                        () => _repost(post, toStory: true)
                      ),
                      (
                        Icons.link_rounded,
                        'Link',
                        () {
                          Clipboard.setData(ClipboardData(
                              text: '${ApiClient.baseUrl}/feed/${post.id}'));
                          _snack('Link copied');
                        }
                      ),
                    ])
                      InkWell(
                        onTap: () {
                          Navigator.of(sheet).pop();
                          action();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(children: [
                            Icon(icon, color: AppColors.text),
                            const SizedBox(height: 4),
                            Text(label,
                                style: const TextStyle(
                                    color: AppColors.textDim, fontSize: 12)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (post.isOwn) ...[
                tile(Icons.archive_outlined, 'Archive',
                    () => _setOption(post, {'archived': true}, 'Archived')),
                tile(
                    post.hideLikes
                        ? Icons.favorite_border_rounded
                        : Icons.heart_broken_outlined,
                    post.hideLikes ? 'Show like count' : 'Hide like count',
                    () => _setOption(
                        post,
                        {'hideLikes': !post.hideLikes},
                        post.hideLikes
                            ? 'Like count shown'
                            : 'Like count hidden')),
                tile(
                    post.commentsDisabled
                        ? Icons.mode_comment_outlined
                        : Icons.comments_disabled_outlined,
                    post.commentsDisabled
                        ? 'Turn on comments'
                        : 'Turn off comments',
                    () => _setOption(
                        post,
                        {'commentsDisabled': !post.commentsDisabled},
                        post.commentsDisabled
                            ? 'Comments on'
                            : 'Comments off')),
              ] else ...[
                tile(
                    Icons.visibility_off_outlined,
                    'Not interested',
                    () => _postAction(
                        () => ApiClient.post('/feed/${post.id}/not-interested'),
                        'We\'ll show you fewer posts like this')),
                tile(
                    Icons.volume_off_outlined,
                    'Mute ${post.author.name}',
                    () => _postAction(
                        () => ApiClient.post('/mute/${post.author.id}'),
                        'Muted ${post.author.name} — change this from their profile')),
                tile(
                    Icons.person_remove_alt_1_outlined,
                    'Restrict',
                    () => _postAction(
                        () => ApiClient.post('/restrict/${post.author.id}'),
                        'Restricted — their comments on your posts are only visible to them',
                        reload: false)),
                tile(
                    Icons.person_off_outlined,
                    'Unfollow',
                    () => _postAction(
                        () => ApiClient.post(
                            '/social/unfollow/${post.author.id}'),
                        'Unfollowed ${post.author.name}')),
                tile(Icons.person_outline_rounded, 'Go to ${post.author.name}',
                    () => openProfile(context, post.author.id)),
                tile(
                    Icons.flag_outlined,
                    'Report',
                    () => showReportReasonSheet(context,
                        userName: post.author.name,
                        onSubmit: (reason) => _postAction(
                            () => ApiClient.post(
                                '/social/report/${post.author.id}',
                                body: {'reason': 'Post ${post.id}: $reason'}),
                            'Report submitted',
                            reload: false)),
                    danger: true),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Edge-to-edge, Instagram-style: header (ring avatar, name, ⋯), the media
  // full width, then actions, likes, caption, comments link and time —
  // separated by a hairline instead of a card.
  Widget _postCard(Post post) {
    const side = EdgeInsets.symmetric(horizontal: 14);
    final hasMedia = post.imageData != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 4, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => openProfile(context, post.author.id),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [
                        AppColors.accent,
                        AppColors.primary,
                        Color(0xFFFF5C8A),
                        AppColors.accent,
                      ]),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: AppColors.bg, shape: BoxShape.circle),
                      child: Avatar(
                          src: post.author.avatarUrl,
                          name: post.author.name,
                          size: AvatarSize.sm),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => openProfile(context, post.author.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: post.author.name),
                            if (post.collaborator != null)
                              TextSpan(
                                  text:
                                      ' and ${post.collaborator!['name'] ?? 'someone'}'),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5),
                        ),
                        if (post.location != null)
                          Text(post.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textFaint, fontSize: 11.5)),
                        if (post.repostOf != null)
                          Row(children: [
                            const Icon(Icons.repeat_rounded,
                                size: 12, color: AppColors.textFaint),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                  'Reposted from ${(post.repostOf!['author'] as Map?)?['name'] ?? 'someone'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textFaint,
                                      fontSize: 11.5)),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () => _postMenu(post),
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.textDim, size: 20),
                ),
              ],
            ),
          ),
          if (post.text != null && post.text!.isNotEmpty && !hasMedia)
            Padding(
              padding: side,
              child: Text.rich(
                TextSpan(children: _captionSpans(post.text!)),
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: post.mediaType == 'text' ? 16 : 14,
                    height: 1.45),
              ),
            ),
          if (hasMedia)
            _DoubleTapLike(
              liked: post.likedByMe,
              onLike: () => _toggleLike(post),
              onTap: () => _openPostDetail(post),
              child: SizedBox(
                width: double.infinity,
                child: AspectRatio(
                    aspectRatio: 1,
                    child: AppImage(source: post.imageData, fit: BoxFit.cover)),
              ),
            ),
          if (post.repostOf != null) _repostBlock(post.repostOf!),
          if (post.taggedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.person_pin_outlined,
                      size: 16, color: AppColors.textDim),
                  for (final t in post.taggedUsers)
                    GestureDetector(
                      onTap: () => openProfile(context, t['id'] as String?),
                      child: Text('@${t['username'] ?? t['name']}',
                          style: const TextStyle(
                              color: Color(0xFF6F9BFF), fontSize: 12.5)),
                    ),
                ],
              ),
            ),
          if (post.mediaType == 'voice' && post.voiceData != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(999)),
                child: const Row(children: [
                  Icon(Icons.graphic_eq, color: AppColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text('Voice note',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12))
                ]),
              ),
            ),
          if (post.mediaType == 'video_link' && post.videoUrl != null)
            _videoLinkTile(post.videoUrl!),
          if (post.mediaType == 'poll' && post.pollOptions != null)
            Padding(padding: side, child: _pollOptions(post)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Icon(
                      post.likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: post.likedByMe
                          ? const Color(0xFFFF5C8A)
                          : AppColors.text,
                      size: 25,
                      semanticLabel: post.likedByMe ? 'Unlike' : 'Like'),
                ),
                if (!post.commentsDisabled || post.isOwn) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _openComments(post),
                    child: const Icon(Icons.mode_comment_outlined,
                        color: AppColors.text,
                        size: 23,
                        semanticLabel: 'Comments'),
                  ),
                ],
                const SizedBox(width: 16),
                ShareRow(text: post.text),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleSave(post),
                  child: Icon(
                      post.savedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: AppColors.text,
                      size: 23,
                      semanticLabel: post.savedByMe ? 'Unsave' : 'Save'),
                ),
              ],
            ),
          ),
          if (!post.likesHidden && post.likesCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: GestureDetector(
                onTap: () => showPostLikesSheet(context, postId: post.id),
                child: Text(
                    '${post.likesCount} ${post.likesCount == 1 ? 'like' : 'likes'}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            )
          else if (post.likesHidden && post.likesCount > 0 && post.isOwn)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Text('${post.likesCount} likes · only you can see this',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 12)),
            ),
          if (post.text != null && post.text!.isNotEmpty && hasMedia)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${post.author.name}  ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  ..._captionSpans(post.text!),
                ]),
                style: const TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ),
          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: GestureDetector(
                onTap: () => _openComments(post),
                child: Text(
                    post.commentsCount == 1
                        ? 'View 1 comment'
                        : 'View all ${post.commentsCount} comments',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 12.5)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text(formatRelativeTime(post.createdAt),
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _repostBlock(Map<String, dynamic> r) {
    final author = r['author'] as Map?;
    final image = r['imageData'] as String?;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: r['id'] as String))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Avatar(
                    src: author?['avatarUrl'] as String?,
                    name: author?['name'] as String?,
                    size: AvatarSize.sm),
                const SizedBox(width: 8),
                Text(author?['name'] as String? ?? 'Someone',
                    style: const TextStyle(
                        color: AppColors.text, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (image != null)
              AspectRatio(
                  aspectRatio: 1,
                  child: AppImage(source: image, fit: BoxFit.cover)),
            if ((r['text'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(r['text'] as String,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _videoLinkTile(String url) {
    final youtubeId = extractYouTubeId(url);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              image: youtubeId != null
                  ? DecorationImage(
                      image: NetworkImage(
                          'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'),
                      fit: BoxFit.cover)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: GlassIcon.circle(
              size: 52,
              colors: const [AppColors.accent2, AppColors.primary],
              glowColor: AppColors.primary.withValues(alpha: 0.4),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 30),
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
          final pct = (voted && total > 0 && counts != null)
              ? ((counts[i] as int) / total * 100).round()
              : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: voted ? null : () => _votePoll(post, i),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border)),
                  ),
                  if (voted)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(
                            decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(options[i],
                            style: TextStyle(
                                color: post.myVote == i
                                    ? AppColors.primary
                                    : AppColors.text,
                                fontWeight: post.myVote == i
                                    ? FontWeight.w700
                                    : FontWeight.normal)),
                        if (voted)
                          Text('$pct%',
                              style: const TextStyle(
                                  color: AppColors.textFaint, fontSize: 12)),
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

/// Double-tap the photo to like it — a heart pops in the middle. Single
/// tap still opens the post. Double-tapping an already-liked post just
/// shows the heart again (it never unlikes, same as Instagram).
class _DoubleTapLike extends StatefulWidget {
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onTap;
  final Widget child;
  const _DoubleTapLike(
      {required this.liked,
      required this.onLike,
      required this.onTap,
      required this.child});

  @override
  State<_DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<_DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heart = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: () {
        if (!widget.liked) widget.onLike();
        _heart.forward(from: 0);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _heart,
            builder: (context, _) {
              final t = _heart.value;
              if (t == 0 || t == 1) return const SizedBox.shrink();
              final scale =
                  t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) : 1.0;
              final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
              return Opacity(
                opacity: opacity.clamp(0, 1).toDouble(),
                child: Transform.scale(
                  scale: scale,
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 96),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
