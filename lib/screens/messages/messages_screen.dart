import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../widgets/notes.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/read_ticks.dart';
import '../../widgets/spinner.dart';
import '../blend/blend_entry.dart';
import '../discover/discover_matches_screen.dart';
import '../friends/friends_screen.dart';
import '../party/party_screen.dart';
import '../discover/liked_me_screen.dart';
import 'group_thread_screen.dart';
import 'message_requests_screen.dart';
import 'message_thread_screen.dart';

/// Messages, opened from the top bar: search; one strip with your note,
/// Likes and new matches; Blends; All / Unread / Groups / Requests; then
/// "Your turn" (people waiting on a reply) above everything else, chats and
/// groups together, pinned first. Rows show typing, seen ticks, mute and
/// pin, and a live chip with Join when a friend is in a public room.
/// Long-press a chat for pin, mute, mark unread, block or delete.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen(
      {super.key,
      this.initialConversations,
      this.initialGroups,
      this.initialMatches,
      this.initialLikes});

  /// Shown instead of loading from the server (widget tests).
  @visibleForTesting
  final List<ConversationSummary>? initialConversations;
  @visibleForTesting
  final List<Map<String, dynamic>>? initialGroups;
  @visibleForTesting
  final List<Map<String, dynamic>>? initialMatches;
  @visibleForTesting
  final int? initialLikes;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<ConversationSummary> _conversations = [];
  List<Map<String, dynamic>> _matches = [];
  String _query = '';
  // 'all' | 'unread' | 'groups'
  String _filter = 'all';
  List<Map<String, dynamic>> _groups = [];
  int _likes = 0;

  // userId → when their "typing…" stops showing.
  final Map<String, DateTime> _typing = {};
  Timer? _typingTick;
  io.Socket? _socket;

  /// How many "your turn" chats get a card before the rest of the list.
  static const _yourTurnMax = 3;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialConversations;
    if (initial != null) {
      _conversations = initial;
      _groups = widget.initialGroups ?? [];
      _matches = widget.initialMatches ?? [];
      _likes = widget.initialLikes ?? 0;
      _loading = false;
      return;
    }
    _load();
    _loadMatches();
    _loadGroups();
    _loadLikes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No live connection (e.g. not signed in yet): just skip typing.
      try {
        _socket = context.read<SocketService>().socket;
      } on ProviderNotFoundException {
        return;
      }
      _socket?.on('dm:typing', _onTyping);
      _socket?.on('dm:message', _onMessage);
    });
  }

  @override
  void dispose() {
    _socket?.off('dm:typing', _onTyping);
    _socket?.off('dm:message', _onMessage);
    _typingTick?.cancel();
    super.dispose();
  }

  void _onTyping(dynamic data) {
    if (!mounted || data is! Map) return;
    final from = '${data['fromUserId']}';
    setState(
        () => _typing[from] = DateTime.now().add(const Duration(seconds: 5)));
    _typingTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final before = _typing.length;
      _typing.removeWhere((_, until) => until.isBefore(now));
      if (_typing.length != before) setState(() {});
      if (_typing.isEmpty) {
        _typingTick?.cancel();
        _typingTick = null;
      }
    });
  }

  void _onMessage(dynamic data) {
    if (!mounted || data is! Map) return;
    _typing.remove('${data['senderId']}');
    _load();
  }

  bool _isTyping(String userId) =>
      _typing[userId]?.isAfter(DateTime.now()) ?? false;

  /// They sent the last message and you haven't read it yet.
  static bool _isYourTurn(ConversationSummary c) =>
      !c.isRequest && !c.lastMessageIsMine && c.unreadCount > 0;

  static int _groupUnread(Map<String, dynamic> g) =>
      (g['unreadCount'] as num?)?.toInt() ?? 0;

  static DateTime _groupAt(Map<String, dynamic> g) =>
      DateTime.tryParse('${g['lastMessageAt'] ?? g['createdAt'] ?? ''}') ??
      DateTime(2000);

  int get _unreadChats =>
      _conversations.where((c) => !c.isRequest && c.isUnread).length +
      _groups.where((g) => _groupUnread(g) > 0).length;

  int get _requestCount => _conversations.where((c) => c.isRequest).length;

  /// Chats and groups together: pinned first, then newest.
  List<_InboxEntry> get _entries {
    final q = _query.trim().toLowerCase();
    bool match(String name) => q.isEmpty || name.toLowerCase().contains(q);
    final out = <_InboxEntry>[
      if (_filter != 'groups')
        for (final c in _conversations)
          if (!c.isRequest &&
              (_filter != 'unread' || c.isUnread) &&
              match(c.name))
            _InboxEntry.chat(c),
      for (final g in _groups)
        if ((_filter != 'unread' || _groupUnread(g) > 0) &&
            match(g['name'] as String? ?? ''))
          _InboxEntry.group(g, _groupAt(g)),
    ];
    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.at.compareTo(a.at);
    });
    return out;
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/messages/conversations');
      if (!mounted) return;
      setState(() {
        _conversations = (data as List)
            .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final data = await ApiClient.get('/groups');
      if (!mounted) return;
      setState(() => _groups = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // Groups are optional.
    }
  }

  Future<void> _loadLikes() async {
    try {
      final data = await ApiClient.get('/swipe/likes-count') as Map;
      if (!mounted) return;
      setState(() => _likes = (data['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  Future<void> _newGroup() async {
    final id = await createGroupChat(context);
    if (id == null || !mounted) return;
    await _loadGroups();
    final g = _groups.firstWhere((x) => x['id'] == id,
        orElse: () => {'id': id, 'name': 'Group'});
    _openGroup(g);
  }

  void _openGroup(Map<String, dynamic> g) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => GroupThreadScreen(
                groupId: g['id'] as String, name: g['name'] as String? ?? '')))
        .then((_) => _loadGroups());
  }

  Future<void> _loadMatches() async {
    try {
      final data = await ApiClient.get('/swipe/matches');
      if (!mounted) return;
      setState(() => _matches = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // Optional row.
    }
  }

  void _openChat(String userId, String name, String? avatarUrl) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => MessageThreadScreen(
                userId: userId, name: name, avatarUrl: avatarUrl)))
        .then((_) => _load());
  }

  void _joinRoom(String roomId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)))
        .then((_) => _load());
  }

  void _setFilter(String f) => setState(() => _filter = f);

  void _openRequests() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const MessageRequestsScreen()))
      .then((_) => _load());

  /// Likes circle → who liked you (VIP sees everyone).
  void _openLikes() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LikedMeScreen()))
      .then((_) => _loadLikes());

  void _replace(ConversationSummary c) => setState(() => _conversations = [
        for (final x in _conversations) x.userId == c.userId ? c : x
      ]);

  Future<void> _patchChat(ConversationSummary before, ConversationSummary after,
      Map<String, dynamic> body) async {
    _replace(after);
    try {
      await ApiClient.patch('/messages/chats/${before.userId}', body: body);
    } on ApiException catch (e) {
      if (!mounted) return;
      _replace(before);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteChat(ConversationSummary c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete chat with ${c.name}?'),
        content: const Text(
            'It’s removed from your inbox only. It comes back if either of you sends a new message.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.pink))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final before = _conversations;
    setState(() => _conversations = [
          for (final x in before)
            if (x != c) x
        ]);
    try {
      await ApiClient.delete('/messages/chats/${c.userId}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _conversations = before);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _block(ConversationSummary c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Block ${c.name}?'),
        content: const Text(
            'They won’t be able to message you or see you in Discover.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child:
                  const Text('Block', style: TextStyle(color: AppColors.pink))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.post('/social/block/${c.userId}');
      if (!mounted) return;
      setState(() => _conversations = [
            for (final x in _conversations)
              if (x.userId != c.userId) x
          ]);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${c.name} is blocked')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Long-press a chat: pin, mute, mark unread, block, delete for me.
  void _openChatOptions(ConversationSummary c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => _ChatOptionsSheet(
        c: c,
        onPin: () {
          Navigator.of(sheet).pop();
          _patchChat(c, c.copyWith(pinned: !c.pinned), {'pinned': !c.pinned});
        },
        onMute: (length) {
          Navigator.of(sheet).pop();
          final until = switch (length) {
            '8h' => DateTime.now().add(const Duration(hours: 8)),
            '1w' => DateTime.now().add(const Duration(days: 7)),
            'always' => DateTime.now().add(const Duration(days: 36500)),
            _ => null,
          };
          _patchChat(
              c,
              until == null
                  ? c.copyWith(clearMute: true)
                  : c.copyWith(mutedUntil: until),
              {'mute': length});
        },
        onMarkUnread: () {
          Navigator.of(sheet).pop();
          _patchChat(c, c.copyWith(markedUnread: true), {'markedUnread': true});
        },
        onBlock: () {
          Navigator.of(sheet).pop();
          _block(c);
        },
        onDelete: () {
          Navigator.of(sheet).pop();
          _deleteChat(c);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    // Split "your turn" out only on the plain All view.
    final splitTurns = _filter == 'all' && _query.trim().isEmpty;
    final yourTurn = splitTurns
        ? [
            for (final e in entries)
              if (e.chat != null && _isYourTurn(e.chat!)) e
          ].take(_yourTurnMax).toList()
        : const <_InboxEntry>[];
    final rest = yourTurn.isEmpty
        ? entries
        : entries.where((e) => !yourTurn.contains(e)).toList();
    final talkedTo = {for (final c in _conversations) c.userId};

    Widget row(_InboxEntry e) => e.chat != null
        ? _ConversationRow(
            c: e.chat!,
            typing: _isTyping(e.chat!.userId),
            onTap: () =>
                _openChat(e.chat!.userId, e.chat!.name, e.chat!.avatarUrl),
            onLongPress: () => _openChatOptions(e.chat!),
            onJoin: _joinRoom,
          )
        : _GroupRow(g: e.group!, onTap: () => _openGroup(e.group!));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait(
              [_load(), _loadMatches(), _loadGroups(), _loadLikes()]),
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
                    child: Text('Messages',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ),
                  _CircleButton(
                      icon: InIcons.community,
                      tooltip: 'New group',
                      onTap: _newGroup),
                  const SizedBox(width: 8),
                  _CircleButton(
                      icon: InIcons.edit,
                      tooltip: 'New message',
                      filled: true,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FriendsScreen()))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search people and messages',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.border)),
                    prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: InIcon(InIcons.search,
                            size: 18, color: AppColors.textDim)),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
              ),
            ),
            // One strip: your note, Likes, new matches, then friends' notes.
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'New matches',
                top: 12,
                action: _matches.isEmpty ? null : 'See all',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const DiscoverMatchesScreen())),
              ),
            ),
            SliverToBoxAdapter(
              child: Builder(builder: (context) {
                final me = context.watch<AuthProvider>().user;
                return NotesRow(
                  myUserId: me?.id,
                  myName: me?.name,
                  myAvatar: me?.avatarUrl,
                  after: [
                    if (_likes > 0)
                      _LikesTile(count: _likes, onTap: _openLikes),
                    for (final m in _matches)
                      _MatchTile(
                        m: m,
                        fresh: !talkedTo.contains(m['userId']),
                        onTap: () => _openChat(
                            m['userId'] as String,
                            m['name'] as String? ?? '',
                            m['avatarUrl'] as String?),
                      ),
                  ],
                );
              }),
            ),
            // Reels Blends: New Blend, then yours.
            const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Blends', top: 10)),
            const SliverToBoxAdapter(child: BlendsRow()),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(children: [
                  _FilterPill(
                      label: 'All',
                      selected: _filter == 'all',
                      onTap: () => _setFilter('all')),
                  _FilterPill(
                      label: 'Unread',
                      count: _unreadChats,
                      selected: _filter == 'unread',
                      onTap: () => _setFilter('unread')),
                  _FilterPill(
                      label: 'Groups',
                      selected: _filter == 'groups',
                      onTap: () => _setFilter('groups')),
                  _FilterPill(
                      label: 'Requests',
                      count: _requestCount,
                      alert: true,
                      selected: false,
                      onTap: _openRequests),
                ]),
              ),
            ),
            if (_filter == 'all' && _requestCount > 0)
              SliverToBoxAdapter(
                child:
                    _RequestsBanner(count: _requestCount, onTap: _openRequests),
              ),
            if (_loading)
              const SliverFillRemaining(
                  hasScrollBody: false, child: Center(child: Spinner(size: 28)))
            else if (_filter == 'groups' && entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('No groups yet.',
                        style: TextStyle(color: AppColors.textFaint)),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _newGroup,
                      icon: const InIcon(InIcons.plus,
                          size: 18, color: Colors.white),
                      label: const Text('New group'),
                    ),
                  ]),
                ),
              )
            else if (_conversations.isEmpty && _groups.isEmpty)
              const SliverFillRemaining(
                  hasScrollBody: false, child: _EmptyChats())
            else if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text(
                        _filter == 'unread'
                            ? 'You’re all caught up.'
                            : 'No chats here.',
                        style: const TextStyle(color: AppColors.textFaint))),
              )
            else ...[
              if (yourTurn.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Your turn',
                    count: yourTurn.length,
                    trailing: 'They’re waiting on you',
                    top: 12,
                  ),
                ),
                SliverList.builder(
                  itemCount: yourTurn.length,
                  itemBuilder: (context, i) {
                    final c = yourTurn[i].chat!;
                    return _YourTurnCard(
                      c: c,
                      typing: _isTyping(c.userId),
                      onOpen: () => _openChat(c.userId, c.name, c.avatarUrl),
                      onLongPress: () => _openChatOptions(c),
                      onJoin: _joinRoom,
                    );
                  },
                ),
                if (rest.isNotEmpty)
                  const SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Recent', top: 14)),
              ],
              SliverList.builder(
                itemCount: rest.length,
                itemBuilder: (context, i) => row(rest[i]),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
      ),
    );
  }
}

