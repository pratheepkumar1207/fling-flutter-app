import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../models/post.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';
import 'share_row.dart';

// Transparent by default — a plain white outline icon sitting directly on
// the video with a soft shadow for legibility, no filled backdrop circle.
// Toggling "on" fills the icon and adds a glow instead of a background
// swap, so the button never looks like a flat colored chip.
class _ReelIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final String? label;
  final String semantics;

  const _ReelIconButton({
    required this.icon,
    this.active = false,
    this.activeColor = AppColors.primary,
    required this.onTap,
    this.label,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 29,
                color: active ? activeColor : Colors.white,
                shadows: const [
                  Shadow(
                      color: Colors.black54,
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ],
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(label!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelCard extends StatefulWidget {
  final Post post;
  final bool active;
  final ValueChanged<Post> onLike;
  final ValueChanged<Post> onOpenComments;
  final ValueChanged<Post> onSave;

  const _ReelCard(
      {super.key,
      required this.post,
      required this.active,
      required this.onLike,
      required this.onOpenComments,
      required this.onSave});

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _muted = true;
  bool _held = false;
  late final AnimationController _heart = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    final data = widget.post.videoData;
    if (data != null) {
      // Data-URI playback works reliably on web (HTML5 <video>, same as the
      // web app's ReelsFeed) — on native Android/iOS, base64-in-DB video is
      // already a known scale tradeoff (see Post model's comment), so very
      // large clips may not decode cleanly through ExoPlayer/AVPlayer.
      _controller = VideoPlayerController.networkUrl(Uri.parse(data))
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.active) _controller!.play();
        });
    }
  }

  // Only the reel on screen plays — swiping away pauses the one behind.
  @override
  void didUpdateWidget(covariant _ReelCard old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.active && !old.active) c.play();
    if (!widget.active && old.active) c.pause();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _heart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final c = _controller;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tap: mute/unmute. Hold: pause. Double-tap: like.
          GestureDetector(
            onTap: _toggleMute,
            onDoubleTap: () {
              if (!post.likedByMe) widget.onLike(post);
              _heart.forward(from: 0);
            },
            onLongPressStart: (_) {
              setState(() => _held = true);
              c?.pause();
            },
            onLongPressEnd: (_) {
              setState(() => _held = false);
              if (widget.active) c?.play();
            },
            child: c != null && c.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                        width: c.value.size.width,
                        height: c.value.size.height,
                        child: VideoPlayer(c)),
                  )
                : const Center(
                    child: Icon(Icons.movie_outlined,
                        size: 48, color: Colors.white24)),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _heart,
              builder: (context, _) {
                final t = _heart.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                return Opacity(
                  opacity: t < 0.7 ? 1 : (1 - (t - 0.7) / 0.3).clamp(0, 1),
                  child: Transform.scale(
                    scale: t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) : 1,
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 100),
                  ),
                );
              },
            ),
          ),
          if (_muted)
            const Positioned(
              top: 70,
              right: 14,
              child: Icon(Icons.volume_off_rounded,
                  color: Colors.white70, size: 20),
            ),
          // Right rail.
          Positioned(
            right: 8,
            bottom: 90,
            child: Column(
              children: [
                _ReelIconButton(
                  icon: post.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  active: post.likedByMe,
                  activeColor: const Color(0xFFFF5C8A),
                  onTap: () => widget.onLike(post),
                  label: post.likesHidden ? null : '${post.likesCount}',
                  semantics: post.likedByMe ? 'Unlike' : 'Like',
                ),
                _ReelIconButton(
                  icon: Icons.mode_comment_outlined,
                  onTap: () => widget.onOpenComments(post),
                  label: '${post.commentsCount}',
                  semantics: 'Comments',
                ),
                ShareRow(text: post.text),
                _ReelIconButton(
                  icon: post.savedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  active: post.savedByMe,
                  activeColor: AppColors.gold,
                  onTap: () => widget.onSave(post),
                  semantics: post.savedByMe ? 'Unsave' : 'Save',
                ),
                const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FittedBox(
                    child: Avatar(
                        src: post.author.avatarUrl, name: post.author.name),
                  ),
                ),
              ],
            ),
          ),
          // Author, caption, audio — bottom left.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 40, 70, 18),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87])),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => openProfile(context, post.author.id),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white),
                          child: Avatar(
                              src: post.author.avatarUrl,
                              name: post.author.name,
                              size: AvatarSize.sm),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(post.author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                    if (post.text != null && post.text!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(post.text!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, height: 1.35)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text('${post.author.name} · Original audio',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_held)
            const Center(
              child: Icon(Icons.pause_rounded, color: Colors.white54, size: 64),
            ),
          // Thin progress line along the bottom edge.
          if (c != null && c.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: false,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vertical swipeable reel feed — Dart port of ReelsFeed.jsx. Fills
/// whatever space it's given (ReelsScreen gives it the whole screen).
class ReelsFeed extends StatefulWidget {
  final List<Post> reels;
  final ValueChanged<Post> onLike;
  final ValueChanged<Post> onOpenComments;
  final ValueChanged<Post> onSave;

  const ReelsFeed(
      {super.key,
      required this.reels,
      required this.onLike,
      required this.onOpenComments,
      required this.onSave});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.reels.isEmpty) {
      return const Center(
          child: Text('No reels yet — be the first to post one.',
              style: TextStyle(color: AppColors.textFaint)));
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: widget.reels.length,
      onPageChanged: (i) => setState(() => _page = i),
      itemBuilder: (context, i) => _ReelCard(
          key: ValueKey(widget.reels[i].id),
          post: widget.reels[i],
          active: i == _page,
          onLike: widget.onLike,
          onOpenComments: widget.onOpenComments,
          onSave: widget.onSave),
    );
  }
}

/// Reels, full screen — "Reels" top left, + to post one top right, swipe
/// up for the next. Likes/saves are handled by the caller (FeedScreen) so
/// the feed and reels stay in step.
class ReelsScreen extends StatefulWidget {
  final List<Post> reels;
  final Future<Post?> Function(Post post) onLike;
  final Future<Post?> Function(Post post) onSave;
  final ValueChanged<Post> onOpenComments;
  final VoidCallback onCreate;

  const ReelsScreen(
      {super.key,
      required this.reels,
      required this.onLike,
      required this.onSave,
      required this.onOpenComments,
      required this.onCreate});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final List<Post> _reels = [...widget.reels];

  Future<void> _replace(Future<Post?> Function(Post) action, Post post) async {
    final next = await action(post);
    if (next == null || !mounted) return;
    setState(() {
      final i = _reels.indexWhere((p) => p.id == post.id);
      if (i != -1) _reels[i] = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ReelsFeed(
            reels: _reels,
            onLike: (p) => _replace(widget.onLike, p),
            onSave: (p) => _replace(widget.onSave, p),
            onOpenComments: widget.onOpenComments,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const Text('Reels',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'New reel',
                    onPressed: widget.onCreate,
                    icon:
                        const Icon(Icons.add_box_outlined, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
