import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/spinner.dart';
import 'message_thread_screen.dart';

/// Message requests: chats from people you haven't matched or befriended.
/// Accept moves one into your chats, Delete removes it (and stops them
/// starting another), and Block blocks them. They don't see "Seen" until
/// you accept or reply.
class MessageRequestsScreen extends StatefulWidget {
  /// Shown instead of loading from the server (widget tests).
  @visibleForTesting
  final List<ConversationSummary>? initialRequests;

  const MessageRequestsScreen({super.key, this.initialRequests});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  List<ConversationSummary> _requests = [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRequests;
    if (initial != null) {
      _requests = initial;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/messages/conversations');
      if (!mounted) return;
      setState(() {
        _requests = [
          for (final e in data as List)
            ConversationSummary.fromJson(e as Map<String, dynamic>)
        ].where((c) => c.isRequest).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _run(ConversationSummary c, Future<void> Function() call) async {
    setState(() => _busy.add(c.userId));
    try {
      await call();
      if (!mounted) return false;
      setState(() => _requests = _requests.where((r) => r != c).toList());
      return true;
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(c.userId));
    }
  }

  void _openChat(ConversationSummary c) => Navigator.of(context)
      .push(MaterialPageRoute(
          builder: (_) => MessageThreadScreen(
              userId: c.userId, name: c.name, avatarUrl: c.avatarUrl)))
      .then((_) => _load());

  Future<void> _accept(ConversationSummary c) async {
    final ok = await _run(
        c, () => ApiClient.post('/messages/requests/${c.userId}/accept'));
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MessageThreadScreen(
              userId: c.userId, name: c.name, avatarUrl: c.avatarUrl)));
    }
  }

  Future<void> _delete(ConversationSummary c) async {
    final ok =
        await _run(c, () => ApiClient.delete('/messages/requests/${c.userId}'));
    if (ok && mounted) _snack('Request from ${c.name} deleted');
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: Text(action,
                    style: const TextStyle(color: AppColors.pink))),
          ],
        ),
      ) ==
      true;

  Future<void> _block(ConversationSummary c) async {
    if (!await _confirm('Block ${c.name}?',
        'They won’t be able to message you or see you in Discover.', 'Block')) {
      return;
    }
    final ok = await _run(c, () => ApiClient.post('/social/block/${c.userId}'));
    if (ok && mounted) _snack('${c.name} is blocked');
  }

  Future<void> _deleteAll() async {
    final n = _requests.length;
    if (!await _confirm(
        'Delete all requests?',
        'All $n requests will be deleted. These people can’t send you a new one.',
        'Delete all')) {
      return;
    }
    for (final c in List.of(_requests)) {
      await _run(c, () => ApiClient.delete('/messages/requests/${c.userId}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
              child: Row(children: [
                InIconButton(InIcons.back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 2),
                const Expanded(
                  child: Text('Message requests',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: _SafetyNote()),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false, child: Center(child: Spinner(size: 28)))
          else if (_requests.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No message requests.',
                    style: TextStyle(color: AppColors.textFaint)),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        _requests.length == 1
                            ? '1 request'
                            : '${_requests.length} requests',
                        style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: _busy.isEmpty ? _deleteAll : null,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8A9F),
                        minimumSize: const Size(44, 44)),
                    child: const Text('Delete all',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
            SliverList.builder(
              itemCount: _requests.length,
              itemBuilder: (context, i) {
                final c = _requests[i];
                return _RequestCard(
                  c: c,
                  busy: _busy.contains(c.userId),
                  onOpen: () => _openChat(c),
                  onAccept: () => _accept(c),
                  onDelete: () => _delete(c),
                  onBlock: () => _block(c),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Color(0xFF12301F), shape: BoxShape.circle),
          child: const Center(
              child:
                  InIcon(InIcons.shield, size: 18, color: AppColors.success)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
              'These people haven’t matched with you. They won’t know you’ve '
              'read their message until you accept.',
              style: TextStyle(
                  color: Color(0xFFD9D6E2), fontSize: 13, height: 1.45)),
        ),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ConversationSummary c;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  const _RequestCard(
      {required this.c,
      required this.busy,
      required this.onOpen,
      required this.onAccept,
      required this.onDelete,
      required this.onBlock});

  @override
  Widget build(BuildContext context) {
    final info = c.requestInfo;
    final meta = info?.line ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => openProfile(context, c.userId),
                      child: Avatar(
                          src: c.avatarUrl, name: c.name, size: AvatarSize.md),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (info?.isVerified == true) ...[
                                const SizedBox(width: 6),
                                Semantics(
                                  label: 'Verified',
                                  child: const InIcon(InIcons.verified,
                                      size: 15, color: AppColors.blue),
                                ),
                              ],
                              const SizedBox(width: 8),
                              const Spacer(),
                              Text(formatRelativeTime(c.lastMessageAt),
                                  style: const TextStyle(
                                      color: AppColors.textDim, fontSize: 12)),
                            ]),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(meta,
                                  style: const TextStyle(
                                      color: AppColors.textDim,
                                      fontSize: 12.5)),
                            ],
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1F1C29),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16)),
                    ),
                    child: Text(c.lastMessage,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onAccept,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Accept',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onDelete,
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.border)),
                        child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Delete', maxLines: 1)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Block ${c.name}',
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(
                            side: BorderSide(color: AppColors.border)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: busy ? null : onBlock,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                                child: InIcon(InIcons.block,
                                    size: 18, color: AppColors.textDim)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ]),
          ),
        ),
      ),
    );
  }
}
