import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../core/youtube_util.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/mention_text_field.dart';
import '../../widgets/post_likes_sheet.dart';
import '../../widgets/share_row.dart';
import '../../widgets/spinner.dart';
import 'package:url_launcher/url_launcher.dart';

/// Single-post view — matches PostDetailDark.dc.html. New GET /feed/:id
/// backend endpoint added alongside this; comments reuse the same
/// GET/POST /feed/:id/comments the feed's bottom-sheet comments already
/// use, just rendered inline instead of in a sheet since this screen has
/// nothing else competing for vertical space.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _loading = true;
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = true;
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/feed/${widget.postId}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _post = Post.fromJson(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadComments() async {
    try {
      final data = await ApiClient.get('/feed/${widget.postId}/comments');
      if (!mounted) return;
      setState(() {
        _comments = (data as List).cast<Map<String, dynamic>>();
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    setState(() {
      _post = Post(
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
    });
    try {
      await ApiClient.post('/feed/${widget.postId}/like');
    } catch (_) {
      _load();
    }
  }

  Future<void> _toggleSave() async {
    final post = _post;
    if (post == null) return;
    setState(() {
      _post = Post(
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
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        likedByMe: post.likedByMe,
        savedByMe: !post.savedByMe,
        isOwn: post.isOwn,
        createdAt: post.createdAt,
      );
    });
    try {
      await ApiClient.post('/feed/${widget.postId}/save');
    } catch (_) {
      _load();
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post('/feed/${widget.postId}/comments', body: {'text': text});
      _controller.clear();
      await _loadComments();
      final post = _post;
      if (post != null) {
        setState(() {
          _post = Post(
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
            likesCount: post.likesCount,
            commentsCount: post.commentsCount + 1,
            likedByMe: post.likedByMe,
            savedByMe: post.savedByMe,
            isOwn: post.isOwn,
            createdAt: post.createdAt,
          );
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Post')),
      body: _loading
          ? const Center(child: Spinner())
          : post == null
              ? const Center(child: Text('Post not found.', style: TextStyle(color: AppColors.textFaint)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          GestureDetector(
                            onTap: () => openProfile(context, post.author.id),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                              child: Row(
                                children: [
                                  Avatar(src: post.author.avatarUrl, name: post.author.name, size: AvatarSize.sm),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(post.author.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5))),
                                  Text(formatRelativeTime(post.createdAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          if (post.imageData != null) AspectRatio(aspectRatio: 1, child: AppImage(source: post.imageData, fit: BoxFit.cover)),
                          if (post.mediaType == 'video_link' && post.videoUrl != null) _videoLinkTile(post.videoUrl!),
                          if (post.mediaType == 'voice' && post.voiceData != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                                child: const Row(children: [Icon(Icons.graphic_eq, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('Voice note', style: TextStyle(color: AppColors.textDim, fontSize: 12))]),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _toggleLike,
                                  child: Icon(post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: post.likedByMe ? AppColors.danger : AppColors.text, size: 24),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.mode_comment_outlined, color: AppColors.text, size: 23),
                                const SizedBox(width: 16),
                                ShareRow(text: post.text),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _toggleSave,
                                  child: Icon(post.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: AppColors.text, size: 22),
                                ),
                              ],
                            ),
                          ),
                          if (post.likesCount > 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: GestureDetector(
                                onTap: () => showPostLikesSheet(context, postId: post.id),
                                child: Text('${post.likesCount} likes', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ),
                          if (post.text != null && post.text!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                              child: RichText(
                                text: TextSpan(children: [
                                  TextSpan(text: '${post.author.name}  ', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
                                  TextSpan(text: post.text!, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                                ]),
                              ),
                            ),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 4),
                          if (_commentsLoading)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Spinner(size: 20)))
                          else if (_comments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('No comments yet.', style: TextStyle(color: AppColors.textFaint, fontSize: 13))),
                            )
                          else
                            ..._comments.map(_commentRow),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                        child: Row(
                          children: [
                            Expanded(child: MentionTextField(controller: _controller, hintText: 'Add a comment…')),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sending ? null : _sendComment,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(gradient: LinearGradient(colors: AppGradients.brand), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: _sending ? const Spinner(size: 16) : const Icon(Icons.send_rounded, color: Colors.white, size: 17),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _videoLinkTile(String url) {
    final youtubeId = extractYouTubeId(url);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              image: youtubeId != null ? DecorationImage(image: NetworkImage('https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'), fit: BoxFit.cover) : null,
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

  Widget _commentRow(Map<String, dynamic> c) {
    final author = c['author'] as Map?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: author?['name'] as String?, size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: '${author?['name'] ?? 'Unknown'}  ', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    TextSpan(text: c['text'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
                  ]),
                ),
                const SizedBox(height: 2),
                Text(formatRelativeTime(DateTime.tryParse(c['createdAt']?.toString() ?? '') ?? DateTime.now()), style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
