import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

class StoryItem {
  final String id;
  final String mediaType;
  final String? text;
  final String? imageData;
  final String? voiceData;
  final String? videoUrl;
  final String? videoData;
  final DateTime createdAt;
  // Shared to "Close friends" only — shown with a green ring and badge.
  final bool closeFriends;

  const StoryItem({
    required this.id,
    required this.mediaType,
    this.text,
    this.imageData,
    this.voiceData,
    this.videoUrl,
    this.videoData,
    required this.createdAt,
    this.closeFriends = false,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as String,
        mediaType: json['mediaType'] as String? ?? 'text',
        text: json['text'] as String?,
        imageData: json['imageData'] as String?,
        voiceData: json['voiceData'] as String?,
        videoUrl: json['videoUrl'] as String?,
        videoData: json['videoData'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        closeFriends: json['closeFriends'] == true,
      );
}

class StoryEntry {
  final String userId;
  final String? name;
  final String? avatarUrl;
  final List<StoryItem> items;
  const StoryEntry(
      {required this.userId, this.name, this.avatarUrl, this.items = const []});

  factory StoryEntry.fromJson(Map<String, dynamic> json) => StoryEntry(
        userId: json['userId'] as String,
        name: json['name'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        items: ((json['items'] as List?) ?? [])
            .map((e) => StoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Horizontal scroll of connections' active stories — Dart port of
/// StoryBar.jsx (a gradient-ring avatar preview strip).
class StoryBar extends StatelessWidget {
  final List<StoryEntry> stories;
  final ValueChanged<StoryEntry>? onOpen;
  final Widget? leading;

  const StoryBar({super.key, required this.stories, this.onOpen, this.leading});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty && leading == null) return const SizedBox.shrink();
    // Ring-wrapped 52px avatar (+ its two thin rings) plus the label.
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length + (leading != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (leading != null) {
            if (i == 0) return leading!;
            final s = stories[i - 1];
            return _storyTile(s);
          }
          final s = stories[i];
          return _storyTile(s);
        },
      ),
    );
  }

  Widget _storyTile(StoryEntry s) {
    return GestureDetector(
      onTap: () => onOpen?.call(s),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              // Green ring when any of their stories is close-friends only.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.items.any((i) => i.closeFriends)
                    ? AppColors.success
                    : null,
                gradient: s.items.any((i) => i.closeFriends)
                    ? null
                    : const SweepGradient(colors: [
                        AppColors.accent,
                        AppColors.primary,
                        Color(0xFFFF5C8A),
                        AppColors.accent
                      ]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.surface),
                child:
                    // Was a 96px avatar inside this 64px-wide tile, which
                    // squashed it into a tall oval.
                    SizedBox(
                  width: 52,
                  height: 52,
                  child: FittedBox(
                      child: Avatar(
                          src: s.avatarUrl, name: s.name, size: AvatarSize.lg)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(s.name ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
