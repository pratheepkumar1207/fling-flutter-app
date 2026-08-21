import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/socket_service.dart';
import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../feed/post_detail_screen.dart';
import '../party/party_screen.dart';
import 'notifications_screen.dart';

/// Mirrors src/components/NotificationBell.jsx — fetches recent
/// notifications, shows an unread badge, and bumps in real time on the
/// `notification:new` socket event pushed by notifyUser() server-side.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<NotificationItem> _items = [];
  bool _bound = false;

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
    _bindSocket();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/notifications');
      if (!mounted) return;
      setState(() {
        _items = (data as List).map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {
      // Best-effort — bell just stays empty on failure.
    }
  }

  void _bindSocket() {
    if (_bound) return;
    final socket = context.read<SocketService>().socket;
    if (socket == null) return;
    _bound = true;
    socket.on('notification:new', (data) {
      if (!mounted || data is! Map) return;
      setState(() {
        _items = [NotificationItem.fromJson(Map<String, dynamic>.from(data)), ..._items];
      });
    });
  }

  Future<void> _openNotification(NotificationItem n) async {
    if (!n.isRead) {
      setState(() {
        _items = _items.map((it) => it.id == n.id
            ? NotificationItem(id: it.id, type: it.type, title: it.title, body: it.body, data: it.data, isRead: true, createdAt: it.createdAt)
            : it).toList();
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

  Future<void> _markAllRead() async {
    try {
      await ApiClient.post('/notifications/read-all');
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((n) => NotificationItem(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: Badge(
        isLabelVisible: _unreadCount > 0,
        label: Text('$_unreadCount'),
        backgroundColor: AppColors.primary,
        textColor: Colors.white,
        child: Image.asset('assets/icons/app/notification.png', width: 48, height: 48),
      ),
      color: AppColors.surface2,
      itemBuilder: (context) {
        if (_items.isEmpty) {
          return [
            const PopupMenuItem<void>(enabled: false, child: Text('No notifications yet', style: TextStyle(color: AppColors.textFaint))),
            PopupMenuItem<void>(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              child: const Text('See all', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ];
        }
        return [
          PopupMenuItem<void>(
            onTap: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
          ..._items.take(10).map(
                (n) => PopupMenuItem<void>(
                  onTap: () => _openNotification(n),
                  child: SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(n.title, style: TextStyle(color: AppColors.text, fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
                        if (n.body.isNotEmpty)
                          Text(n.body, style: const TextStyle(color: AppColors.textDim, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(formatRelativeTime(n.createdAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
          PopupMenuItem<void>(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            child: const Text('See all', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ];
      },
    );
  }
}
