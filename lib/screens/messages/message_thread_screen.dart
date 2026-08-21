import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/chat_stickers.dart';
import '../../core/profile_nav.dart';
import '../../core/socket_service.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../calls/call_screen.dart';

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
    socket?.on('dm:deleted', (data) {
      if (!mounted || data is! Map) return;
      if (data['otherUserId'] != widget.userId) return;
      setState(() => _messages = _messages.where((m) => m.id != data['id']).toList());
    });
  }

  Future<void> _deleteMessage(DirectMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes it for both of you.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final previous = _messages;
    setState(() => _messages = _messages.where((m) => m.id != message.id).toList());
    try {
      await ApiClient.delete('/messages/${message.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _messages = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _messageContent(DirectMessage m, bool mine) {
    if (m.messageType == 'sticker' && m.mediaUrl != null) {
      return Text(m.mediaUrl!, style: const TextStyle(fontSize: 40));
    }
    if (m.messageType == 'gif' && m.mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          m.mediaUrl!,
          width: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Could not load GIF', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
        ),
      );
    }
    return Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.text));
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
    await _sendBody({'text': text}, clearText: true);
  }

  Future<void> _sendSticker(String emoji) async {
    Navigator.of(context).pop(); // close the picker sheet
    await _sendBody({'messageType': 'sticker', 'mediaUrl': emoji});
  }

  Future<void> _pasteGifLink() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Paste a GIF link'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'https://…')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    await _sendBody({'messageType': 'gif', 'mediaUrl': url});
  }

  Future<void> _startCall(bool video) async {
    try {
      final data = await ApiClient.post('/calls/direct-invite', body: {'toUserId': widget.userId, 'mode': video ? 'video' : 'audio'}) as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: data['channelName'] as String,
          token: data['token'] as String,
          uid: data['uid'] as int,
          video: video,
          isCaller: true,
          peerName: widget.name,
          peerAvatarUrl: widget.avatarUrl,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendBody(Map<String, dynamic> body, {bool clearText = false}) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = await ApiClient.post('/messages/${widget.userId}', body: body);
      final msg = DirectMessage.fromJson(data as Map<String, dynamic>);
      setState(() {
        _messages = [..._messages, msg];
        if (clearText) _textController.clear();
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kChatStickers
                .map((e) => GestureDetector(
                      onTap: () => _sendSticker(e),
                      child: Text(e, style: const TextStyle(fontSize: 32)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => openProfile(context, widget.userId),
          child: Row(
            children: [
              Avatar(src: widget.avatarUrl, name: widget.name, size: AvatarSize.sm),
              const SizedBox(width: 10),
              Text(widget.name),
            ],
          ),
        ),
        actions: [
          IconButton(onPressed: () => _startCall(false), icon: const Icon(Icons.call_rounded, color: AppColors.primary), tooltip: 'Audio call'),
          IconButton(onPressed: () => _startCall(true), icon: const Icon(Icons.videocam_rounded, color: AppColors.primary), tooltip: 'Video call'),
        ],
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
                            child: GestureDetector(
                              onLongPress: mine ? () => _deleteMessage(m) : null,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                decoration: BoxDecoration(
                                  gradient: mine ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppGradients.brand) : null,
                                  color: mine ? null : AppColors.surface2,
                                  // Flat corner on the "tail" side (bottom-right for mine, bottom-left
                                  // for theirs) — matches ChatDark.dc.html's speech-bubble shape.
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(mine ? 18 : 5),
                                    bottomRight: Radius.circular(mine ? 5 : 18),
                                  ),
                                ),
                                child: _messageContent(m, mine),
                              ),
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
                  IconButton(
                    onPressed: _sending ? null : _openStickerPicker,
                    icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textDim),
                    tooltip: 'Sticker',
                  ),
                  IconButton(
                    onPressed: _sending ? null : _pasteGifLink,
                    icon: const Icon(Icons.gif_box_outlined, color: AppColors.textDim),
                    tooltip: 'GIF',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(hintText: 'Message…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: AppGradients.brand), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: _sending ? const Spinner(size: 16) : const Icon(Icons.send_rounded, color: Colors.white, size: 17),
                    ),
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
