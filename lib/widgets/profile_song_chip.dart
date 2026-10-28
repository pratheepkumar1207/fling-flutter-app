import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// "♪ Kannaana Kanney · Profile song" under a profile's bio; tap to play
/// it on YouTube.
class ProfileSongChip extends StatelessWidget {
  final Map<String, dynamic>? song;
  const ProfileSongChip({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final s = song;
    if (s == null || s['title'] == null) return const SizedBox.shrink();
    final url = Uri.tryParse('${s['videoUrl'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: url != null,
        label: 'Profile song: ${s['title']}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: url == null
              ? null
              : () => launchUrl(url, mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1326),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF3B2A55))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const InIcon(InIcons.music, size: 14, color: AppColors.lilac),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${s['title']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE2CCFF))),
              ),
              const Text(' · Profile song',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim)),
            ]),
          ),
        ),
      ),
    );
  }
}
