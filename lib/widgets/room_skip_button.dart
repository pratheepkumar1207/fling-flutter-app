import 'package:flutter/material.dart';

/// Flanks RoomPlayPauseButton left/right (previous/next) — same
/// glass-on-video treatment, smaller since it's a secondary action.
/// Renders disabled (dimmed, no tap) when [onTap] is null, e.g. "previous"
/// with nothing queued before the current item.
class RoomSkipButton extends StatelessWidget {
  const RoomSkipButton({super.key, required this.forward, required this.onTap});

  final bool forward;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle),
        child: Icon(
          forward ? Icons.skip_next_rounded : Icons.skip_previous_rounded,
          color: enabled ? Colors.white : Colors.white38,
          size: 22,
        ),
      ),
    );
  }
}
