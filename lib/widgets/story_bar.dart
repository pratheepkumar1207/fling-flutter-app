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

  const StoryItem({
    required this.id,
    required this.mediaType,
    this.text,
    this.imageData,
    this.voiceData,
    this.videoUrl,
    this.videoData,
    required this.createdAt,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as String,
        mediaType: json['mediaType'] as String? ?? 'text',
        text: json['text'] as String?,
        imageData: json['imageData'] as String?,
        voiceData: json['voiceData'] as String?,
        videoUrl: json['videoUrl'] as String?,
        videoData: json['videoData'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class StoryEntry {
  final String userId;
  final String? name;
  final String? avatarUrl;
  final List<StoryItem> items;
  const StoryEntry({required this.userId, this.name, this.avatarUrl, this.items = const []});

  factory StoryEntry.fromJson(Map<String, dynamic> json) => StoryEntry(
        userId: json['userId'] as String,
        name: json['name'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        items: ((json['items'] as List?) ?? []).map((e) => StoryItem.fromJson(e as Map<String, dynamic>)).toList(),
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
    // A ring-wrapped AvatarSize.lg (96) plus its two 2px padding layers is
    // already 104px alone, before the label below it — 84 was never tall
    // enough and silently overflowed on-device (not something flutter
    // analyze/build catches, only visible on a real screen).
    return SizedBox(
      height: 126,
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppGradients.brand),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                child: Avatar(src: s.avatarUrl, name: s.name, size: AvatarSize.lg),
              ),
            ),
            const SizedBox(height: 4),
            Text(s.name ?? '', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
