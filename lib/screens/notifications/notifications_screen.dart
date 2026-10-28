import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/spinner.dart';
import 'notification_actions.dart';

/// Full notifications list — the bell dropdown only ever shows the 10 most
/// recent, this is the "see all" screen matching NotificationsDark.dc.html.
/// Same GET /notifications backend the bell already uses; grouped into
/// New/Earlier by isRead rather than by date, since the mock's own
/// "New"/"Earlier" split already maps 1:1 onto that flag.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
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
      createdAt: n.createdAt);

  Future<void> _open(NotificationItem n) async {
    if (!n.isRead) {
      setState(() {
        final i = _items.indexWhere((it) => it.id == n.id);
        if (i != -1) _items[i] = _withRead(n);
      });
      try {
        await ApiClient.post('/notifications/${n.id}/read');
      } catch (_) {}
    }
    if (!mounted) return;
    openNotificationTarget(context, n);
  }

  // All / Rooms / Matches / Social / Coins.
  String _filter = 'all';
  final Set<String> _followedBack = {};

  static const _filters = [
    ('all', 'All'),
    ('rooms', 'Rooms'),
    ('matches', 'Matches'),
    ('social', 'Social'),
    ('coins', 'Coins'),
  ];

  static String _group(String type) => switch (type) {
        'room_invite' ||
        'event_reminder' ||
        'blend_invite' ||
        'blend_watch' ||
        'friend_online' =>
          'rooms',
        'match' => 'matches',
        'gift' ||
        'gift_received' ||
        'cashout_requested' ||
        'cashout' ||
        'reward' =>
          'coins',
        _ => 'social',
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

  /// The one-tap action on a row, when the type has one.
  Widget? _action(NotificationItem n) {
    Widget pill(String label, VoidCallback onTap, {bool filled = true}) =>
        filled
            ? FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: Text(label, style: const TextStyle(fontSize: 12.5)),
              )
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: Text(label, style: const TextStyle(fontSize: 12.5)),
              );
    switch (n.type) {
      case 'room_invite' || 'blend_invite' || 'blend_watch':
        return pill('Join', () => _open(n));
      case 'match':
        return pill('Say hi', () => _open(n));
      case 'follow':
        final id = n.data?['fromUserId'] as String?;
        if (id == null) return null;
        return _followedBack.contains(id)
            ? pill('Following', () {}, filled: false)
            : pill('Follow back', () => _followBack(n));
      case 'friend_request':
        return pill('View', () => _open(n), filled: false);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).toList();
    final shown = _filter == 'all'
        ? _items
        : _items.where((n) => _group(n.type) == _filter).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final sections = <(String, List<NotificationItem>)>[
      (
        'TODAY',
        shown.where((n) => !n.createdAt.toLocal().isBefore(today)).toList()
      ),
      (
        'THIS WEEK',
        shown
            .where((n) =>
                n.createdAt.toLocal().isBefore(today) &&
                !n.createdAt.toLocal().isBefore(weekAgo))
            .toList()
      ),
      (
        'EARLIER',
        shown.where((n) => n.createdAt.toLocal().isBefore(weekAgo)).toList()
      ),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const InsyncPageTitle('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read',
                    style: TextStyle(color: AppColors.primary, fontSize: 12))),
        ],
      ),
      body: _loading
          ? const Center(child: Spinner())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'No notifications yet. Invites, likes and gifts will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textFaint)),
                ))
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(children: [
                        for (final (id, label) in _filters)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _filter == id,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _filter = id),
                            ),
                          ),
                      ]),
                    ),
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Nothing here yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textFaint)),
                      ),
                    for (final (label, list) in sections)
                      if (list.isNotEmpty) ...[
                        _sectionLabel(label),
                        ...list.map(_row),
                      ],
                  ],
                ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
      );

  Widget _row(NotificationItem n) {
    final action = _action(n);
    return GestureDetector(
      onTap: () => _open(n),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: insyncClay(radius: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: notificationColors(n.type))),
              alignment: Alignment.center,
              child: InIcon(notificationIcon(n.type),
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight:
                              n.isRead ? FontWeight.normal : FontWeight.w700)),
                  if (n.body.isNotEmpty)
                    Text(n.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12)),
                  const SizedBox(height: 1),
                  Text(formatRelativeTime(n.createdAt),
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action],
            if (!n.isRead) ...[
              const SizedBox(width: 8),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.accent)),
            ],
          ],
        ),
      ),
    );
  }
}
