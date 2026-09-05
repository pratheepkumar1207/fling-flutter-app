import 'package:flutter/material.dart';

/// ±10s seek button flanking RoomPlayPauseButton — a real seek (YouTube/
/// Drive only; OTT has no real position to seek, see webview_room_player
/// .dart's separate elapsed-time drag bar instead). Host-only, same as the
/// play/pause button it sits next to; renders disabled (dimmed, no tap)
/// when [onTap] is null.
class RoomSeekTenButton extends StatelessWidget {
  const RoomSeekTenButton({super.key, required this.forward, this.onTap});

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
            color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
              color: enabled ? Colors.white : Colors.white38,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
