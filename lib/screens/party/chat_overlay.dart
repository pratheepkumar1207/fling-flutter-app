import 'package:flutter/material.dart';
import '../../core/profile_nav.dart';
import '../../models/room_models.dart';
import '../../widgets/avatar.dart';
import '../../widgets/chat_attachment_sheet.dart';
import '../../widgets/glass.dart';

// Deterministic per-sender name color, cycling through a small palette —
// matches WatchPartyDark.dc.html's floating chat, where each speaker's name
// is a distinct color instead of a uniform bubble color.
const _nameColors = [
  Color(0xFFDBB155), // gold
  Color(0xFFCC9DE8), // lilac
  Color(0xFF9DE8B8), // mint
  Color(0xFFE89D9D), // rose
  Color(0xFF9DC5E8), // sky
];

/// Floating, translucent chat — meant to sit inside a Stack over a room's
/// "stage" area (video, game board, voice speaker grid). Used identically
/// by every room type now (Watch/Voice/Game) so the bottom-chat experience
/// reads the same everywhere, not just Watch Party.
class ChatOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  // mentionedUserIds are exactly the roster userIds picked via the @mention
  // suggestion list below (see _selectMention), not parsed back out of the
  // text — display names/handles can contain spaces or collide, so
  // regex-matching @handle tokens out of free text after the fact would be
  // unreliable. The server uses this list as-is (after validating each id
  // is actually in the room) to notify just those people.
  final void Function(String text, List<String> mentionedUserIds) onSend;
  final String? myUserId;
  final Color primaryColor;
  final Color textColor;

  // Room roster, for the @mention suggestion list (handle + DP) shown
  // above the input while composing — see _mentionMatches/_selectMention.
  final List<RosterEntry> roster;

  final bool myMicOn;
  final bool myMicRequested;
  final VoidCallback onMicTap;
  final VoidCallback onPoll;
  final VoidCallback onGift;
  final VoidCallback onShare;
  final VoidCallback onInvite;
  // Lets the parent screen hide its own AppBar while the keyboard is up
  // composing a message (the video/audio player then slides up into that
  // freed space, chat gets the room below) — see party_screen.dart's
  // _chatFocused.
  final ValueChanged<bool>? onFocusChanged;

  const ChatOverlay({
    super.key,
    required this.messages,
    required this.onSend,
    this.myUserId,
    required this.primaryColor,
    required this.textColor,
    required this.roster,
    required this.myMicOn,
    required this.myMicRequested,
    required this.onMicTap,
    required this.onPoll,
    required this.onGift,
    required this.onShare,
    required this.onInvite,
    this.onFocusChanged,
  });

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focused = false;
  // Non-null while the text after the last '@' looks like an in-progress
  // handle (no whitespace yet) — drives the mention suggestion list. Empty
  // string matches "just typed @", not "no @ at all".
  String? _mentionQuery;
  // Accumulates as mentions get picked from the suggestion list — sent
  // alongside the message text so the server knows exactly who to notify
  // without having to parse it back out of the text (see the widget's
  // onSend doc). Not pruned if the user later deletes an @mention from the
  // text — an over-notify on an edited-out mention is a much smaller
  // problem than a missed one from imperfect text parsing, and editing
  // back out a just-inserted mention is a rare enough case not worth the
  // extra bookkeeping to track precisely.
  final Set<String> _mentionedUserIds = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateMentionQuery);
    // Collapses the attachment/gift/share/invite row and hands the parent
    // screen's AppBar space back while typing — restored once focus is
    // lost so the full control set is there the rest of the time.
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
      widget.onFocusChanged?.call(_focusNode.hasFocus);
    });
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
    final newText = '$before$insert$after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (before + insert).length),
    );
    _mentionedUserIds.add(participant.userId);
    setState(() => _mentionQuery = null);
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
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color _nameColor(String? senderId) {
    if (senderId == null) return _nameColors[0];
    return _nameColors[senderId.hashCode.abs() % _nameColors.length];
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

  @override
  Widget build(BuildContext context) {
    final visible = widget.messages
        .where((m) => m['system'] != true)
        .toList()
        .reversed
        .toList();
    final matches = _mentionMatches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: visible.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final m = visible[i];
                    final name = m['name'] as String? ?? 'Someone';
                    final senderId = m['senderId'] as String?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => openProfile(context, senderId),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: GlassPanel(
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        fontSize: 12.5, color: Colors.white),
                                    children: [
                                      TextSpan(
                                          text: '$name  ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: _nameColor(senderId))),
                                      TextSpan(
                                          text: m['text'] as String? ?? ''),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (matches.isNotEmpty)
          GlassPanel(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
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
                      src: p.avatarUrl,
                      name: p.name,
                      size: AvatarSize.sm,
                    ),
                    title: Text('@$handle',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    onTap: () => _selectMention(p),
                  );
                },
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GlassCircleButton(
                size: 38,
                onTap: widget.onMicTap,
                color: widget.myMicOn
                    ? Colors.red.withValues(alpha: 0.85)
                    : (widget.myMicRequested
                        ? widget.primaryColor.withValues(alpha: 0.6)
                        : null),
                child: Icon(widget.myMicOn ? Icons.mic : Icons.mic_off,
                    color: Colors.white, size: 17),
              ),
            ),
            Expanded(
              child: GlassPanel(
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Say something…',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                      if (!_focused) ...[
                        _inlineIcon(
                            Icons.attach_file_rounded,
                            () => showChatAttachmentSheet(context,
                                onPoll: widget.onPoll)),
                        _inlineIcon(Icons.card_giftcard_rounded, widget.onGift),
                        _inlineIcon(Icons.share_rounded, widget.onShare),
                        _inlineIcon(
                            Icons.person_add_alt_1_rounded, widget.onInvite),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GlassCircleButton(
              size: 38,
              onTap: _send,
              color: widget.primaryColor,
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 17),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inlineIcon(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: Colors.white70, size: 19),
      ),
    );
  }
}
