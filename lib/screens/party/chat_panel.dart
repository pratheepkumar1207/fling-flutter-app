import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/club_room_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/glass.dart';
import '../../widgets/chat_attachment_sheet.dart';

class ChatPanel extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  // mentionedUserIds are exactly the roster userIds picked via the @mention
  // suggestion list (see _selectMention) — see chat_overlay.dart's matching
  // doc comment for why this isn't parsed back out of the text instead.
  final void Function(String text, List<String> mentionedUserIds) onSend;
  final String? myUserId;

  /// Voice Room's ClubRoom-matched palette instead of the app's normal
  /// theme — see club_room_colors.dart and party_screen.dart's isVoice.
  final bool clubRoomTheme;

  // Same mic/poll/gift/invite quick actions as chat_overlay.dart's input
  // bar — see that widget for why they live here now instead of only in
  // the room's own floating action rail.
  final List<RosterEntry> roster;
  final bool myMicOn;
  final bool myMicRequested;
  final VoidCallback onMicTap;
  final VoidCallback onPoll;
  final VoidCallback onGift;
  final VoidCallback onInvite;

  const ChatPanel({
    super.key,
    required this.messages,
    required this.onSend,
    this.myUserId,
    this.clubRoomTheme = false,
    required this.roster,
    required this.myMicOn,
    required this.myMicRequested,
    required this.onMicTap,
    required this.onPoll,
    required this.onGift,
    required this.onInvite,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  // Non-null while the text after the last '@' looks like an in-progress
  // handle (no whitespace yet) — drives the mention suggestion list. Empty
  // string matches "just typed @", not "no @ at all".
  String? _mentionQuery;
  final Set<String> _mentionedUserIds = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateMentionQuery);
  }

  @override
  void didUpdateWidget(covariant ChatPanel old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  void _updateMentionQuery() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final upToCursor = text.substring(0, cursor);
    final at = upToCursor.lastIndexOf('@');
    if (at == -1 || (at > 0 && !RegExp(r'\s').hasMatch(upToCursor[at - 1]))) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final query = upToCursor.substring(at + 1);
    if (RegExp(r'\s').hasMatch(query)) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    setState(() => _mentionQuery = query);
  }

  void _selectMention(RosterEntry participant) {
    final handle = participant.username ?? participant.name;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final upToCursor = cursor >= 0 ? text.substring(0, cursor) : text;
    final at = upToCursor.lastIndexOf('@');
    if (at == -1) return;
    final before = text.substring(0, at);
    final after = cursor >= 0 ? text.substring(cursor) : '';
    final insert = '@$handle ';
    _controller.value = TextEditingValue(
      text: '$before$insert$after',
      selection: TextSelection.collapsed(offset: (before + insert).length),
    );
    _mentionedUserIds.add(participant.userId);
    setState(() => _mentionQuery = null);
  }

  List<RosterEntry> get _mentionMatches {
    final query = _mentionQuery;
    if (query == null) return const [];
    final q = query.toLowerCase();
    return widget.roster
        .where((p) {
          if (widget.myUserId != null && p.userId == widget.myUserId) {
            return false;
          }
          final handle = (p.username ?? p.name).toLowerCase();
          return handle.contains(q);
        })
        .take(6)
        .toList();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, _mentionedUserIds.toList());
    _controller.clear();
    _mentionedUserIds.clear();
    setState(() => _mentionQuery = null);
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.clubRoomTheme;
    final textFaint = club ? ClubRoomColors.textFaint : AppColors.textFaint;
    final text = club ? ClubRoomColors.text : AppColors.text;
    final textDim = club ? ClubRoomColors.textDim : AppColors.textDim;
    final primary = club ? ClubRoomColors.primary : AppColors.primary;
    final bubbleOther = club ? ClubRoomColors.surface2 : AppColors.surface2;
    final matches = _mentionMatches;
    return Column(
      children: [
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Text('Say hi 👋',
                      style: TextStyle(color: textFaint, fontSize: 12)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, i) {
                    final m = widget.messages[i];
                    final isSystem = m['system'] == true;
                    if (isSystem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                            child: Text(m['text'] as String? ?? '',
                                style:
                                    TextStyle(color: textFaint, fontSize: 11))),
                      );
                    }
                    final ts = m['ts'];
                    final time = ts is num
                        ? formatClockTime(
                            DateTime.fromMillisecondsSinceEpoch(ts.toInt()))
                        : '';
                    final isMe = widget.myUserId != null &&
                        m['senderId'] == widget.myUserId;
                    final bubble = Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? primary : bubbleOther,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(m['text'] as String? ?? '',
                          style: TextStyle(
                              color: isMe ? Colors.white : textDim,
                              fontSize: 13)),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: isMe
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (time.isNotEmpty)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2, right: 2),
                                            child: Text(time,
                                                style: TextStyle(
                                                    color: textFaint,
                                                    fontSize: 10))),
                                      bubble,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Avatar(
                                    src: m['avatarUrl'] as String?,
                                    name: m['name'] as String?,
                                    size: AvatarSize.sm),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => openProfile(
                                      context, m['senderId'] as String?),
                                  child: Avatar(
                                      src: m['avatarUrl'] as String?,
                                      name: m['name'] as String?,
                                      size: AvatarSize.sm),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 2, left: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                m['name'] as String? ??
                                                    'Someone',
                                                style: TextStyle(
                                                    color: text,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12)),
                                            if (time.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(time,
                                                  style: TextStyle(
                                                      color: textFaint,
                                                      fontSize: 10)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      bubble,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
        ),
        if (matches.isNotEmpty)
          GlassPanel(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: matches.length,
                itemBuilder: (context, i) {
                  final p = matches[i];
                  final handle = p.username ?? p.name;
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Avatar(
                        src: p.avatarUrl, name: p.name, size: AvatarSize.sm),
                    title: Text('@$handle',
                        style: TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    onTap: () => _selectMention(p),
                  );
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GlassCircleButton(
                  size: 36,
                  onTap: widget.onMicTap,
                  color: widget.myMicOn
                      ? AppColors.danger
                      : (widget.myMicRequested
                          ? primary.withValues(alpha: 0.5)
                          : null),
                  child: Icon(widget.myMicOn ? Icons.mic : Icons.mic_off,
                      color: widget.myMicOn ? Colors.white : textDim, size: 17),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: TextStyle(color: text, fontSize: 13),
                        decoration: const InputDecoration(
                            hintText: 'Message…', isDense: true),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    _inlineIcon(
                        Icons.attach_file_rounded,
                        () => showChatAttachmentSheet(context,
                            onPoll: widget.onPoll),
                        textDim),
                    _inlineIcon(
                        Icons.card_giftcard_rounded, widget.onGift, textDim),
                    _inlineIcon(Icons.person_add_alt_1_rounded, widget.onInvite,
                        textDim),
                  ],
                ),
              ),
              IconButton(
                  onPressed: _send,
                  icon: Icon(Icons.send, size: 18, color: primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inlineIcon(IconData icon, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
          onTap: onTap, child: Icon(icon, color: color, size: 19)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