/// A row in the inbox: a 1:1 chat or a group.
class _InboxEntry {
  final ConversationSummary? chat;
  final Map<String, dynamic>? group;
  final DateTime at;
  final bool pinned;

  _InboxEntry.chat(ConversationSummary c)
      : chat = c,
        group = null,
        at = c.lastMessageAt,
        pinned = c.pinned;

  _InboxEntry.group(Map<String, dynamic> g, this.at)
      : chat = null,
        group = g,
        pinned = false;
}

/// Same shape as a notes tile (bubble space on top) so the strip lines up.
class _StripTile extends StatelessWidget {
  final Widget face;
  final String label;
  final Color labelColor;
  final String semantics;
  final VoidCallback onTap;
  const _StripTile(
      {required this.face,
      required this.label,
      required this.semantics,
      required this.onTap,
      this.labelColor = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(children: [
            const SizedBox(height: 36),
            face,
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _LikesTile extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _LikesTile({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _StripTile(
      semantics: '$count people like you',
      label: 'Likes',
      labelColor: AppColors.gold,
      onTap: onTap,
      face: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A2208),
            border: Border.all(color: AppColors.gold, width: 2)),
        alignment: Alignment.center,
        child: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool fresh;
  final VoidCallback onTap;
  const _MatchTile({required this.m, required this.fresh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = m['name'] as String? ?? '';
    return _StripTile(
      semantics: fresh ? 'New match $name' : 'Message $name',
      label: name.split(' ').first,
      onTap: onTap,
      face: Stack(clipBehavior: Clip.none, children: [
        Avatar(
            src: m['avatarUrl'] as String?,
            name: name,
            size: AvatarSize.md,
            ring: true),
        if (fresh)
          Positioned(
            right: -6,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.pink,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bg, width: 2)),
              child: const Text('NEW',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
            ),
          ),
      ]),
    );
  }
}

class _ChatOptionsSheet extends StatelessWidget {
  final ConversationSummary c;
  final VoidCallback onPin;
  final void Function(String? length) onMute;
  final VoidCallback onMarkUnread;
  final VoidCallback onBlock;
  final VoidCallback onDelete;
  const _ChatOptionsSheet(
      {required this.c,
      required this.onPin,
      required this.onMute,
      required this.onMarkUnread,
      required this.onBlock,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget item(InIconData icon, String label,
            {String? sub, Color? color, required VoidCallback onTap}) =>
        InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                InIcon(icon, size: 20, color: color ?? AppColors.lilac),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: color ?? AppColors.text)),
                        if (sub != null)
                          Text(sub,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textDim)),
                      ]),
                ),
              ]),
            ),
          ),
        );
    Widget muteChip(String label, String? value, bool selected) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: selected,
              button: true,
              child: Material(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: StadiumBorder(
                    side: selected
                        ? BorderSide.none
                        : const BorderSide(color: Color(0xFF3B3550))),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onMute(value),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFD9D6E2))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The theme's sheet already draws the drag handle.
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(children: [
                Avatar(src: c.avatarUrl, name: c.name, size: AvatarSize.sm),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                            'Last message ${formatRelativeTime(c.lastMessageAt)}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textDim)),
                      ]),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            item(InIcons.pin, c.pinned ? 'Unpin chat' : 'Pin chat',
                sub: 'Pinned chats stay on top', onTap: onPin),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      InIcon(InIcons.mute, size: 20, color: AppColors.lilac),
                      SizedBox(width: 14),
                      Expanded(
                          child: Text('Mute notifications',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 34),
                      child: Row(children: [
                        muteChip('8 hours', '8h', false),
                        muteChip('1 week', '1w', false),
                        muteChip('Always', 'always', false),
                      ]),
                    ),
                    if (c.muted)
                      Padding(
                        padding: const EdgeInsets.only(left: 34, top: 8),
                        child: TextButton(
                          onPressed: () => onMute(null),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(44, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4)),
                          child: const Text('Unmute'),
                        ),
                      ),
                  ]),
            ),
            if (!c.isUnread)
              item(InIcons.chat, 'Mark as unread', onTap: onMarkUnread),
            item(InIcons.block, 'Block ${c.name.split(' ').first}',
                onTap: onBlock),
            const Divider(height: 1, color: AppColors.border),
            item(InIcons.close, 'Delete chat',
                sub: 'Removes it from your inbox only',
                color: const Color(0xFFFF8A9F),
                onTap: onDelete),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final InIconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;
  const _CircleButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.primary : AppColors.surface,
        shape: CircleBorder(
            side: filled
                ? BorderSide.none
                : const BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
                child: InIcon(icon,
                    size: 20, color: filled ? Colors.white : AppColors.text)),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;
  final double top;
  const _SectionHeader(
      {required this.title,
      this.count,
      this.trailing,
      this.action,
      this.onAction,
      this.top = 8});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 8),
      child: Row(children: [
        // Title (and count) on the left, shrinking with an ellipsis before
        // the action link on the right does.
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              CountBadge(count!),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(trailing!,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 12)),
              ),
            ],
          ]),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.lilac,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool alert;
  final VoidCallback onTap;
  const _FilterPill(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.count = 0,
      this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.text : AppColors.surface,
          shape: StadiumBorder(
              side: selected
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            selected ? AppColors.bg : const Color(0xFFD9D6E2))),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: alert && !selected
                            ? AppColors.pink
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _RequestsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: Color(0xFF2B1640), shape: BoxShape.circle),
                child: const Center(
                    child:
                        InIcon(InIcons.chat, size: 20, color: AppColors.lilac)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          count == 1
                              ? '1 message request'
                              : '$count message requests',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text('From people you haven’t matched with',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textDim)),
                    ]),
              ),
              const InIcon(InIcons.right, size: 18, color: AppColors.textDim),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Avatar with the green online dot.
