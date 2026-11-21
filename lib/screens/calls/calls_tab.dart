import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../messages/message_thread_screen.dart';
import 'start_call.dart';

/// Chat → Calls: the people you call most, then recent calls (missed in
/// red) with call-back buttons. The 📞+ in the Chat header picks a friend.
class CallsTabList extends StatefulWidget {
  const CallsTabList({super.key});

  @override
  State<CallsTabList> createState() => _CallsTabListState();
}

class _CallsTabListState extends State<CallsTabList> {
  List<Map<String, dynamic>>? _calls;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/calls/history');
      if (!mounted) return;
      setState(() => _calls = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _calls = const []);
    }
  }

  Future<void> _call(Map<String, dynamic> c, bool video) async {
    await startDirectCall(context,
        userId: c['userId'] as String,
        name: c['name'] as String? ?? '',
        avatarUrl: c['avatarUrl'] as String?,
        video: video);
    _load();
  }

  void _openChat(Map<String, dynamic> c) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MessageThreadScreen(
              userId: c['userId'] as String,
              name: c['name'] as String? ?? '',
              avatarUrl: c['avatarUrl'] as String?)));

  static String _length(int? s) {
    if (s == null) return '';
    if (s < 60) return ' · ${s}s';
    final m = s ~/ 60;
    return m < 60 ? ' · $m min' : ' · ${m ~/ 60} h ${m % 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final calls = _calls;
    if (calls == null) {
      return const Padding(
          padding: EdgeInsets.all(32), child: Center(child: Spinner()));
    }
    // Favourites: the people you've talked to most.
    final counts = <String, int>{};
    final byUser = <String, Map<String, dynamic>>{};
    for (final c in calls) {
      final id = c['userId'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
      byUser.putIfAbsent(id, () => c);
    }
    final favs = (counts.keys.toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!)))
        .take(6)
        .map((id) => byUser[id]!)
        .toList();

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(t,
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700)),
        );

    if (calls.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: Column(children: [
          Icon(Icons.call_outlined, size: 40, color: AppColors.textFaint),
          SizedBox(height: 10),
          Text('Your calls show up here.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Call a friend from their chat, or tap the call button above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header('FAVOURITES'),
      SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final f in favs)
              Semantics(
                button: true,
                label: 'Call ${f['name']}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _call(f, f['mode'] == 'video'),
                  child: SizedBox(
                    width: 68,
                    child: Column(children: [
                      const SizedBox(height: 4),
                      Avatar(
                          src: f['avatarUrl'] as String?,
                          name: f['name'] as String?,
                          size: AvatarSize.md),
                      const SizedBox(height: 4),
                      Text((f['name'] as String? ?? '').split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
      header('RECENT'),
      for (final c in calls)
        Builder(builder: (context) {
          final missed = c['status'] == 'missed' && c['direction'] == 'incoming';
          final declined = c['status'] == 'declined';
          final outgoing = c['direction'] == 'outgoing';
          final video = c['mode'] == 'video';
          final at = DateTime.tryParse('${c['at'] ?? ''}');
          final what = missed
              ? 'Missed'
              : declined
                  ? (outgoing ? 'Not answered' : 'Declined')
                  : c['status'] == 'missed'
                      ? 'No answer'
                      : outgoing
                          ? 'Outgoing'
                          : 'Incoming';
          return ListTile(
            onTap: () => _openChat(c),
            leading: Avatar(
                src: c['avatarUrl'] as String?,
                name: c['name'] as String?,
                size: AvatarSize.md),
            title: Text(c['name'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: missed ? AppColors.danger : null)),
            subtitle: Row(children: [
              Icon(
                  outgoing
                      ? Icons.call_made_rounded
                      : Icons.call_received_rounded,
                  size: 14,
                  color: missed || declined
                      ? AppColors.danger
                      : const Color(0xFF5DCAA5)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                    '$what${at != null ? ' · ${formatRelativeTime(at)}' : ''}'
                    '${_length((c['seconds'] as num?)?.toInt())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5)),
              ),
            ]),
            trailing: IconButton(
              tooltip: video ? 'Video call' : 'Voice call',
              icon: Icon(
                  video ? Icons.videocam_outlined : Icons.call_outlined,
                  color: AppColors.lilac),
              onPressed: () => _call(c, video),
            ),
          );
        }),
      const SizedBox(height: 12),
    ]);
  }
}

/// 📞+ → pick a friend, then voice or video.
Future<void> pickFriendAndCall(BuildContext context) async {
  List<Map<String, dynamic>> friends = const [];
  try {
    friends = ((await ApiClient.get('/friends')) as List)
        .cast<Map<String, dynamic>>();
  } catch (_) {}
  if (!context.mounted) return;
  final pick = await showModalBottomSheet<(Map<String, dynamic>, bool)>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scroll) => ListView(controller: scroll, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('New call',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        if (friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Add friends to call them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint)),
          ),
        for (final f in friends)
          ListTile(
            leading: Avatar(
                src: f['avatarUrl'] as String?,
                name: f['name'] as String?,
                size: AvatarSize.md),
            title: Text(f['name'] as String? ?? ''),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Voice call',
                  icon: const Icon(Icons.call_outlined, color: AppColors.lilac),
                  onPressed: () => Navigator.of(sheet).pop((f, false))),
              IconButton(
                  tooltip: 'Video call',
                  icon: const Icon(Icons.videocam_outlined,
                      color: AppColors.lilac),
                  onPressed: () => Navigator.of(sheet).pop((f, true))),
            ]),
          ),
      ]),
    ),
  );
  if (pick == null || !context.mounted) return;
  final (f, video) = pick;
  await startDirectCall(context,
      userId: f['id'] as String,
      name: f['name'] as String? ?? '',
      avatarUrl: f['avatarUrl'] as String?,
      video: video);
}
