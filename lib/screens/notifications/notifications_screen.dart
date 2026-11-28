import 'package:flutter/material.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/avatar.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import 'notification_actions.dart';
import '../../widgets/insync_snack.dart';

/// All notifications (approved design, Nov 2026): filters for Lobbies,
/// Mentions, Gifts and Requests; New (unread), Today and Earlier; each row
/// the sender's photo with a small red badge for what happened, their name
/// in bold, and a button right on the row when there's a next step (Join,
/// Let in, Follow back, Accept). Likes on the same post are one row:
/// "Meera and 12 others liked your post".
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// One row: a notification, or several likes on the same post.
class _Row {
  final NotificationItem first;
  final List<NotificationItem> all;
  _Row(this.first, this.all);
  bool get isRead => all.every((n) => n.isRead);
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/notifications');
      if (!mounted) return;
      setState(() {
        _items = (data as List)
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.post('/notifications/read-all');
      if (!mounted) return;
      setState(() =>
          _items = _items.map((n) => n.isRead ? n : _withRead(n)).toList());
    } catch (_) {}
  }

  NotificationItem _withRead(NotificationItem n) => NotificationItem(
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      data: n.data,
      isRead: true,
      createdAt: n.createdAt,
      actorName: n.actorName,
      actorAvatarUrl: n.actorAvatarUrl);

  Future<void> _open(_Row r) async {
    final unread = r.all.where((n) => !n.isRead).toList();
    if (unread.isNotEmpty) {
      setState(() {
        for (final n in unread) {
          final i = _items.indexWhere((it) => it.id == n.id);
          if (i != -1) _items[i] = _withRead(n);
        }
      });
      for (final n in unread) {
        ApiClient.post('/notifications/${n.id}/read').catchError((_) => null);
      }
    }
    if (!mounted) return;
    openNotificationTarget(context, r.first);
  }

  String _filter = 'all';
  final Set<String> _followedBack = {};
  final Set<String> _accepted = {};

  static String _group(String type) => switch (type) {
        'room_invite' ||
        'event_reminder' ||
        'blend_invite' ||
        'blend_watch' ||
        'friend_online' ||
        'tournament' ||
        'tournament_match' =>
          'lobbies',
        'mention' || 'tag' || 'comment' || 'story_reply' => 'mentions',
        'gift' ||
        'gift_received' ||
        'new_subscriber' ||
        'cashout_requested' ||
        'cashout' ||
        'reward' =>
          'gifts',
        'room_join_ask' ||
        'friend_request' ||
        'community_request' ||
        'collab' =>
          'requests',
        _ => 'other',
      };

  Future<void> _followBack(NotificationItem n) async {
    final id = n.data?['fromUserId'] as String?;
    if (id == null) return;
    setState(() => _followedBack.add(id));
    try {
      await ApiClient.post('/social/follow/$id');
    } catch (_) {
      if (mounted) setState(() => _followedBack.remove(id));
    }
  }

  Future<void> _accept(NotificationItem n) async {
    final id = n.data?['requestId'] as String?;
    if (id == null) return;
    setState(() => _accepted.add(n.id));
    try {
      await ApiClient.post('/friends/$id/accept');
    } catch (_) {
      if (!mounted) return;
      setState(() => _accepted.remove(n.id));
      ScaffoldMessenger.of(context).showSnackBar(
          insyncSnackBar(content: const Text('Couldn’t accept. Try again.')));
    }
  }

  // Host side of "Ask to join": letting someone in sends them an invite.
  final Set<String> _letIn = {};
  Future<void> _letThemIn(NotificationItem n) async {
    final roomId = n.data?['roomId'] as String?;
    final userId = n.data?['userId'] as String?;
    if (roomId == null || userId == null) return;
    setState(() => _letIn.add(n.id));
    try {
      await ApiClient.post('/rooms/$roomId/invite', body: {
        'userIds': [userId]
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(
            content: Text('Invite sent to ${n.data?['name'] ?? 'them'}')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _letIn.remove(n.id));
        ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(
            content: const Text(
                'Couldn’t send the invite. The lobby may have ended.')));
      }
    }
  }

