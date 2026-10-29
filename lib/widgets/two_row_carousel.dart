import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';
import 'app_image.dart';

/// One tile in a [TwoRowCarousel].
class CarouselTile {
  final String title;
  final String? thumbnail;
  final String? badge; // small pill, top right ("12 songs", "Added")
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const CarouselTile(
      {required this.title,
      this.thumbnail,
      this.badge,
      this.highlighted = false,
      this.onTap,
      this.onLongPress});
}

/// The watch party's 2-row sideways carousel of 16:9 thumbnails — shared by
/// the room's History/Liked lists and the profile's History, Playlists and
/// Liked songs.
class TwoRowCarousel extends StatelessWidget {
  final List<CarouselTile> tiles;
  const TwoRowCarousel({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tileWidth = constraints.maxWidth * 0.46;
      final tileHeight = tileWidth * 9 / 16;
      const gap = 4.0;
      return SizedBox(
        height: tileHeight * 2 + gap,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: tileWidth,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemBuilder: (context, i) => _Tile(tiles[i]),
        ),
      );
    });
  }
}

class _Tile extends StatelessWidget {
  final CarouselTile t;
  const _Tile(this.t);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: t.onTap != null,
      label: [t.title, if (t.badge != null) t.badge].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: t.onTap,
        onLongPress: t.onLongPress,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface3,
            borderRadius: BorderRadius.circular(8),
            border: t.highlighted
                ? Border.all(color: AppColors.accent, width: 2)
                : null,
          ),
          child: Stack(fit: StackFit.expand, children: [
            if (t.thumbnail != null && t.thumbnail!.isNotEmpty)
              AppImage(source: t.thumbnail, fit: BoxFit.cover)
            else
              const Center(
                  child:
                      InIcon(InIcons.music, size: 20, color: AppColors.lilac)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            if (t.badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: t.highlighted
                          ? AppColors.accent
                          : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(t.badge!,
                      style: TextStyle(
                          color: t.highlighted ? AppColors.ink : Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
