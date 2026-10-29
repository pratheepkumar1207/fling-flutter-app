import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/profile_nav.dart';
import '../../core/room_prefs.dart';
import '../../core/room_source_types.dart';
import '../../models/room_models.dart';
import '../../theme/insync_icons.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/insync_attach_sheet.dart';
import '../../widgets/view_once.dart';
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
  final void Function(String text, List<String> mentionedUserIds,
      {Map<String, dynamic>? replyTo}) onSend;
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
  // For the "now playing" chat card's like icon (see syncHandler.js's
  // chat:message type:'nowPlaying') — reuses the same liked-songs set/
  // toggle the video players themselves use, so liking from chat and
  // liking from the player stay in sync.
  final Set<String> likedUrls;
  final void Function(Map<String, dynamic> item)? onToggleLike;

  /// Live: the host's fan club members, shown with a heart badge.
  final Set<String> fanIds;

  /// View-once photos: share one (from the camera or the gallery), open
  /// one (once, for 10 seconds), and — for your own — see who saw it.
  final void Function({required bool camera})? onViewOncePhoto;
  final Future<void> Function(String id, String senderName)? onOpenViewOnce;
  final void Function(String id)? onViewOnceSeen;

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
    this.likedUrls = const {},
    this.onToggleLike,
    this.fanIds = const {},
    this.onViewOncePhoto,
    this.onOpenViewOnce,
    this.onViewOnceSeen,
  });

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  final _controller = TextEditingController();
  // View-once photos this person has opened (or tried to) here.
  final _openedViewOnce = <String>{};
  // The message being replied to (long-press or swipe a message).
  Map<String, dynamic>? _replyTo;

  void _startReply(Map<String, dynamic> m) {
    HapticFeedback.selectionClick();
    setState(() => _replyTo = m);
    _focusNode.requestFocus();
  }

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
    final r = _replyTo;
    widget.onSend(text, _mentionedUserIds.toList(),
        replyTo: r == null
            ? null
            : {
                'id': r['id'],
                'senderId': r['senderId'],
                'name': r['name'],
                'text': r['text'],
              });
    _controller.clear();
    _mentionedUserIds.clear();
    setState(() {
      _mentionQuery = null;
      _replyTo = null;
    });
  }

  /// Message text with @handles picked out (yours highlighted).
  List<InlineSpan> _textSpans(String text) {
    final myHandle = widget.roster
        .where((r) => r.userId == widget.myUserId)
        .map((r) => (r.username ?? r.name).toLowerCase())
        .firstOrNull;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'@([A-Za-z0-9_.]+)').allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final me = myHandle != null && m.group(1)!.toLowerCase() == myHandle;
      spans.add(TextSpan(
          text: m.group(0),
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: me ? AppColors.gold : AppColors.lilac,
              backgroundColor:
                  me ? AppColors.gold.withValues(alpha: 0.18) : null)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  bool _mentionsMe(String text) {
    final myHandle = widget.roster
        .where((r) => r.userId == widget.myUserId)
        .map((r) => (r.username ?? r.name).toLowerCase())
        .firstOrNull;
    return myHandle != null && text.toLowerCase().contains('@$myHandle');
  }

  /// One chat message: yours on the right, everyone else's on the left.
  /// Long-press or swipe it to reply.
  Widget _messageLine(Map<String, dynamic> m, String name, String? senderId) {
    final mine = senderId != null && senderId == widget.myUserId;
    final text = m['text'] as String? ?? '';
    final quote = m['replyTo'] is Map
        ? Map<String, dynamic>.from(m['replyTo'] as Map)
        : null;
    final quoteMine = quote?['senderId'] == widget.myUserId;
    final toMe = !mine && (quoteMine || _mentionsMe(text));
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 7),
      decoration: BoxDecoration(
        color: mine
            ? AppColors.primary.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: Border.all(
            color: toMe
                ? AppColors.gold.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: toMe ? 1.4 : 1),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (quote != null)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                      left: BorderSide(color: AppColors.lilac, width: 3)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(quoteMine ? 'You' : '${quote['name'] ?? 'Someone'}',
                          style: const TextStyle(
                              color: AppColors.lilac,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      Text('${quote['text'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11.5)),
                    ]),
              ),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: Colors.white),
                children: [
                  if (!mine && widget.fanIds.contains(senderId))
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: InIcon(InIcons.heart,
                            size: 12, color: AppColors.pink, filled: true),
                      ),
                    ),
                  if (!mine)
                    TextSpan(
                        text: '$name  ',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _nameColor(senderId))),
                  ..._textSpans(text),
                ],
              ),
            ),
          ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: ValueKey('msg-${m['id'] ?? m['ts']}-$senderId'),
        direction:
            mine ? DismissDirection.endToStart : DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.25,
          DismissDirection.endToStart: 0.25,
        },
        confirmDismiss: (_) async {
          _startReply(m);
          return false;
        },
        background: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: InIcon(InIcons.reply, size: 18, color: AppColors.lilac),
          ),
        ),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Semantics(
            label: '${mine ? 'You' : name}: $text. Long-press to reply',
            child: GestureDetector(
              onTap: mine ? null : () => openProfile(context, senderId),
              onLongPress: () => _startReply(m),
              child: bubble,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAttach() async {
    final kind = await showInsyncAttachSheet(context, options: [
      if (widget.onViewOncePhoto != null) ...[
        AttachKind.gallery,
        AttachKind.camera,
      ],
      AttachKind.poll,
    ]);
    switch (kind) {
      case AttachKind.gallery:
        widget.onViewOncePhoto?.call(camera: false);
      case AttachKind.camera:
        widget.onViewOncePhoto?.call(camera: true);
      case AttachKind.poll:
        widget.onPoll();
      default:
        break;
    }
  }

  /// A view-once photo in the room chat. Others tap to open it once; after
  /// that it blows away. The sender sees how many people have seen it.
  Widget _viewOnceLine(
      Map<String, dynamic> m, String id, String name, String? senderId) {
    final mine = senderId == widget.myUserId;
    final opened = _openedViewOnce.contains(id);
    final seen = (m['seenCount'] as num?)?.toInt() ?? 0;
    Widget card(
            {required Widget icon,
            required Widget body,
            VoidCallback? onTap,
            bool chevron = false}) =>
        Semantics(
          button: onTap != null,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 270),
              padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
              decoration: BoxDecoration(
                color: mine
                    ? const Color(0xFF5A2196)
                    : AppColors.primary.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lilac, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.18)
                          : const Color(0xFF2B1640)),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 9),
                Flexible(child: body),
                if (chevron) ...[
                  const SizedBox(width: 6),
                  const InIcon(InIcons.right, size: 16, color: Colors.white),
                ],
              ]),
            ),
          ),
        );
    const sub = TextStyle(color: Color(0xFFE7DDF5), fontSize: 11.5);
    final Widget line;
    if (mine) {
      line = card(
        icon: const InIcon(InIcons.eye, size: 16, color: Colors.white),
        chevron: widget.onViewOnceSeen != null,
        onTap: widget.onViewOnceSeen == null
            ? null
            : () => widget.onViewOnceSeen!(id),
        body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your photo',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Text(seen == 0 ? 'Not seen yet' : 'Seen by $seen', style: sub),
            ]),
      );
    } else {
      line = VanishOnce(
        gone: opened,
        after: ViewOnceGoneNote('$name’s photo · viewed'),
        child: card(
          icon: const InIcon(InIcons.eye, size: 16, color: AppColors.lilac),
          onTap: widget.onOpenViewOnce == null
              ? null
              : () async {
                  await widget.onOpenViewOnce!(id, name);
                  if (mounted) setState(() => _openedViewOnce.add(id));
                },
          body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      children: [
                        TextSpan(
                            text: name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _nameColor(senderId))),
                        const TextSpan(text: ' sent a photo'),
                      ]),
                ),
                const Text('Tap to open · 10 sec', style: sub),
              ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: line),
    );
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
    // Other system messages (joins, "added to queue") stay out of the
    // bubble list as before — only the rich nowPlaying card is meant to
    // appear inline here.
    final visible = widget.messages
        .where((m) => m['system'] != true || m['type'] == 'nowPlaying')
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
                    if (m['type'] == 'nowPlaying') {
                      final pinnerId = m['pinnedBy'] as String?;
                      final onRoster = pinnerId == null
                          ? null
                          : widget.roster
                              .where((r) => r.userId == pinnerId)
                              .firstOrNull;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _NowPlayingChatCard(
                            pinnerName:
                                m['pinnedByName'] as String? ?? onRoster?.name,
                            pinnerAvatar: m['pinnedByAvatar'] as String? ??
                                onRoster?.avatarUrl,
                            message: m,
                            liked: widget.likedUrls
                                .contains(m['videoUrl'] as String?),
                            onToggleLike: widget.onToggleLike == null
                                ? null
                                : () => widget.onToggleLike!(m),
                          ),
                        ),
                      );
                    }
                    final name = m['name'] as String? ?? 'Someone';
                    final senderId = m['senderId'] as String?;
                    final viewOnceId = m['viewOnceId'] as String?;
                    if (viewOnceId != null) {
                      return _viewOnceLine(m, viewOnceId, name, senderId);
                    }
                    return _messageLine(m, name, senderId);
                  },
                ),
        ),
        if (matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Tap someone to tag them',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ),
                      ),
                      Flexible(
                        child: Container(
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
                                title: Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text('@$handle',
                                    style: const TextStyle(
                                        color: AppColors.lilac, fontSize: 12)),
                                trailing: p.isHost
                                    ? const InIcon(InIcons.crown,
                                        size: 14,
                                        color: AppColors.gold,
                                        filled: true)
                                    : null,
                                onTap: () => _selectMention(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        if (_replyTo != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                  left: BorderSide(color: AppColors.lilac, width: 3)),
            ),
            child: Row(children: [
              const InIcon(InIcons.reply, size: 16, color: AppColors.lilac),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          _replyTo!['senderId'] == widget.myUserId
                              ? 'Replying to yourself'
                              : 'Replying to ${_replyTo!['name'] ?? 'Someone'}',
                          style: const TextStyle(
                              color: AppColors.lilac,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                      Text('${_replyTo!['text'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              IconButton(
                tooltip: 'Cancel reply',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _replyTo = null),
                icon: const InIcon(InIcons.close,
                    size: 16, color: Colors.white70),
              ),
            ]),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [RoomPrefs.instance, RoomPrefs.instance.talking]),
                builder: (context, _) {
                  final prefs = RoomPrefs.instance;
                  final ptt = prefs.pushToTalk && widget.myMicOn;
                  final talking = ptt && prefs.talking.value;
                  final button = GlassCircleButton(
                    size: 42,
                    onTap: ptt
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Push to talk is on — hold the mic to speak.')))
                        : widget.onMicTap,
                    color: talking
                        ? AppColors.pink
                        : ptt
                            ? AppColors.primary.withValues(alpha: 0.55)
                            : widget.myMicOn
                                ? AppColors.primary
                                : (widget.myMicRequested
                                    ? widget.primaryColor.withValues(alpha: 0.6)
                                    : null),
                    child: InIcon(
                        widget.myMicOn && (!ptt || talking)
                            ? InIcons.mic
                            : InIcons.micoff,
                        color: Colors.white,
                        size: 20),
                  );
                  if (!ptt) return button;
                  return Semantics(
                    label: 'Hold to talk',
                    child: Listener(
                      onPointerDown: (_) => prefs.talking.value = true,
                      onPointerUp: (_) => prefs.talking.value = false,
                      onPointerCancel: (_) => prefs.talking.value = false,
                      child: button,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: GlassPanel(
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          // Otherwise picks up the app's default theme
                          // accent for the cursor/selection handles — a
                          // stray splash of color against this glass bar's
                          // neutral look while typing.
                          cursorColor: Colors.white,
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
                        if (widget.onViewOncePhoto != null)
                          _inlineIcon(InIcons.camera, 'Send a view once photo',
                              () => widget.onViewOncePhoto!(camera: true)),
                        _inlineIcon(InIcons.clip, 'Attach', _openAttach),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // While typing: just Send. Otherwise gift, invite and share sit
            // beside the field, as in the design.
            if (_focused)
              GlassCircleButton(
                size: 42,
                onTap: _send,
                color: widget.primaryColor,
                child:
                    const InIcon(InIcons.send, color: Colors.white, size: 19),
              )
            else ...[
              Semantics(
                button: true,
                label: 'Send a gift',
                child: GlassCircleButton(
                  size: 42,
                  onTap: widget.onGift,
                  color: const Color(0xFF2A2310),
                  child: const InIcon(InIcons.gift,
                      color: AppColors.gold, size: 20),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: 'Invite',
                child: GlassCircleButton(
                  size: 42,
                  onTap: widget.onInvite,
                  child: const InIcon(InIcons.useradd,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: 'Share room',
                child: GlassCircleButton(
                  size: 42,
                  onTap: widget.onShare,
                  child: const InIcon(InIcons.share,
                      color: Colors.white, size: 19),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _inlineIcon(InIconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: InIcon(icon, color: Colors.white70, size: 19),
        ),
      ),
    );
  }
}

// The "now playing" entry in chat itself — see syncHandler.js's
// chat:message type:'nowPlaying'. Same GlassPanel bubble treatment as a
// normal message, just with a thumbnail and a tappable like icon instead
// of plain text.
class _NowPlayingChatCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool liked;
  final VoidCallback? onToggleLike;
  // Who pinned/added this item — name + avatar are snapshotted by the server
  // when it starts playing (see syncHandler.js), with the live roster as a
  // fallback. Both null for older messages, which keep the thumbnail.
  final String? pinnerName;
  final String? pinnerAvatar;

  const _NowPlayingChatCard(
      {required this.message,
      required this.liked,
      this.onToggleLike,
      this.pinnerName,
      this.pinnerAvatar});

  static (InIconData, Color) _sourceIcon(String? sourceType) {
    if (sourceType == 'youtube') {
      return (InIcons.tv, const Color(0xFFFF3B30));
    }
    if (sourceType == 'drive') {
      return (InIcons.cloud, const Color(0xFF4285F4));
    }
    if (sourceType != null && webviewSourceTypes.contains(sourceType)) {
      return (InIcons.tv, Colors.white70);
    }
    return (InIcons.play, Colors.white70);
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = message['thumbnail'] as String?;
    final hasPinner = pinnerName != null || pinnerAvatar != null;
    final (sourceIcon, sourceColor) =
        _sourceIcon(message['sourceType'] as String?);
    // Full chat width (no max-width cap, unlike normal bubbles) so the
    // title can use the whole screen length before it ellipsizes.
    return GlassPanel(
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            if (hasPinner)
              Avatar(src: pinnerAvatar, name: pinnerName, size: AvatarSize.sm)
            else if (thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(thumbnail,
                    width: 32, height: 32, fit: BoxFit.cover),
              ),
            if (hasPinner || thumbnail != null) const SizedBox(width: 8),
            InIcon(sourceIcon, size: 16, color: sourceColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message['title'] as String? ?? 'Untitled',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            if (onToggleLike != null)
              GestureDetector(
                onTap: onToggleLike,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(liked ? '❤️' : '🤍',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
