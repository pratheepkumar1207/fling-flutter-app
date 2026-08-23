import 'package:flutter/material.dart';

/// Center-of-video play/pause control shared by sync_video_player.dart and
/// drive_video_player.dart — a dedicated button, not a whole-video tap
/// target, per explicit request (tapping anywhere on the video was toggling
/// playback on incidental taps, e.g. near the seek bar).
///
/// Named RoomPlayPauseButton (not PlayPauseButton) to avoid colliding with
/// youtube_player_flutter's own internal widget of that exact name.
class RoomPlayPauseButton extends StatelessWidget {
  const RoomPlayPauseButton({super.key, required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}
