import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
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
import '../lobby/watch_room_creator.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'saved_posts_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
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
                        color: AppColors.primary,
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const InIcon(InIcons.plus,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Your story',
                    maxLines: 1,
                    style: TextStyle(color: AppColors.textDim, fontSize: 11))),
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
    return Stack(children: [
      RefreshIndicator(
        // Pull to refresh reloads stories too.
        onRefresh: () => Future.wait([_load(), _loadStories()]),
        child: ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: StoryBar(
                  stories: _stories,
                  onOpen: _openStoryViewer,
                  leading: _yourStoryTile()),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
              child: Row(children: [
                _chip('Posts', selected: true, onTap: () {}),
                _chip('Reels', icon: InIcons.reel, onTap: _openReels),
                _chip('Saved',
                    icon: InIcons.bookmark,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SavedPostsScreen()))),
              ]),
            ),
            if (_loading)
              const Center(
                  child: Padding(padding: EdgeInsets.all(24), child: Spinner()))
            else if (_regularPosts.isEmpty)
              const _EmptyFeed()
            else
              ..._regularPosts.map((post) => _postCard(post)),
          ],
        ),
      ),
      Positioned(
        right: 18,
        bottom: 18,
        child: Semantics(
          button: true,
          label: 'New post',
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            elevation: 3,
            shadowColor: Colors.black,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => showPostComposerSheet(context, onPosted: _load),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Center(
                    child: InIcon(InIcons.plus, size: 26, color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _chip(String label,
      {required VoidCallback onTap, InIconData? icon, bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null
            ? null
            : InIcon(icon,
                size: 15, color: selected ? Colors.white : AppColors.text),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w500),
        onSelected: (_) => onTap(),
      ),
    );
  }

  List<Post> get _regularPosts =>
      _posts.where((p) => p.mediaType != 'reel').toList();
  List<Post> get _reels => _posts.where((p) => p.mediaType == 'reel').toList();

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
          style: const TextStyle(color: AppColors.lilac),
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

  // "Watch in a room" for a shared YouTube link: opens a synced watch room
  // playing it. Uploaded reels can't do this yet — they're stored as
  // in-post data the room player can't stream.
  void _watchInRoom(String videoId) => createWatchRoomAndEnter(
        context,
        sourceType: 'youtube',
        videoUrl: 'https://www.youtube.com/watch?v=$videoId',
        visibility: 'public',
        videoThumbnail: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      );

  void _postMenu(Post post) {
    Widget tile(InIconData icon, String label, VoidCallback onTap,
            {bool danger = false}) =>
        ListTile(
          leading:
              InIcon(icon, color: danger ? AppColors.danger : AppColors.text),
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
                        post.savedByMe ? InIcons.bookmark : InIcons.bookmark,
                        post.savedByMe ? 'Unsave' : 'Save',
                        () => _toggleSave(post)
                      ),
                      (InIcons.repeat, 'Repost', () => _repost(post)),
                      (
                        InIcons.plus,
                        'Add to story',
                        () => _repost(post, toStory: true)
                      ),
                      if (extractYouTubeId(post.videoUrl) case final videoId?)
                        (InIcons.tv, 'Watch', () => _watchInRoom(videoId)),
                      (
                        InIcons.link,
                        'Link',
                        () {
                          Clipboard.setData(ClipboardData(
                              text: '${ApiClient.baseUrl}/p/${post.id}'));
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
                            InIcon(icon, color: AppColors.text),
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
                tile(InIcons.archive, 'Archive',
                    () => _setOption(post, {'archived': true}, 'Archived')),
                tile(
                    post.hideLikes ? InIcons.heart : InIcons.heart,
                    post.hideLikes ? 'Show like count' : 'Hide like count',
                    () => _setOption(
                        post,
                        {'hideLikes': !post.hideLikes},
                        post.hideLikes
                            ? 'Like count shown'
                            : 'Like count hidden')),
                tile(
                    post.commentsDisabled ? InIcons.comment : InIcons.comment,
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
                    InIcons.eyeoff,
                    'Not interested',
                    () => _postAction(
                        () => ApiClient.post('/feed/${post.id}/not-interested'),
                        'We\'ll show you fewer posts like this')),
                tile(
                    InIcons.mute,
                    'Mute ${post.author.name}',
                    () => _postAction(
                        () => ApiClient.post('/mute/${post.author.id}'),
                        'Muted ${post.author.name} — change this from their profile')),
                tile(
                    InIcons.block,
                    'Restrict',
                    () => _postAction(
                        () => ApiClient.post('/restrict/${post.author.id}'),
                        'Restricted — their comments on your posts are only visible to them',
                        reload: false)),
                tile(
                    InIcons.block,
                    'Unfollow',
                    () => _postAction(
                        () => ApiClient.post(
                            '/social/unfollow/${post.author.id}'),
                        'Unfollowed ${post.author.name}')),
                tile(InIcons.user, 'Go to ${post.author.name}',
                    () => openProfile(context, post.author.id)),
                tile(
                    InIcons.flame,
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
                            const InIcon(InIcons.repeat,
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
                InIconButton(InIcons.more,
                    tooltip: 'More',
                    iconSize: 20,
                    color: AppColors.textDim,
                    onPressed: () => _postMenu(post)),
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
                  const InIcon(InIcons.pin, size: 16, color: AppColors.textDim),
                  for (final t in post.taggedUsers)
                    GestureDetector(
                      onTap: () => openProfile(context, t['id'] as String?),
                      child: Text('@${t['username'] ?? t['name']}',
                          style: const TextStyle(
                              color: AppColors.lilac, fontSize: 12.5)),
                    ),
                ],
              ),
            ),
          if (post.mediaType == 'voice' && post.voiceData != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openPostDetail(post),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Row(children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.primary,
                      child: InIcon(InIcons.play,
                          size: 16, color: Colors.white, filled: true),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                        child: Row(children: [
                      InIcon(InIcons.wave, size: 22, color: AppColors.lilac),
                      InIcon(InIcons.wave, size: 22, color: AppColors.lilac),
                      InIcon(InIcons.wave, size: 22, color: AppColors.lilac),
                    ])),
                    Text('Voice note',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ]),
                ),
              ),
            ),
          if (post.mediaType == 'video_link' && post.videoUrl != null)
            _videoLinkTile(post.videoUrl!),
          if (post.mediaType == 'poll' && post.pollOptions != null)
            Padding(padding: side, child: _pollOptions(post)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                _action(
                  post.likedByMe ? 'Unlike' : 'Like',
                  InIcon(InIcons.heart,
                      size: 24,
                      filled: post.likedByMe,
                      color: post.likedByMe ? AppColors.pink : AppColors.text),
                  count: post.likesHidden ? null : post.likesCount,
                  onTap: () => _toggleLike(post),
                  onCountTap: () =>
                      showPostLikesSheet(context, postId: post.id),
                ),
                if (!post.commentsDisabled || post.isOwn)
                  _action(
                    'Comments',
                    const InIcon(InIcons.comment, size: 23),
                    count: post.commentsCount,
                    onTap: () => _openComments(post),
                  ),
                ShareRow(
                    text: post.text, url: '${ApiClient.baseUrl}/p/${post.id}'),
                const Spacer(),
                _action(
                  post.savedByMe ? 'Unsave' : 'Save',
                  InIcon(InIcons.bookmark, size: 22, filled: post.savedByMe),
                  onTap: () => _toggleSave(post),
                ),
              ],
            ),
          ),
          if (post.likesHidden && post.likesCount > 0 && post.isOwn)
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
              child: const InIcon(InIcons.play,
                  filled: true, color: Colors.white, size: 30),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                  ),
                  if (voted)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(
                            decoration: BoxDecoration(
                                color: const Color(0xFF3A1F5C),
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
                                  color: AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
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
                  child: const InIcon(InIcons.heart,
                      filled: true, color: Colors.white, size: 96),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Like / comment button with its count beside it.
Widget _action(String label, Widget icon,
    {int? count, required VoidCallback onTap, VoidCallback? onCountTap}) {
  final hasCount = count != null && count > 0;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, 8, hasCount ? 3 : 6, 8),
          child: icon,
        ),
      ),
    ),
    if (hasCount)
      Semantics(
        button: onCountTap != null,
        label: '$count',
        child: InkWell(
          onTap: onCountTap ?? onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 6, 8),
            child: Text('$count',
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
  ]);
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 40, 36, 0),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFF2A1028),
              borderRadius: BorderRadius.circular(21)),
          child: const Center(
              child: InIcon(InIcons.image, size: 30, color: AppColors.pink)),
        ),
        const SizedBox(height: 12),
        const Text('No posts yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
            'Follow people or add friends to see their posts here — or share your first one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
      ]),
    );
  }
}
