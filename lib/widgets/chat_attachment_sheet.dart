import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// "+" attachment menu for the room chat input bar (chat_overlay.dart).
/// Poll and view-once photos work; Video/Audio/GIF say they're coming
/// rather than pretending to send something.
Future<void> showChatAttachmentSheet(
  BuildContext context, {
  required VoidCallback onPoll,
  VoidCallback? onViewOncePhoto,
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
                  icon: InIcons.poll,
                  label: 'Poll',
                  onTap: () {
                    Navigator.of(context).pop();
                    onPoll();
                  },
                ),
                _AttachOption(
                  icon: InIcons.hourglass,
                  label: 'View once',
                  onTap: onViewOncePhoto == null
                      ? () => _comingSoon(context, 'Photo')
                      : () {
                          Navigator.of(context).pop();
                          onViewOncePhoto();
                        },
                ),
                _AttachOption(
                  icon: InIcons.video,
                  label: 'Video',
                  onTap: () => _comingSoon(context, 'Video'),
                ),
                _AttachOption(
                  icon: InIcons.music,
                  label: 'Audio',
                  onTap: () => _comingSoon(context, 'Audio'),
                ),
                _AttachOption(
                  icon: InIcons.gif,
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
  final InIconData icon;
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
            child: InIcon(icon, color: AppColors.text, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ],
      ),
    );
  }
}
