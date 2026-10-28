import '../../widgets/permission_primer.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/chat_stickers.dart';
import '../../core/profile_nav.dart';
import '../../core/socket_service.dart';
import '../../models/blend.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/chat_media.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/read_ticks.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../blend/blend_entry.dart';
import '../calls/call_screen.dart';
import '../lobby/lobby_create_screen.dart';

/// The reactions offered on long-press, same list the backend accepts.
const kChatReactions = ['❤️', '😂', '😮', '😢', '🔥', '👍'];

/// A 1:1 chat: day separators, grouped bubbles, reply quotes, reactions,
/// "Seen", typing, quick actions (watch, game, gift) and the composer.
class MessageThreadScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;

  /// Shown instead of loading from the server (widget tests).
  @visibleForTesting
  final List<DirectMessage>? initialMessages;

  const MessageThreadScreen(
      {super.key,
      required this.userId,
      required this.name,
      this.avatarUrl,
      this.initialMessages});

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
  bool _online = false;
  // The Reels Blend with this person, once one exists — shown as a card
  // above the message box.
  Blend? _blend;
  DateTime? _matchedAt;
  DirectMessage? _replyTo;
  bool _hasText = false;

  // "typing…" from them, cleared a few seconds after the last ping.
  bool _theyTyping = false;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    final initial = widget.initialMessages;
    if (initial != null) {
      _messages = initial;
      _loading = false;
      _scrollToBottom();
      return;
    }
    _load();
    _loadOnlineStatus();
    _loadBlend();
    _loadMatch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocket());
  }

  String get _firstName => widget.name.split(' ').first;

  void _onTextChanged() {
    final has = _textController.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (!has) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inSeconds < 3) return;
    _lastTypingSent = now;
    _socket?.emit('dm:typing', {'toUserId': widget.userId});
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final data = await ApiClient.get('/creators/${widget.userId}/profile')
          as Map<String, dynamic>;
      if (mounted) setState(() => _online = data['online'] == true);
    } catch (_) {}
  }

  Future<void> _loadBlend() async {
    try {
      final data = await ApiClient.get('/blends/with/${widget.userId}');
      if (mounted && data is Map) {
        setState(
            () => _blend = Blend.fromJson(Map<String, dynamic>.from(data)));
      }
    } catch (_) {}
  }

  Future<void> _loadMatch() async {
    try {
      final data = await ApiClient.get('/swipe/matches');
      for (final m in (data as List).cast<Map>()) {
        if (m['userId'] == widget.userId) {
          final at = DateTime.tryParse('${m['matchedAt'] ?? ''}');
          if (mounted && at != null) setState(() => _matchedAt = at);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _openBlend() async {
    final blend = await showDmBlendSheet(context, widget.userId);
    if (mounted && blend != null) setState(() => _blend = blend);
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/messages/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _messages = (data as List)
            .map((e) => DirectMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDm(dynamic data) {
    if (!mounted || data is! Map) return;
    final msg = DirectMessage.fromJson(Map<String, dynamic>.from(data));
    if (msg.senderId != widget.userId) return;
    _typingTimer?.cancel();
    setState(() {
      _messages = [..._messages, msg];
      _theyTyping = false;
    });
    _scrollToBottom();
  }

  void _onDeleted(dynamic data) {
    if (!mounted || data is! Map) return;
    if (data['otherUserId'] != widget.userId) return;
    setState(
        () => _messages = _messages.where((m) => m.id != data['id']).toList());
  }

  void _onRead(dynamic data) {
    if (!mounted || data is! Map || data['otherUserId'] != widget.userId) {
      return;
    }
    final at = DateTime.tryParse('${data['readAt']}') ?? DateTime.now();
    setState(() => _messages = [
          for (final m in _messages)
            m.recipientId == widget.userId && m.readAt == null
                ? m.copyWith(readAt: at)
                : m
        ]);
  }

  void _onReaction(dynamic data) {
    if (!mounted || data is! Map || data['otherUserId'] != widget.userId) {
      return;
    }
    _setReactions(
        '${data['id']}', DirectMessage.reactionsFrom(data['reactions']));
  }

  void _onTyping(dynamic data) {
    if (!mounted || data is! Map || data['fromUserId'] != widget.userId) {
      return;
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _theyTyping = false);
    });
    if (!_theyTyping) {
      setState(() => _theyTyping = true);
      _scrollToBottom();
    }
  }

  late final _handlers = <String, void Function(dynamic)>{
    'dm:message': _onDm,
    'dm:deleted': _onDeleted,
    'dm:read': _onRead,
    'dm:reaction': _onReaction,
    'dm:typing': _onTyping,
  };

  io.Socket? _socket;

  void _bindSocket() {
    _socket = context.read<SocketService>().socket;
    _handlers.forEach((e, h) => _socket?.on(e, h));
  }

  void _setReactions(String id, Map<String, String> reactions) {
    setState(() => _messages = [
          for (final m in _messages)
            m.id == id ? m.copyWith(reactions: reactions) : m
        ]);
  }

  Future<void> _react(DirectMessage m, String emoji) async {
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final before = m.reactions;
    final next = Map<String, String>.from(before);
    if (next[myId] == emoji) {
      next.remove(myId);
    } else {
      next[myId] = emoji;
    }
    _setReactions(m.id, next);
    try {
      final data = await ApiClient.post('/messages/${m.id}/react',
          body: {'emoji': emoji}) as Map<String, dynamic>;
      if (mounted) {
        _setReactions(m.id, DirectMessage.reactionsFrom(data['reactions']));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _setReactions(m.id, before);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteMessage(DirectMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes it for both of you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final previous = _messages;
    setState(
        () => _messages = _messages.where((m) => m.id != message.id).toList());
    try {
      await ApiClient.delete('/messages/${message.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _messages = previous);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Long-press: react, reply, copy, delete.
  /// Long-press: the reaction bar above the message and a small menu under
  /// it (Reply, Copy, Delete for both), over a dimmed chat.
  void _openMessageActions(DirectMessage m, bool mine, String? myId) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialog, _, __) {
        void close() => Navigator.of(dialog).pop();
        Widget action(InIconData icon, String label, VoidCallback onTap,
                {Color? color, bool first = false}) =>
            InkWell(
              onTap: () {
                close();
                onTap();
              },
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: first
                    ? null
                    : const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  InIcon(icon, size: 19, color: color ?? AppColors.lilac),
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color ?? AppColors.text)),
                ]),
              ),
            );
        // Transparent Material so text gets the app's font and theme.
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Material(
                    color: AppColors.surface2,
                    shape: const StadiumBorder(
                        side: BorderSide(color: AppColors.border)),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      // One line always: shrinks on narrow phones.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (final e in kChatReactions)
                            Semantics(
                              button: true,
                              selected: m.reactions[myId] == e,
                              label: 'React $e',
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  close();
                                  _react(m, e);
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: m.reactions[myId] == e
                                          ? const Color(0xFF3B2A55)
                                          : Colors.transparent),
                                  child: Text(e,
                                      style: const TextStyle(fontSize: 24)),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(dialog).size.width * 0.76),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.primary : const Color(0xFF1F1C29),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(m.summary,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: mine ? Colors.white : AppColors.text,
                            fontSize: 15,
                            height: 1.35,
                            decoration: TextDecoration.none)),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.surface2,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.border)),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 220,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        action(InIcons.undo, 'Reply',
                            () => setState(() => _replyTo = m),
                            first: true),
                        if (m.messageType == 'text')
                          action(
                              InIcons.copy,
                              'Copy',
                              () => Clipboard.setData(
                                  ClipboardData(text: m.text))),
                        if (mine)
                          action(InIcons.close, 'Delete for both',
                              () => _deleteMessage(m),
                              color: const Color(0xFFFF8A9F)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _messageContent(DirectMessage m, bool mine) {
    if (m.messageType == 'image' && m.mediaUrl != null) {
      return ChatPhoto(m.mediaUrl!);
    }
    if (m.messageType == 'voice' && m.mediaUrl != null) {
      return ChatVoiceNote(m.mediaUrl!, mine: mine);
    }
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
            child: Text('Could not load GIF',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
        ),
      );
    }
    return Text(m.text,
        style: TextStyle(
            color: mine ? Colors.white : AppColors.text,
            fontSize: 15,
            height: 1.35));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // The list is reversed, so offset 0 is the newest message.
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    await _sendBody({'text': text}, clearText: true);
  }

  Future<void> _sendPhoto() async {
    final uri = await pickChatPhoto();
    if (uri == null || !mounted) return;
    await _sendBody({'messageType': 'image', 'mediaUrl': uri});
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
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'https://…')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    await _sendBody({'messageType': 'gif', 'mediaUrl': url});
  }

  Future<void> _startCall(bool video) async {
    await ensurePermissionPrimer(context);
    if (!mounted) return;
    try {
      final data = await ApiClient.post('/calls/direct-invite', body: {
        'toUserId': widget.userId,
        'mode': video ? 'video' : 'audio'
      }) as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: data['channelName'] as String,
          token: data['token'] as String,
          uid: data['uid'] as int,
          video: video,
          isCaller: true,
          peerId: widget.userId,
          peerName: widget.name,
          peerAvatarUrl: widget.avatarUrl,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _sendBody(Map<String, dynamic> body,
      {bool clearText = false}) async {
    if (_sending) return;
    final replyTo = _replyTo;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = await ApiClient.post('/messages/${widget.userId}',
          body: {...body, if (replyTo != null) 'replyToId': replyTo.id});
      final msg = DirectMessage.fromJson(data as Map<String, dynamic>);
      setState(() {
        _messages = [..._messages, msg];
        _replyTo = null;
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

  /// The + button: photo, sticker or GIF.
  void _openAttach() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const InIcon(InIcons.image, size: 20),
            title: const Text('Photo'),
            onTap: () {
              Navigator.of(sheet).pop();
              _sendPhoto();
            },
          ),
          ListTile(
            leading: const InIcon(InIcons.smile, size: 20),
            title: const Text('Sticker'),
            onTap: () {
              Navigator.of(sheet).pop();
              _openStickerPicker();
            },
          ),
          ListTile(
            leading: const InIcon(InIcons.gif, size: 20),
            title: const Text('GIF'),
            onTap: () {
              Navigator.of(sheet).pop();
              _pasteGifLink();
            },
          ),
        ]),
      ),
    );
  }

  void _openRoomCreate(String type) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LobbyCreateScreen(initialRoomType: type)));

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    final entries = _entries(myId);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: Color(0xFF1E1B27)),
            Expanded(
              child: _loading
                  ? const Center(child: Spinner())
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: entries.length,
                      itemBuilder: (context, i) =>
                          entries[entries.length - 1 - i],
                    ),
            ),
            if (_blend != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: BlendCard(blend: _blend!, compact: true),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            _quickActions(),
            if (_replyTo != null) _replyBar(myId),
            _composer(),
          ],
        ),
      ),
    );
  }

  /// Match note, day separators, bubbles with their group's time, Seen,
  /// and the typing bubble.
  List<Widget> _entries(String? myId) {
    final out = <Widget>[];
    if (_matchedAt != null) {
      out.add(_MatchNote(name: _firstName, matchedAt: _matchedAt!));
    }
    if (_messages.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Say hi to $_firstName',
              style: const TextStyle(color: AppColors.textFaint)),
        ),
      ));
    }
    final byId = {for (final m in _messages) m.id: m};
    final lastMine =
        _messages.lastIndexWhere((m) => m.senderId == myId); // for "Seen"
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final prev = i > 0 ? _messages[i - 1] : null;
      final next = i + 1 < _messages.length ? _messages[i + 1] : null;
      final local = m.createdAt.toLocal();
      if (prev == null || !_sameDay(prev.createdAt.toLocal(), local)) {
        out.add(_DaySeparator(local));
      }
      bool together(DirectMessage? a, DirectMessage b) =>
          a != null &&
          a.senderId == b.senderId &&
          _sameDay(a.createdAt.toLocal(), b.createdAt.toLocal()) &&
          b.createdAt.difference(a.createdAt).inMinutes.abs() < 5;
      final first = !together(prev, m);
      final last = next == null || !together(m, next);
      final mine = m.senderId == myId;
      final quoted = m.replyToId == null ? null : byId[m.replyToId];
      out.add(_Bubble(
        key: ValueKey(m.id),
        mine: mine,
        first: first,
        last: last,
        quoteName: quoted == null
            ? null
            : quoted.senderId == myId
                ? 'You'
                : _firstName,
        quoteText:
            quoted?.summary ?? (m.replyToId != null ? 'Message deleted' : null),
        reactions: m.reactions.values.toList(),
        onLongPress: () => _openMessageActions(m, mine, myId),
        child: _messageContent(m, mine),
      ));
      if (last) {
        final time = DateFormat.jm().format(local);
        final seen = mine && i == lastMine;
        out.add(_Meta(
          mine: mine,
          text: seen
              ? (m.readAt != null
                  ? 'Seen ${DateFormat.jm().format(m.readAt!.toLocal())}'
                  : 'Sent $time')
              : time,
          seen: seen && m.readAt != null,
        ));
      }
    }
    if (_theyTyping) out.add(_TypingBubble(name: _firstName));
    return out;
  }

  Widget _quickActions() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        children: [
          _QuickAction(
              icon: InIcons.tv,
              label: 'Invite to watch',
              onTap: () => _openRoomCreate('watch')),
          _QuickAction(
              icon: InIcons.game,
              label: 'Play a game',
              onTap: () => _openRoomCreate('game')),
          _QuickAction(
              icon: InIcons.gift,
              label: 'Gift',
              iconColor: AppColors.gold,
              onTap: () =>
                  showGiftBottomSheet(context, toUserId: widget.userId)),
        ],
      ),
    );
  }

  Widget _replyBar(String? myId) {
    final r = _replyTo!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            const Border(left: BorderSide(color: AppColors.lilac, width: 3)),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                r.senderId == myId
                    ? 'Replying to yourself'
                    : 'Replying to $_firstName',
                style: const TextStyle(
                    color: AppColors.lilac,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(r.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          ]),
        ),
        InIconButton(InIcons.close,
            tooltip: 'Cancel reply',
            size: 40,
            iconSize: 18,
            color: AppColors.textDim,
            onPressed: () => setState(() => _replyTo = null)),
      ]),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF1E1B27)))),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Tooltip(
              message: 'Photo, sticker or GIF',
              child: Material(
                color: AppColors.surface2,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : _openAttach,
                  child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: InIcon(InIcons.plus, size: 20))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.only(left: 16, right: 4),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 15),
                      decoration: InputDecoration(
                          hintText: 'Message $_firstName…',
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12)),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  if (!_hasText)
                    InIconButton(InIcons.camera,
                        tooltip: 'Send a photo',
                        size: 36,
                        iconSize: 20,
                        color: AppColors.textDim,
                        onPressed: _sending ? null : _sendPhoto),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Mic while the box is empty, Send once there's text.
            if (_hasText)
              Semantics(
                button: true,
                label: 'Send',
                child: InkResponse(
                  onTap: _sending ? null : _send,
                  radius: 26,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: _sending
                        ? const Spinner(size: 16)
                        : const InIcon(InIcons.send,
                            size: 20, color: Colors.white),
                  ),
                ),
              )
            else
              VoiceRecordButton(
                  size: 44,
                  filled: true,
                  onRecorded: (uri) =>
                      _sendBody({'messageType': 'voice', 'mediaUrl': uri})),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
      child: Row(children: [
        InIconButton(InIcons.back,
            tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open ${widget.name}\'s profile',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openProfile(context, widget.userId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Stack(children: [
                    Avatar(
                        src: widget.avatarUrl,
                        name: widget.name,
                        size: AvatarSize.sm),
                    if (_online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.bg, width: 2)),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        if (_theyTyping)
                          const Text('typing…',
                              style: TextStyle(
                                  color: AppColors.lilac,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))
                        else if (_online)
                          const Text('Active now',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        InIconButton(InIcons.blend,
            tooltip: 'Reels Blend',
            color: AppColors.lilac,
            onPressed: _openBlend),
        InIconButton(InIcons.phone,
            tooltip: 'Audio call', onPressed: () => _startCall(false)),
        InIconButton(InIcons.video,
            tooltip: 'Video call', onPressed: () => _startCall(true)),
      ]),
    );
  }

  @override
  void dispose() {
    _handlers.forEach((e, h) => _socket?.off(e, h));
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _MatchNote extends StatelessWidget {
  final String name;
  final DateTime matchedAt;
  const _MatchNote({required this.name, required this.matchedAt});

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(matchedAt).inDays;
    final when = days <= 0
        ? 'today'
        : days == 1
            ? 'yesterday'
            : '$days days ago';
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const InIcon(InIcons.heart, size: 14, color: AppColors.pink),
          const SizedBox(width: 8),
          Flexible(
            child: Text('You matched with $name $when',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime day;
  const _DaySeparator(this.day);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = _sameDay(day, now)
        ? 'TODAY'
        : _sameDay(day, now.subtract(const Duration(days: 1)))
            ? 'YESTERDAY'
            : DateFormat(day.year == now.year ? 'EEE, d MMM' : 'd MMM y')
                .format(day)
                .toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool mine;
  final bool first;
  final bool last;
  final String? quoteName;
  final String? quoteText;
  final List<String> reactions;
  final VoidCallback onLongPress;
  final Widget child;
  const _Bubble(
      {super.key,
      required this.mine,
      required this.first,
      required this.last,
      required this.reactions,
      required this.onLongPress,
      required this.child,
      this.quoteName,
      this.quoteText});

  @override
  Widget build(BuildContext context) {
    // Grouped bubbles: the corner on the sender's side is tight except at
    // the very top of the group.
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: mine || first ? big : small,
      topRight: !mine || first ? big : small,
      bottomLeft: mine ? big : small,
      bottomRight: mine ? small : big,
    );
    final bubble = Container(
      padding: quoteText != null
          ? const EdgeInsets.fromLTRB(8, 8, 8, 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : const Color(0xFF1F1C29),
        borderRadius: radius,
      ),
      child: quoteText == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.black.withValues(alpha: 0.18)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                          left: BorderSide(color: AppColors.lilac, width: 3)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (quoteName != null)
                            Text(quoteName!,
                                style: TextStyle(
                                    color: mine
                                        ? const Color(0xFFE2CCFF)
                                        : AppColors.lilac,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          Text(quoteText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: mine
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppColors.textDim,
                                  fontSize: 12.5)),
                        ]),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: child),
                ]),
    );
    return Padding(
      padding: EdgeInsets.only(
          top: first ? 6 : 2, bottom: reactions.isEmpty ? 0 : 12),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Stack(clipBehavior: Clip.none, children: [
            bubble,
            if (reactions.isNotEmpty)
              Positioned(
                bottom: -14,
                right: mine ? 10 : null,
                left: mine ? null : 10,
                child: Semantics(
                  label: 'Reactions ${reactions.join(' ')}',
                  excludeSemantics: true,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1F1C29),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bg, width: 2)),
                    child: Text(reactions.toSet().join(),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Time under a group, or "Seen 8:53 PM" under my last message.
class _Meta extends StatelessWidget {
  final bool mine;
  final String text;
  final bool seen;
  const _Meta({required this.mine, required this.text, required this.seen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 6),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(text,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
          if (seen) ...[
            const SizedBox(width: 4),
            const ReadTicks(seen: true, color: AppColors.lilac, size: 15),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final String name;
  const _TypingBubble({required this.name});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name is typing',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: const BoxDecoration(
            color: Color(0xFF1F1C29),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final o in [1.0, 0.7, 0.4]) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: AppColors.textDim.withValues(alpha: o),
                    shape: BoxShape.circle),
              ),
              if (o != 0.4) const SizedBox(width: 5),
            ],
          ]),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final InIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.iconColor = const Color(0xFFE2CCFF)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: const Color(0xFF1A1326),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF3B2A55))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InIcon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFFE2CCFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
