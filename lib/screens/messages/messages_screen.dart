import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<ConversationSummary> get _filtered {
    if (_query.trim().isEmpty) return _conversations;
    final q = _query.trim().toLowerCase();
    return _conversations.where((c) => c.name.toLowerCase().contains(q)).toList();
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
    final results = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          if (_conversations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 16, color: AppColors.textFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(color: AppColors.text, fontSize: 13),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Search', hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
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
                    : results.isEmpty
                        ? const Center(child: Text('No matches.', style: TextStyle(color: AppColors.textFaint)))
                        : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final c = results[i];
                    final unread = c.unreadCount > 0;
                    return GestureDetector(
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => MessageThreadScreen(userId: c.userId, name: c.name, avatarUrl: c.avatarUrl)))
                          .then((_) => _load()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => openProfile(context, c.userId),
                              child: Avatar(src: c.avatarUrl, name: c.name, size: AvatarSize.md),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text, fontWeight: unread ? FontWeight.w700 : FontWeight.w600, fontSize: 14)),
                                      ),
                                      Text(formatRelativeTime(c.lastMessageAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c.lastMessageIsMine ? 'You: ' : ''}${c.lastMessage}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: unread ? AppColors.text : AppColors.textFaint, fontWeight: unread ? FontWeight.w600 : FontWeight.normal, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: 8),
                              Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
