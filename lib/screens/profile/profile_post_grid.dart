import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../feed/post_detail_screen.dart';

/// A profile's Posts or Reels tab — 3 columns, edge to edge, tap opens the
/// post. Photos show the photo; other kinds show what they are (text,
/// poll, voice, video) so the grid still reads at a glance.
class ProfilePostGrid extends StatelessWidget {
  final List<Post> posts;
  final bool reels;
  final String emptyText;
  final Future<void> Function()? onRefresh;

  const ProfilePostGrid({
    super.key,
    required this.posts,
    this.reels = false,
    required this.emptyText,
    this.onRefresh,
  });

  // One grid tile — also used on its own by the Archive screen.
  Widget tile(BuildContext context, Post p) {
    Widget content;
    if (p.imageData != null && p.imageData!.isNotEmpty) {
      content = AppImage(source: p.imageData, fit: BoxFit.cover);
    } else {
      final (icon, label) = switch (p.mediaType) {
        'reel' => (Icons.play_arrow_rounded, null),
        'voice' => (Icons.graphic_eq_rounded, 'Voice note'),
        'poll' => (Icons.poll_outlined, p.text),
        'video_link' => (Icons.smart_display_outlined, p.text),
        _ => (null, p.text),
      };
      content = Container(
        color: AppColors.surface2,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: AppColors.textDim, size: reels ? 34 : 24),
            if (label != null && label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 11.5, height: 1.3)),
              ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${p.mediaType} post',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (reels)
              Positioned(
                left: 6,
                bottom: 6,
                child: Row(children: [
                  const Icon(Icons.favorite_border_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text('${p.likesCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(40),
        children: [
          Icon(reels ? Icons.movie_outlined : Icons.grid_on_rounded,
              color: AppColors.textFaint, size: 36),
          const SizedBox(height: 10),
          Text(emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textFaint)),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: reels ? 9 / 16 : 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) => tile(context, posts[i]),
    );
  }
}