class _ChatAvatar extends StatelessWidget {
  final ConversationSummary c;
  const _ChatAvatar(this.c);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openProfile(context, c.userId),
      child: Stack(children: [
        Avatar(src: c.avatarUrl, name: c.name, size: AvatarSize.md),
        if (c.online)
          Positioned(
            bottom: 0,
            right: 0,
            child: Semantics(
              label: 'Online',
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2.5)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Last-message line: seen tick on mine, an icon for photos and voice
/// notes, bold while unread.
class _Preview extends StatelessWidget {
  final ConversationSummary c;
  final bool typing;
  const _Preview(this.c, {this.typing = false});

  @override
  Widget build(BuildContext context) {
    if (typing) {
      return const Text('typing…',
          maxLines: 1,
          style: TextStyle(
              color: AppColors.lilac,
              fontWeight: FontWeight.w600,
              fontSize: 13.5));
    }
    final unread = c.unreadCount > 0;
    final color = unread ? AppColors.text : AppColors.textDim;
    final mediaIcon = switch (c.lastMessageType) {
      'image' => InIcons.image,
      'voice' => InIcons.mic,
      'gif' => InIcons.gif,
      'sticker' => InIcons.sticker,
      _ => null,
    };
    return Row(children: [
      if (c.lastMessageIsMine) ...[
        ReadTicks(
            seen: c.lastMessageSeen,
            color: c.lastMessageSeen ? AppColors.lilac : AppColors.textFaint),
        const SizedBox(width: 4),
      ],
      if (mediaIcon != null) ...[
        InIcon(mediaIcon, size: 15, color: color),
        const SizedBox(width: 4),
      ],
      Expanded(
        child: Text('${c.lastMessageIsMine ? 'You: ' : ''}${c.lastMessage}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color,
                fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13.5)),
      ),
    ]);
  }
}

/// "In Movie night · Join" — what they're doing right now.
class _ActivityChip extends StatelessWidget {
  final ConversationActivity a;
  final void Function(String roomId) onJoin;
  const _ActivityChip(this.a, {required this.onJoin});

  static String _gameName(String? g) => switch (g) {
        'tictactoe' => 'Tic-tac-toe',
        'ludo' => 'Ludo',
        'truth_or_dare' => 'Truth or dare',
        'chess' => 'Chess',
        'uno' => 'Uno',
        _ => 'a game',
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (a.roomType) {
      'watch' => (
          InIcons.play,
          AppColors.lilac,
          'Watching ${a.nowPlayingTitle ?? a.title}'
        ),
      'game' => (
          InIcons.game,
          AppColors.diamond,
          'Playing ${_gameName(a.gameType)}'
        ),
      'live' => (
          InIcons.live,
          const Color(0xFFFF8A9F),
          'Live now · ${a.title}'
        ),
      _ => (InIcons.mic, AppColors.lilac, 'In ${a.title}'),
    };
    final label = a.canJoin ? '$text · Join' : text;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1326),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF3B2A55))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InIcon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2CCFF))),
        ),
        // Join stays visible however long the room name is.
        if (a.canJoin)
          const Text(' · Join',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
      ]),
    );
    if (!a.canJoin) return chip;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(onTap: () => onJoin(a.roomId), child: chip),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ConversationSummary c;
  final bool typing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String roomId) onJoin;
  const _ConversationRow(
      {required this.c,
      required this.onTap,
      required this.onLongPress,
      required this.onJoin,
      this.typing = false});

  @override
  Widget build(BuildContext context) {
    final unread = c.isUnread;
    final loud = unread && !c.muted;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ChatAvatar(c),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15)),
                ),
                _ChatFlags(c),
                const Spacer(),
                const SizedBox(width: 8),
                Text(formatRelativeTime(c.lastMessageAt),
                    style: TextStyle(
                        color: loud ? AppColors.lilac : AppColors.textDim,
                        fontWeight: loud ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _Preview(c, typing: typing)),
                if (unread) ...[
                  const SizedBox(width: 8),
                  _UnreadBadge(c.unreadCount, muted: c.muted),
                ],
              ]),
              if (c.activity != null) ...[
                const SizedBox(height: 7),
                _ActivityChip(c.activity!, onJoin: onJoin),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Someone waiting on your reply: a card with its own Reply button.
class _YourTurnCard extends StatelessWidget {
  final ConversationSummary c;
  final bool typing;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final void Function(String roomId) onJoin;
  const _YourTurnCard(
      {required this.c,
      required this.onOpen,
      required this.onLongPress,
      required this.onJoin,
      this.typing = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _ChatAvatar(c),
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
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                          _ChatFlags(c),
                          const SizedBox(width: 6),
                          Text(formatRelativeTime(c.lastMessageAt),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lilac,
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 3),
                        _Preview(c, typing: typing),
                      ]),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  child: const Text('Reply'),
                ),
              ]),
              // Under the whole row so it has room next to Reply.
              if (c.activity != null)
                Padding(
                  padding: const EdgeInsets.only(left: 60, top: 8),
                  child: _ActivityChip(c.activity!, onJoin: onJoin),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pin and mute icons after a chat's name.
class _ChatFlags extends StatelessWidget {
  final ConversationSummary c;
  const _ChatFlags(this.c);

  @override
  Widget build(BuildContext context) {
    if (!c.pinned && !c.muted) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (c.pinned) ...[
        const SizedBox(width: 6),
        Semantics(
            label: 'Pinned',
            child:
                const InIcon(InIcons.pin, size: 13, color: AppColors.textDim)),
      ],
      if (c.muted) ...[
        const SizedBox(width: 6),
        Semantics(
            label: 'Muted',
            child:
                const InIcon(InIcons.mute, size: 13, color: AppColors.textDim)),
      ],
    ]);
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  final bool muted;
  const _UnreadBadge(this.count, {this.muted = false});

  @override
  Widget build(BuildContext context) {
    // Marked unread by hand with nothing new: a dot instead of a number.
    if (count == 0) {
      return Semantics(
        label: 'Marked unread',
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: muted ? const Color(0xFF4A4658) : AppColors.primary,
              shape: BoxShape.circle),
        ),
      );
    }
    return Semantics(
      label: '$count unread',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 22),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: muted ? const Color(0xFF4A4658) : AppColors.primary,
            borderRadius: BorderRadius.circular(999)),
        child: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1)),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFF1C1638),
              borderRadius: BorderRadius.circular(21)),
          child: const Center(
              child: InIcon(InIcons.chat, size: 30, color: AppColors.lilac)),
        ),
        const SizedBox(height: 12),
        const Text('No messages yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Match with someone or message a friend to start chatting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
      ]),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final Map<String, dynamic> g;
  final VoidCallback onTap;
  const _GroupRow({required this.g, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = (g['unreadCount'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse('${g['lastMessageAt'] ?? ''}');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          // Groups: rounded square so they stand apart from people.
          Semantics(
            label: 'Group',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: avatarColorFor(g['name'] as String?),
                  borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(initials(g['name'] as String?),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['name'] as String? ?? 'Group',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight:
                          unread > 0 ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                  (g['lastMessage'] as String?)?.isNotEmpty == true
                      ? g['lastMessage'] as String
                      : '${g['memberCount'] ?? ''} people',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: unread > 0 ? AppColors.text : AppColors.textDim,
                      fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (at != null)
              Text(formatRelativeTime(at),
                  style: TextStyle(
                      color: unread > 0 ? AppColors.lilac : AppColors.textDim,
                      fontSize: 12)),
            const SizedBox(height: 6),
            if (unread > 0)
              _UnreadBadge(unread)
            else
              const SizedBox(height: 16),
          ]),
        ]),
      ),
    );
  }
}
