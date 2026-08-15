import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/profile_nav.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import 'message_thread_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<ConversationSummary> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/messages/conversations');
      if (!mounted) return;
      setState(() {
        _conversations = (data as List).map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : _conversations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No conversations yet.\nMessage a friend, or a VIP can start a conversation with anyone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textFaint),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, i) {
                    final c = _conversations[i];
                    return ListTile(
                      leading: GestureDetector(
                        onTap: () => openProfile(context, c.userId),
                        child: Avatar(src: c.avatarUrl, name: c.name),
                      ),
                      title: Text(c.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        '${c.lastMessageIsMine ? 'You: ' : ''}${c.lastMessage}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textFaint),
                      ),
                      trailing: c.unreadCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                              child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            )
                          : null,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => MessageThreadScreen(userId: c.userId, name: c.name, avatarUrl: c.avatarUrl)))
                          .then((_) => _load()),
                    );
                  },
                ),
    );
  }
}
