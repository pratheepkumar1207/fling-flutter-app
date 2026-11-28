import 'package:flutter/material.dart';
import '../../widgets/animated_emoji.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/chat_media.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/people_picker_sheet.dart';
import '../../widgets/spinner.dart';
import '../../widgets/group_poll.dart';
import '../communities/community_home_screen.dart';
import '../../widgets/insync_snack.dart';

/// Create a group: name it, pick people. Returns the new group's id.
Future<String?> createGroupChat(BuildContext context) async {
  final people =
      await showPeoplePicker(context, title: 'New group', doneLabel: 'Next');
  if (people == null || people.isEmpty || !context.mounted) return null;
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Name the group'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(hintText: 'Movie gang'),
        onSubmitted: (v) => Navigator.of(dialog).pop(v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: const Text('Create')),
      ],
    ),
  );
  if (name == null || name.isEmpty || !context.mounted) return null;
  try {
    final g = await ApiClient.post('/groups', body: {
      'name': name,
      'memberIds': [for (final p in people) p.id],
    }) as Map<String, dynamic>;
    return g['id'] as String;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(insyncSnackBar(content: Text(e.message)));
    }
    return null;
  }
}

class GroupThreadScreen extends StatefulWidget {
  final String groupId;
  final String name;
  const GroupThreadScreen(
      {super.key, required this.groupId, required this.name});

  @override
  State<GroupThreadScreen> createState() => _GroupThreadScreenState();
}

