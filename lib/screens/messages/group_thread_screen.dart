import 'package:flutter/material.dart';
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
          .showSnackBar(SnackBar(content: Text(e.message)));
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
  }

  void _onIncoming(dynamic data) {
    if (!mounted || data is! Map || data['groupId'] != widget.groupId) return;
    setState(() => _messages = [..._messages, Map<String, dynamic>.from(data)]);
    _toBottom();
  }

  @override
  void dispose() {
    context.read<SocketService>().socket?.off('group:message', _onIncoming);
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
            .showSnackBar(SnackBar(content: Text(e.message)));
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
            .showSnackBar(SnackBar(content: Text(e.message)));
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
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _content(Map<String, dynamic> m, bool mine) {
    final type = m['messageType'] as String? ?? 'text';
    final media = m['mediaUrl'] as String?;
    if (type == 'image' && media != null) return ChatPhoto(media);
    if (type == 'voice' && media != null) {
      return ChatVoiceNote(media, mine: mine);
    }
    if (type == 'sticker' && media != null) {
      return Text(media, style: const TextStyle(fontSize: 40));
    }
    return Text(m['text'] as String? ?? '',
        style: TextStyle(color: mine ? Colors.white : AppColors.text));
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
                    color: const Color(0xFF1C1638),
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
                      if (_members > 0)
                        Text('$_members people',
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                    ]),
              ),
              InIconButton(InIcons.useradd,
                  tooltip: 'Add people', onPressed: _addPeople),
              InIconButton(InIcons.logout,
                  tooltip: 'Leave group',
                  color: const Color(0xFFFF8AA0),
                  onPressed: _leave),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFF1E1B27)),
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
                          final mine = m['senderId'] == myId;
                          final showName = !mine &&
                              (i == 0 ||
                                  _messages[i - 1]['senderId'] !=
                                      m['senderId']);
                          final bubble = Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.68),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.primary
                                  : const Color(0xFF1F1C29),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(mine ? 20 : 6),
                                bottomRight: Radius.circular(mine ? 6 : 20),
                              ),
                            ),
                            child: _content(m, mine),
                          );
                          if (mine) {
                            return Align(
                                alignment: Alignment.centerRight,
                                child: bubble);
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 32,
                                child: showName
                                    ? SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: FittedBox(
                                          child: Avatar(
                                              src: m['senderAvatarUrl']
                                                  as String?,
                                              name: m['senderName'] as String?,
                                              size: AvatarSize.sm),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (showName)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 4, top: 6),
                                          child: Text(
                                              m['senderName'] as String? ?? '',
                                              style: const TextStyle(
                                                  color: AppColors.lilac,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      bubble,
                                    ]),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E1B27)))),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(children: [
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
