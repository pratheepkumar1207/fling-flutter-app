import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

class MessageThreadScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;

  const MessageThreadScreen({super.key, required this.userId, required this.name, this.avatarUrl});

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<DirectMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocket());
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/messages/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _messages = (data as List).map((e) => DirectMessage.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bindSocket() {
    final socket = context.read<SocketService>().socket;
    socket?.on('dm:message', (data) {
      if (!mounted || data is! Map) return;
      final msg = DirectMessage.fromJson(Map<String, dynamic>.from(data));
      if (msg.senderId != widget.userId) return;
      setState(() => _messages = [..._messages, msg]);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = await ApiClient.post('/messages/${widget.userId}', body: {'text': text});
      final msg = DirectMessage.fromJson(data as Map<String, dynamic>);
      setState(() {
        _messages = [..._messages, msg];
        _textController.clear();
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Avatar(src: widget.avatarUrl, name: widget.name, size: AvatarSize.sm),
            const SizedBox(width: 10),
            Text(widget.name),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet — say hi!', style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = m.senderId == myId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: mine ? AppColors.primary : AppColors.surface2,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.text)),
                            ),
                          );
                        },
                      ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(hintText: 'Message…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const Spinner(size: 18) : const Icon(Icons.send, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
