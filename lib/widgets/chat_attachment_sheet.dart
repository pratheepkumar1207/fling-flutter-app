import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// "+" attachment menu for the room chat input bar (chat_overlay.dart) —
/// replaces the old standalone poll icon. Poll is wired
/// to the existing, already-working poll flow; Image/Video/Audio/GIF are
/// UI-only for now — there's no upload/storage/message-rendering support
/// for media messages anywhere in this app yet, so tapping them is honest
/// about that ("coming soon") rather than pretending to send something
/// that silently goes nowhere.
Future<void> showChatAttachmentSheet(
  BuildContext context, {
  required VoidCallback onPoll,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Attach',
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: Icons.poll_rounded,
                  label: 'Poll',
                  onTap: () {
                    Navigator.of(context).pop();
                    onPoll();
                  },
                ),
                _AttachOption(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  onTap: () => _comingSoon(context, 'Image'),
                ),
                _AttachOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: () => _comingSoon(context, 'Video'),
                ),
                _AttachOption(
                  icon: Icons.audiotrack_rounded,
                  label: 'Audio',
                  onTap: () => _comingSoon(context, 'Audio'),
                ),
                _AttachOption(
                  icon: Icons.gif_box_rounded,
                  label: 'GIF',
                  onTap: () => _comingSoon(context, 'GIF'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _comingSoon(BuildContext context, String kind) {
  Navigator.of(context).pop();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$kind messages aren\'t built yet — coming soon')),
  );
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.surface3, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.text, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ],
      ),
    );
  }
}
