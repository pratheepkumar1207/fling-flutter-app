import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../models/notification_item.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
import 'notifications_screen.dart';

/// Top-bar bell: unread badge from GET /notifications, bumped live by the
/// `notification:new` socket event. Tapping opens the Notifications screen.
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
        _items = (data as List)
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
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
        _items = [
          NotificationItem.fromJson(Map<String, dynamic>.from(data)),
          ..._items
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return InIconButton(
      InIcons.bell,
      tooltip: 'Notifications',
      size: 38,
      badge: _unreadCount,
      onPressed: () async {
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _load();
      },
    );
  }
}
