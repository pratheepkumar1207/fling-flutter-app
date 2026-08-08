import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';
import 'share_row.dart';

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
                          Row(children: [
                            Avatar(src: post.author.avatarUrl, name: post.author.name, size: AvatarSize.sm),
                            const SizedBox(width: 8),
                            Expanded(child: Text(post.author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          ]),
                          if (post.text != null && post.text!.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(post.text!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(onPressed: () => widget.onLike(post), icon: Text(post.likedByMe ? '❤️' : '🤍', style: const TextStyle(fontSize: 22))),
                        Text('${post.likesCount}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        IconButton(onPressed: () => widget.onOpenComments(post), icon: const Text('💬', style: TextStyle(fontSize: 22))),
                        Text('${post.commentsCount}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        IconButton(onPressed: () => widget.onSave(post), icon: Text(post.savedByMe ? '🔖' : '📑', style: const TextStyle(fontSize: 20))),
                        ShareRow(text: post.text),
                        IconButton(onPressed: _toggleMute, icon: Text(_muted ? '🔇' : '🔊', style: const TextStyle(fontSize: 20))),
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
