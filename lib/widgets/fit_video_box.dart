import 'package:flutter/material.dart';

/// The player's box in the video's own shape: full width for landscape,
/// and for tall videos (reels, Shorts) no taller than [maxScreenShare] of
/// the screen, centred with black at the sides, so chat always has room.
/// Shared by the YouTube, Drive and streaming-site players.
class FitVideoBox extends StatelessWidget {
  final double aspectRatio;
  final Widget child;
  final double maxScreenShare;
  const FitVideoBox({
    super.key,
    required this.aspectRatio,
    required this.child,
    this.maxScreenShare = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;
    // The limit only applies upright; turned sideways the video gets the
    // whole screen.
    final upright = MediaQuery.orientationOf(context) == Orientation.portrait;
    final maxHeight =
        MediaQuery.sizeOf(context).height * (upright ? maxScreenShare : 1);
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth.isFinite
          ? box.maxWidth
          : MediaQuery.sizeOf(context).width;
      if (width / ratio <= maxHeight) {
        return AspectRatio(aspectRatio: ratio, child: child);
      }
      return ColoredBox(
        color: Colors.black,
        child: SizedBox(
          width: width,
          height: maxHeight,
          child: Center(
            child: AspectRatio(aspectRatio: ratio, child: child),
          ),
        ),
      );
    });
  }
}
