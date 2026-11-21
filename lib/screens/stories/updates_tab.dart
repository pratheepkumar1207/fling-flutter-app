import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/notes.dart';
import '../../widgets/story_bar.dart';
import '../../widgets/story_viewer_screen.dart';
import '../create/create_flow.dart';

const _seenKey = 'chat_updates_seen_story_ids';

/// Stories from people you're connected with (same list as the Home strip).
Future<List<StoryEntry>> loadStoryEntries() async {
  try {
    final data = await ApiClient.get('/feed/stories');
    return [
      for (final e in data as List)
        StoryEntry.fromJson(Map<String, dynamic>.from(e as Map))
    ];
  } catch (_) {
    return const [];
  }
}

/// Story ids this phone has opened from Chat → Updates.
Future<Set<String>> loadSeenStoryIds() async {
  try {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_seenKey) ?? const []).toSet();
  } catch (_) {
    return <String>{};
  }
}

Future<void> _markSeen(Iterable<String> ids) async {
  try {
    final p = await SharedPreferences.getInstance();
    final all = {...(p.getStringList(_seenKey) ?? const <String>[]), ...ids};
    // Stories last a day; keep the list small.
    final list = all.toList();
    await p.setStringList(
        _seenKey, list.length > 500 ? list.sublist(list.length - 500) : list);
  } catch (_) {}
}

bool storyGroupSeen(StoryEntry s, Set<String> seen) =>
    s.items.isNotEmpty && s.items.every((i) => seen.contains(i.id));

/// Chat → Updates: notes on top, then add to your story, then friends'
/// stories split into Recent (not opened yet) and Seen.
class UpdatesTab extends StatelessWidget {
  final List<StoryEntry> stories;
  final Set<String> seen;

  /// Called after a story was opened or posted, so the caller reloads.
  final VoidCallback onChanged;
  const UpdatesTab(
      {super.key,
      required this.stories,
      required this.seen,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final mine = stories.where((s) => s.userId == me?.id).toList();
    final others = stories.where((s) => s.userId != me?.id).toList()
      ..removeWhere((s) => s.items.isEmpty)
      ..sort((a, b) => b.items.last.createdAt.compareTo(a.items.last.createdAt));
    final recent = others.where((s) => !storyGroupSeen(s, seen)).toList();
    final old = others.where((s) => storyGroupSeen(s, seen)).toList();

    Future<void> open(StoryEntry s) async {
      final list = [...mine, ...recent, ...old];
      // Only the stories that were really on screen count as seen,
      // including friends swiped into.
      final viewed = <String>{};
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
              groups: list,
              startGroupIndex: list.indexOf(s),
              onItemShown: (i) => viewed.add(i.id))));
      await _markSeen(viewed);
      onChanged();
    }

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(t,
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700)),
        );

    Widget ring(StoryEntry s, bool fresh) => Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: fresh ? const Color(0xFFFF4FA3) : AppColors.border,
                width: 2),
          ),
          child: Avatar(src: s.avatarUrl, name: s.name, size: AvatarSize.md),
        );

    Widget row(StoryEntry s, bool fresh) => ListTile(
          onTap: () => open(s),
          leading: ring(s, fresh),
          title: Text(s.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${formatRelativeTime(s.items.last.createdAt)}'
              '${s.items.length > 1 ? ' · ${s.items.length} stories' : ''}',
              style: const TextStyle(fontSize: 12.5)),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header('NOTES'),
      NotesRow(myUserId: me?.id, myName: me?.name, myAvatar: me?.avatarUrl),
      header('STORIES'),
      ListTile(
        onTap: () => mine.isNotEmpty
            ? open(mine.first)
            : openCreateFlow(context,
                mode: CreateMode.story, onPosted: onChanged),
        leading: Stack(clipBehavior: Clip.none, children: [
          Avatar(src: me?.avatarUrl, name: me?.name, size: AvatarSize.md),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: () => openCreateFlow(context,
                  mode: CreateMode.story, onPosted: onChanged),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                    color: AppColors.lilac,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2)),
                child: const Icon(Icons.add, size: 13, color: Colors.white),
              ),
            ),
          ),
        ]),
        title: Text(mine.isNotEmpty ? 'Your story' : 'Add to your story',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            mine.isNotEmpty
                ? '${mine.first.items.length} today · tap + to add more'
                : 'Camera, lenses, text',
            style: const TextStyle(fontSize: 12.5)),
      ),
      if (others.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Text('When friends post stories, they show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint)),
        ),
      if (recent.isNotEmpty) header('RECENT'),
      for (final s in recent) row(s, true),
      if (old.isNotEmpty) header('SEEN'),
      for (final s in old) row(s, false),
      const SizedBox(height: 12),
    ]);
  }
}
