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
  final int? count;

  const _ReelIconButton({
    required this.icon,
    this.active = false,
    this.activeColor = AppColors.primary,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: active ? activeColor : Colors.white,
              shadows: active
                  ? [Shadow(color: activeColor, blurRadius: 12), Shadow(color: activeColor, blurRadius: 24)]
                  : const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReelCard extends StatefulWidget {
  final Post post;
  final ValueChanged<Post> onLike;
  final ValueChanged<Post> onOpenComments;
  final ValueChanged<Post> onSave;

  const _ReelCard({required this.post, required this.onLike, required this.onOpenComments, required this.onSave});

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  VideoPlayerController? _controller;
  bool _muted = true;

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
          if (mounted) {
            setState(() {});
            _controller!.play();
          }
        });
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              GestureDetector(
                onTap: _toggleMute,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)),
                ),
              )
            else
              const Center(child: Text('🎥', style: TextStyle(fontSize: 48, color: Colors.white24))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => openProfile(context, post.author.id),
                            child: Row(children: [
                              Avatar(src: post.author.avatarUrl, name: post.author.name, size: AvatarSize.sm),
                              const SizedBox(width: 8),
                              Expanded(child: Text(post.author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                            ]),
                          ),
                          if (post.text != null && post.text!.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(post.text!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _ReelIconButton(
                          icon: post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          active: post.likedByMe,
                          onTap: () => widget.onLike(post),
                          count: post.likesCount,
                        ),
                        _ReelIconButton(
                          icon: Icons.mode_comment_outlined,
                          onTap: () => widget.onOpenComments(post),
                          count: post.commentsCount,
                        ),
                        _ReelIconButton(
                          icon: post.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          active: post.savedByMe,
                          activeColor: AppColors.gold,
                          onTap: () => widget.onSave(post),
                        ),
                        ShareRow(text: post.text),
                        _ReelIconButton(
                          icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          onTap: _toggleMute,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical swipeable reel feed — Dart port of ReelsFeed.jsx.
class ReelsFeed extends StatelessWidget {
  final List<Post> reels;
  final ValueChanged<Post> onLike;
  final ValueChanged<Post> onOpenComments;
  final ValueChanged<Post> onSave;

  const ReelsFeed({super.key, required this.reels, required this.onLike, required this.onOpenComments, required this.onSave});

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No reels yet — be the first to post one.', style: TextStyle(color: AppColors.textFaint))),
      );
    }
    final height = MediaQuery.of(context).size.height - 320;
    return SizedBox(
      height: height < 300 ? 300 : height,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _ReelCard(post: reels[i], onLike: onLike, onOpenComments: onOpenComments, onSave: onSave),
        ),
      ),
    );
  }
}