class _GroupThreadScreenState extends State<GroupThreadScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  late String _name = widget.name;
  int _members = 0;
  // In a community: its name (tap to open it), and whether this is its
  // Announcements group, where only admins post and others react.
  String? _communityId;
  String? _communityName;
  bool _isAnnouncements = false;
  bool _canPost = true;
  bool _loading = true;
  bool _sending = false;
  bool _bound = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    final socket = context.read<SocketService>().socket;
    if (socket == null) return;
    _bound = true;
    socket.on('group:message', _onIncoming);
    socket.on('group:poll', _onPoll);
    socket.on('group:reaction', _onReaction);
  }

  void _patch(
      String id, Map<String, dynamic> Function(Map<String, dynamic>) f) {
    setState(() => _messages = [
          for (final m in _messages) m['id'] == id ? f(Map.of(m)) : m
        ]);
  }

  void _onPoll(dynamic data) {
    if (!mounted || data is! Map || data['groupId'] != widget.groupId) return;
    _patch(
        '${data['messageId']}', (m) => m..['pollCounts'] = data['pollCounts']);
  }

  void _onReaction(dynamic data) {
    if (!mounted || data is! Map || data['groupId'] != widget.groupId) return;
    _patch('${data['messageId']}', (m) => m..['reactions'] = data['reactions']);
  }

  Future<void> _vote(Map<String, dynamic> m, int? option) async {
    final id = m['id'] as String;
    try {
      final r = await ApiClient.post('/groups/messages/$id/vote',
          body: {'option': option}) as Map<String, dynamic>;
      if (!mounted) return;
      _patch(
          id,
          (x) => x
            ..['pollCounts'] = r['pollCounts']
            ..['myVote'] = r['myVote']);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(insyncSnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _react(Map<String, dynamic> m, String emoji) async {
    final id = m['id'] as String;
    try {
      final r = await ApiClient.post('/groups/messages/$id/react',
          body: {'emoji': emoji}) as Map<String, dynamic>;
      if (!mounted) return;
      _patch(
          id,
          (x) => x
            ..['reactions'] = r['reactions']
            ..['myReaction'] = r['myReaction']);
    } catch (_) {}
  }

  Future<void> _pickReaction(Map<String, dynamic> m) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF000000),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final e in groupReactions)
              Semantics(
                button: true,
                label: 'React $e',
                child: InkResponse(
                  onTap: () => Navigator.of(sheet).pop(e),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
              ),
          ]),
        ),
      ),
    );
    if (emoji != null) _react(m, emoji);
  }

  Future<void> _newPoll() async {
    final poll = await showCreatePollSheet(context);
    if (poll != null) _send({'messageType': 'poll', 'poll': poll});
  }

  void _onIncoming(dynamic data) {
    if (!mounted || data is! Map || data['groupId'] != widget.groupId) return;
    setState(() => _messages = [..._messages, Map<String, dynamic>.from(data)]);
    _toBottom();
  }

  @override
  void dispose() {
    final socket = context.read<SocketService>().socket;
    socket?.off('group:message', _onIncoming);
    socket?.off('group:poll', _onPoll);
    socket?.off('group:reaction', _onReaction);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/groups/${widget.groupId}/messages');
      if (!mounted) return;
      setState(() {
        _messages = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      _toBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInfo() async {
    try {
      final g = await ApiClient.get('/groups/${widget.groupId}')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name = g['name'] as String? ?? _name;
        _members = (g['members'] as List?)?.length ?? 0;
        _communityId = g['communityId'] as String?;
        _communityName = g['communityName'] as String?;
        _isAnnouncements = g['isAnnouncements'] == true;
        _canPost = g['canPost'] != false;
      });
    } catch (_) {}
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send(Map<String, dynamic> body, {bool clear = false}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final m =
          await ApiClient.post('/groups/${widget.groupId}/messages', body: body)
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, m];
        if (clear) _text.clear();
      });
      _toBottom();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(insyncSnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addPeople() async {
    final people =
        await showPeoplePicker(context, title: 'Add people', doneLabel: 'Add');
    if (people == null || people.isEmpty) return;
    try {
      await ApiClient.post('/groups/${widget.groupId}/members', body: {
        'userIds': [for (final p in people) p.id]
      });
      _loadInfo();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(insyncSnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text('You won’t get its messages any more.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.delete('/groups/${widget.groupId}/members/me');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(insyncSnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _content(Map<String, dynamic> m, bool mine) {
    final type = m['messageType'] as String? ?? 'text';
    final media = m['mediaUrl'] as String?;
    if (type == 'poll') {
      return GroupPollBubble(
          message: m, mine: mine, onVote: (o) => _vote(m, o));
    }
    if (type == 'image' && media != null) return ChatPhoto(media);
    if (type == 'voice' && media != null) {
      return ChatVoiceNote(media, mine: mine);
    }
    if (type == 'sticker' && media != null) {
      return Text(media, style: const TextStyle(fontSize: 40));
    }
    return ChatEmojiText(m['text'] as String? ?? '',
        style: TextStyle(
            color: mine ? Colors.white : AppColors.text, fontSize: 14));
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(children: [
              InIconButton(InIcons.back,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop()),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: InIcon(InIcons.users,
                        size: 18, color: AppColors.lilac)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (_communityName != null)
                        Semantics(
                          button: true,
                          label: 'Open community $_communityName',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => CommunityHomeScreen(
                                        communityId: _communityId!))),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const InIcon(InIcons.community,
                                  size: 12, color: AppColors.lilac),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(_communityName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.lilac, fontSize: 12)),
                              ),
                            ]),
                          ),
                        )
                      else if (_members > 0)
                        Text('$_members people',
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                    ]),
              ),
              if (!_isAnnouncements) ...[
                InIconButton(InIcons.useradd,
                    tooltip: 'Add people', onPressed: _addPeople),
                InIconButton(InIcons.logout,
                    tooltip: 'Leave group',
                    color: const Color(0xFFFF5266),
                    onPressed: _leave),
              ],
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFFFFFFF)),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Say hi to the group 👋',
                            style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          if (m['messageType'] == 'system') {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF000000),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(m['text'] as String? ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.textDim,
                                          fontSize: 12)),
                                ),
                              ),
                            );
                          }
                          final mine = m['senderId'] == myId;
                          // Same as lobby chat: theirs on the left, photo
                          // and name once per run, text under the name;
                          // yours on the right in a red bubble.
                          bool same(int j) =>
                              j >= 0 &&
                              j < _messages.length &&
                              _messages[j]['messageType'] != 'system' &&
                              _messages[j]['senderId'] == m['senderId'];
                          final continued = same(i - 1);
                          final nextContinues = same(i + 1);
                          final type = m['messageType'] as String? ?? 'text';
                          final plainText = type == 'text';
                          final maxW = MediaQuery.sizeOf(context).width * 0.72;
                          final Widget body = mine && plainText
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 9),
                                  constraints: BoxConstraints(maxWidth: maxW),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      bottomLeft: const Radius.circular(18),
                                      topRight:
                                          Radius.circular(continued ? 6 : 18),
                                      bottomRight: Radius.circular(
                                          nextContinues ? 6 : 18),
                                    ),
                                  ),
                                  child: _content(m, mine),
                                )
                              : ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxW),
                                  child: _content(m, mine));
                          // Long-press any message to react.
                          final reactable = GestureDetector(
                            onLongPress: () => _pickReaction(m),
                            child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  body,
                                  GroupReactionChips(
                                      message: m, onTap: (e) => _react(m, e)),
                                ]),
                          );
                          final gap =
                              EdgeInsets.only(bottom: nextContinues ? 3 : 12);
                          if (mine) {
                            return Padding(
                              padding: gap,
                              child: Align(
                                  alignment: Alignment.centerRight,
                                  child: reactable),
                            );
                          }
                          final name = m['senderName'] as String? ?? '';
                          return Padding(
                            padding: gap,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: continued
                                      ? null
                                      : SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: FittedBox(
                                            child: Avatar(
                                                src: m['senderAvatarUrl']
                                                    as String?,
                                                name: name,
                                                size: AvatarSize.sm),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!continued)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Text(name.split(' ').first,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                        reactable,
                                      ]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (!_canPost)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFFFFFFF)))),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: const Text(
                  'Only admins post here · long-press a message to react',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
            )
          else
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFFFFFFF)))),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(children: [
                InIconButton(InIcons.poll,
                    tooltip: 'Create a poll',
                    size: 38,
                    iconSize: 21,
                    onPressed: _sending ? null : _newPoll),
                InIconButton(InIcons.image,
                    tooltip: 'Send a photo',
                    size: 38,
                    iconSize: 21,
                    onPressed: _sending
                        ? null
                        : () async {
                            final uri = await pickChatPhoto();
                            if (uri != null) {
                              _send({'messageType': 'image', 'mediaUrl': uri});
                            }
                          }),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                        hintText: 'Message the group…', isDense: true),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        _send({'text': v.trim()}, clear: true);
                      }
                    },
                  ),
                ),
                VoiceRecordButton(
                    onRecorded: (uri) =>
                        _send({'messageType': 'voice', 'mediaUrl': uri})),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: 'Send',
                  child: InkResponse(
                    onTap: _sending
                        ? null
                        : () {
                            final v = _text.text.trim();
                            if (v.isNotEmpty) _send({'text': v}, clear: true);
                          },
                    radius: 26,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: _sending
                          ? const Spinner(size: 16)
                          : const InIcon(InIcons.send,
                              size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
