import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Center-of-video play/pause control shared by sync_video_player.dart and
/// drive_video_player.dart — a dedicated button, not a whole-video tap
/// target, per explicit request (tapping anywhere on the video was toggling
/// playback on incidental taps, e.g. near the seek bar).
///
/// Named RoomPlayPauseButton (not PlayPauseButton) — a holdover from when
/// sync_video_player.dart used a third-party YouTube-player package with
/// its own internal widget of that exact name; kept for consistency even
/// though that package is gone (see sync_video_player.dart's own doc
/// comment for why).
class RoomPlayPauseButton extends StatelessWidget {
  const RoomPlayPauseButton(
      {super.key, required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.brand,
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 1),
          ],
        ),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white, size: 34),
      ),
    );
  }
}
