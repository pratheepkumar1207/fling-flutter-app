import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import '../feed/post_detail_screen.dart';
import '../party/party_screen.dart';

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
        _items = (data as List).map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
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
      setState(() => _items = _items.map((n) => n.isRead ? n : _withRead(n)).toList());
    } catch (_) {}
  }

  NotificationItem _withRead(NotificationItem n) =>
      NotificationItem(id: n.id, type: n.type, title: n.title, body: n.body, data: n.data, isRead: true, createdAt: n.createdAt);

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
    if (n.type == 'room_invite') {
      final roomId = n.data?['roomId'] as String?;
      if (roomId != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
    } else if (n.type == 'mention') {
      final postId = n.data?['postId'] as String?;
      if (postId != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)));
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'room_invite' => Icons.meeting_room_rounded,
        'mention' => Icons.alternate_email_rounded,
        _ => Icons.notifications_rounded,
      };

  List<Color> _colorsFor(String type) => switch (type) {
        'room_invite' => const [AppColors.accent2, AppColors.primary],
        'mention' => const [AppColors.gold, Color(0xFFC98F3A)],
        _ => const [AppColors.accent, AppColors.primaryDim],
      };

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).toList();
    final read = _items.where((n) => n.isRead).toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(onPressed: _markAllRead, child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 12))),
        ],
      ),
      body: _loading
          ? const Center(child: Spinner())
          : _items.isEmpty
              ? const Center(child: Text('No notifications yet.', style: TextStyle(color: AppColors.textFaint)))
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    if (unread.isNotEmpty) ...[_sectionLabel('New'), ...unread.map(_row)],
                    if (read.isNotEmpty) ...[_sectionLabel('Earlier'), ...read.map(_row)],
                  ],
                ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(text, style: const TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );

  Widget _row(NotificationItem n) {
    return GestureDetector(
      onTap: () => _open(n),
      child: Container(
        color: n.isRead ? null : AppColors.accent.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: _colorsFor(n.type))),
              alignment: Alignment.center,
              child: Icon(_iconFor(n.type), color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700)),
                  if (n.body.isNotEmpty)
                    Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  const SizedBox(height: 1),
                  Text(formatRelativeTime(n.createdAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
            ),
            if (!n.isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}