  Widget _pill(String label, VoidCallback? onTap, {String style = 'red'}) {
    final bg = switch (style) {
      'red' => AppColors.primary,
      'white' => Colors.white,
      _ => Colors.black,
    };
    final fg = style == 'white' ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        shape: StadiumBorder(
            side: style == 'outline'
                ? const BorderSide(color: Colors.white)
                : BorderSide.none),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(label,
                style: TextStyle(
                    color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  /// The one-tap button on a row, when there's a next step.
  Widget? _action(_Row r) {
    final n = r.first;
    switch (n.type) {
      case 'room_invite' || 'blend_invite' || 'blend_watch':
        return _pill('Join', () => _open(r));
      case 'room_join_ask':
        return _letIn.contains(n.id)
            ? _pill('Invited', null, style: 'outline')
            : _pill('Let in', () => _letThemIn(n), style: 'white');
      case 'match':
        return _pill('Say hi', () => _open(r));
      case 'follow':
        final id = n.data?['fromUserId'] as String?;
        if (id == null) return null;
        return _followedBack.contains(id)
            ? _pill('Following', null, style: 'outline')
            : _pill('Follow back', () => _followBack(n), style: 'outline');
      case 'friend_request':
        if (n.data?['requestId'] == null) {
          return _pill('View', () => _open(r), style: 'outline');
        }
        return _accepted.contains(n.id)
            ? _pill('Friends', null, style: 'outline')
            : _pill('Accept', () => _accept(n));
    }
    return null;
  }

  /// Likes on the same post, next to each other, become one row.
  List<_Row> _rows(List<NotificationItem> list) {
    final out = <_Row>[];
    for (final n in list) {
      final post = n.data?['postId'];
      if (n.type == 'like' && post != null && out.isNotEmpty) {
        final last = out.last;
        if (last.first.type == 'like' && last.first.data?['postId'] == post) {
          last.all.add(n);
          continue;
        }
      }
      out.add(_Row(n, [n]));
    }
    return out;
  }

  int get _openRequests => _items
      .where((n) =>
          !n.isRead &&
          (n.type == 'room_join_ask' || n.type == 'friend_request'))
      .length;

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).toList();
    final shown = _filter == 'all'
        ? _items
        : _items.where((n) => _group(n.type) == _filter).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sections = <(String, List<NotificationItem>)>[
      ('New', shown.where((n) => !n.isRead).toList()),
      (
        'Today',
        shown
            .where((n) => n.isRead && !n.createdAt.toLocal().isBefore(today))
            .toList()
      ),
      (
        'Earlier',
        shown
            .where((n) => n.isRead && n.createdAt.toLocal().isBefore(today))
            .toList()
      ),
    ];
    final requests = _openRequests;
    final filters = [
      ('all', 'All'),
      ('lobbies', 'Lobbies'),
      ('mentions', 'Mentions'),
      ('gifts', 'Gifts'),
      ('requests', requests > 0 ? 'Requests $requests' : 'Requests'),
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Notifications',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read',
                    style:
                        TextStyle(color: Color(0xFFFF9AA6), fontSize: 12.5))),
        ],
      ),
      body: _loading
          ? const SingleChildScrollView(child: SkeletonRows())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(top: 2, bottom: 24),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Row(children: [
                      for (final (id, label) in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: _chip(label, id),
                        ),
                    ]),
                  ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                          _items.isEmpty
                              ? 'Invites, likes and gifts show up here.'
                              : 'Nothing here yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  for (final (label, list) in sections)
                    if (list.isNotEmpty) ...[
                      _sectionLabel(label),
                      ..._rows(list).map(_row),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _chip(String label, String id) {
    final on = _filter == id;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: () => setState(() => _filter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.black : Colors.white,
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  /// "Riya invited you to a room": the sender's name in bold.
  InlineSpan _title(_Row r) {
    final n = r.first;
    final name = n.actorName ?? n.data?['name'] as String?;
    final others = r.all.length - 1;
    var title = n.title;
    if (others > 0 && name != null && title.startsWith(name)) {
      title = '$name and $others other${others == 1 ? '' : 's'}'
          '${title.substring(name.length)}';
    }
    const bold = TextStyle(fontWeight: FontWeight.w700);
    if (name != null && name.isNotEmpty && title.startsWith(name)) {
      final rest = title.substring(name.length);
      final m = RegExp(r'^ and (\d+ others?)').firstMatch(rest);
      return TextSpan(children: [
        TextSpan(text: name, style: bold),
        if (m != null) ...[
          const TextSpan(text: ' and '),
          TextSpan(text: m.group(1), style: bold),
          TextSpan(text: rest.substring(m.end)),
        ] else
          TextSpan(text: rest),
      ]);
    }
    return TextSpan(text: title);
  }

  Widget _face(_Row r) {
    final n = r.first;
    final name = n.actorName ?? n.data?['name'] as String?;
    final hasPerson = n.actorAvatarUrl != null || (name?.isNotEmpty ?? false);
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          top: 0,
          child: hasPerson
              ? SizedBox.square(
                  dimension: 40,
                  child: FittedBox(
                      child: Avatar(
                          src: n.actorAvatarUrl,
                          name: name,
                          size: AvatarSize.md)),
                )
              : Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: InIcon(notificationIcon(n.type),
                      size: 18, color: Colors.white),
                ),
        ),
        if (hasPerson)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              alignment: Alignment.center,
              child: InIcon(notificationIcon(n.type),
                  size: 10, color: Colors.white),
            ),
          ),
      ]),
    );
  }

  Widget _row(_Row r) {
    final n = r.first;
    final action = _action(r);
    final sub = [
      if (n.body.isNotEmpty) n.body,
      formatRelativeTime(n.createdAt),
    ].join(' · ');
    return InkWell(
      onTap: () => _open(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _face(r),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(_title(r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13.5)),
                  const SizedBox(height: 1),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11.5)),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action],
            if (!r.isRead && action == null) ...[
              const SizedBox(width: 8),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
