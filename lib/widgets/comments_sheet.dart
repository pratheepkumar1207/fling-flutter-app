import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';
import 'mention_text_field.dart';
import 'spinner.dart';

/// Comments, Instagram-style: half-height sheet over the post/reel (which
/// keeps playing behind), each comment with a like count and Reply,
/// replies tucked under "View N more replies", a quick emoji row above the
/// box. Comments from people the author restricted are only visible to
/// those people (filtered server-side).
Future<void> showCommentsSheet(BuildContext context,
    {required String postId,
    required VoidCallback onCommented,
    bool commentsDisabled = false,
    String? authorName}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => CommentsSheet(
        postId: postId,
        onCommented: onCommented,
        commentsDisabled: commentsDisabled,
        authorName: authorName),
  );
}

class CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onCommented;
  final bool commentsDisabled;
  final String? authorName;
  const CommentsSheet(
      {super.key,
      required this.postId,
      required this.onCommented,
      this.commentsDisabled = false,
      this.authorName});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Map<String, dynamic>? _replyTo;
  final Set<String> _expanded = {};

  static const _emojis = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
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
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post('/feed/${widget.postId}/comments', body: {
        'text': text,
        if (_replyTo != null) 'parentId': _replyTo!['id'],
      });
      _controller.clear();
      final parent = _replyTo?['parentId'] ?? _replyTo?['id'];
      if (parent is String) _expanded.add(parent);
      setState(() => _replyTo = null);
      await _load();
      widget.onCommented();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(e is ApiException ? e.message : "Couldn't post comment")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> c) async {
    final liked = c['likedByMe'] == true;
    setState(() {
      c['likedByMe'] = !liked;
      c['likesCount'] = ((c['likesCount'] as int?) ?? 0) + (liked ? -1 : 1);
    });
    try {
      await ApiClient.post('/feed/comments/${c['id']}/like');
    } catch (_) {
      if (mounted) {
        setState(() {
          c['likedByMe'] = liked;
          c['likesCount'] = ((c['likesCount'] as int?) ?? 0) + (liked ? 1 : -1);
        });
      }
    }
  }

  void _reply(Map<String, dynamic> c) {
    final author = c['author'] as Map?;
    setState(() => _replyTo = c);
    final handle = author?['username'] as String?;
    if (handle != null && handle.isNotEmpty) {
      _controller.text = '@$handle ';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
    _focus.requestFocus();
  }

  Widget _comment(Map<String, dynamic> c, {bool reply = false}) {
    final author = (c['author'] as Map?) ?? const {};
    final text = c['text'] as String? ?? '';
    final likes = (c['likesCount'] as int?) ?? 0;
    final liked = c['likedByMe'] == true;
    final created = DateTime.tryParse(c['createdAt']?.toString() ?? '');
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 52 : 14, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => openProfile(context, author['id'] as String?),
            child: Avatar(
                src: author['avatarUrl'] as String?,
                name: author['name'] as String?,
                size: AvatarSize.sm),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${author['username'] ?? author['name'] ?? 'Someone'}  ·  ${created == null ? '' : formatRelativeTime(created)}',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 11.5)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    for (final part in text.split(RegExp(r'(?=@)|(?<=\s)')))
                      TextSpan(
                          text: part,
                          style: part.startsWith('@')
                              ? const TextStyle(color: Color(0xFF6F9BFF))
                              : null),
                  ]),
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _reply(c),
                  child: const Text('Reply',
                      style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: liked ? 'Unlike comment' : 'Like comment',
            child: InkWell(
              onTap: () => _toggleLike(c),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16,
                        color: liked
                            ? const Color(0xFFFF5C8A)
                            : AppColors.textFaint),
                    if (likes > 0)
                      Text('$likes',
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = [
      for (final c in _comments)
        if (c['parentId'] == null) c
    ];
    final repliesOf = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final parent = c['parentId'];
      if (parent is String) (repliesOf[parent] ??= []).add(c);
    }
    final children = <Widget>[];
    for (final c in top) {
      children.add(_comment(c));
      final replies = repliesOf[c['id']] ?? const [];
      if (replies.isEmpty) continue;
      if (_expanded.contains(c['id'])) {
        children.addAll(replies.map((r) => _comment(r, reply: true)));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 52, bottom: 6),
          child: GestureDetector(
            onTap: () => setState(() => _expanded.add(c['id'] as String)),
            child: Text(
                '——  View ${replies.length} ${replies.length == 1 ? 'reply' : 'more replies'}',
                style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ));
      }
    }
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Comments',
                    style: TextStyle(
                        color: AppColors.text, fontWeight: FontWeight.bold))),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _loading
                  ? const Center(child: Spinner())
                  : children.isEmpty
                      ? Center(
                          child: Text(
                              widget.commentsDisabled
                                  ? 'Comments are turned off'
                                  : 'No comments yet — start the conversation',
                              style:
                                  const TextStyle(color: AppColors.textFaint)))
                      : ListView(children: children),
            ),
            if (!widget.commentsDisabled) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final e in _emojis)
                      GestureDetector(
                        onTap: () {
                          _controller.text += e;
                          _controller.selection = TextSelection.collapsed(
                              offset: _controller.text.length);
                        },
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                  ],
                ),
              ),
              if (_replyTo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          'Replying to ${(_replyTo!['author'] as Map?)?['name'] ?? 'comment'}',
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textFaint),
                    ),
                  ]),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                          child: MentionTextField(
                              controller: _controller,
                              focusNode: _focus,
                              hintText: widget.authorName == null
                                  ? 'Add a comment…'
                                  : 'Add a comment for ${widget.authorName}…')),
                      IconButton(
                          tooltip: 'Post comment',
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send_rounded,
                              color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
