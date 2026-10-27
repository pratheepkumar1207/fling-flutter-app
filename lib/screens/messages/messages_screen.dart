import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../widgets/notes.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../models/message.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/spinner.dart';
import '../blend/blend_entry.dart';
import '../discover/discover_matches_screen.dart';
import '../friends/friends_screen.dart';
import '../party/party_screen.dart';
import 'group_thread_screen.dart';
import 'message_requests_screen.dart';
import 'message_thread_screen.dart';

/// Messages, opened from the top bar: search, notes, new matches, blends,
/// All / Unread / Groups / Requests, then "Your turn" (people waiting on a
/// reply) above the rest. Rows show what a friend is doing right now
/// (a live chip with Join) when their privacy settings allow it.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.initialConversations});

  /// Shown instead of loading from the server (widget tests).
  @visibleForTesting
  final List<ConversationSummary>? initialConversations;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<ConversationSummary> _conversations = [];
  List<Map<String, dynamic>> _matches = [];
  String _query = '';
  // 'all' | 'unread' | 'requests' | 'groups'
  String _filter = 'all';
  List<Map<String, dynamic>> _groups = [];

  /// How many "your turn" chats get a card before the rest of the list.
  static const _yourTurnMax = 3;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialConversations;
    if (initial != null) {
      _conversations = initial;
      _loading = false;
    } else {
      _load();
    }
    _loadMatches();
    _loadGroups();
  }

  List<ConversationSummary> get _filtered {
    final q = _query.trim().toLowerCase();
    return _conversations
        .where((c) =>
            (_filter != 'unread' || c.unreadCount > 0) &&
            (_filter == 'requests' ? c.isRequest : !c.isRequest) &&
            (q.isEmpty || c.name.toLowerCase().contains(q)))
        .toList();
  }

  /// They sent the last message and you haven't read it yet.
  static bool _isYourTurn(ConversationSummary c) =>
      !c.isRequest && !c.lastMessageIsMine && c.unreadCount > 0;

  int get _unreadChats =>
      _conversations.where((c) => !c.isRequest && c.unreadCount > 0).length;

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
      // Groups row is optional.
    }
  }

  int get _requestCount => _conversations.where((c) => c.isRequest).length;

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

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    // Split "your turn" out only on the plain All view.
    final splitTurns = _filter == 'all' && _query.trim().isEmpty;
    final yourTurn = splitTurns
        ? results.where(_isYourTurn).take(_yourTurnMax).toList()
        : const <ConversationSummary>[];
    final rest = yourTurn.isEmpty
        ? results
        : results.where((c) => !yourTurn.contains(c)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([_load(), _loadMatches()]),
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
            // Notes: your own first (tap to write one), then people you follow.
            SliverToBoxAdapter(
              child: Builder(builder: (context) {
                final me = context.watch<AuthProvider>().user;
                return NotesRow(
                    myUserId: me?.id,
                    myName: me?.name,
                    myAvatar: me?.avatarUrl);
              }),
            ),
            if (_matches.isNotEmpty) SliverToBoxAdapter(child: _matchesRow()),
            // Reels Blends: New Blend, then yours.
            const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Blends', top: 10)),
            const SliverToBoxAdapter(child: BlendsRow()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
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
                      onTap: () => _openRequests()),
                ]),
              ),
            ),
            if (_filter == 'all' && _requestCount > 0)
              SliverToBoxAdapter(
                child: _RequestsBanner(
                    count: _requestCount, onTap: () => _openRequests()),
              ),
            if (_filter == 'groups')
              _groups.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
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
                  : SliverList.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, i) => _GroupRow(
                          g: _groups[i], onTap: () => _openGroup(_groups[i])),
                    )
            else if (_loading)
              const SliverFillRemaining(
                  hasScrollBody: false, child: Center(child: Spinner(size: 28)))
            else if (_conversations.isEmpty)
              const SliverFillRemaining(
                  hasScrollBody: false, child: _EmptyChats())
            else if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text(
                        _filter == 'requests'
                            ? 'No message requests.'
                            : _filter == 'unread'
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
                  itemBuilder: (context, i) => _YourTurnCard(
                    c: yourTurn[i],
                    onOpen: () => _openChat(yourTurn[i].userId,
                        yourTurn[i].name, yourTurn[i].avatarUrl),
                    onJoin: _joinRoom,
                  ),
                ),
                if (rest.isNotEmpty)
                  const SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Recent', top: 14)),
              ],
              SliverList.builder(
                itemCount: rest.length,
                itemBuilder: (context, i) => _ConversationRow(
                  c: rest[i],
                  onTap: () => _openChat(
                      rest[i].userId, rest[i].name, rest[i].avatarUrl),
                  onJoin: _joinRoom,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
      ),
    );
  }

  Widget _matchesRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(
        title: 'New matches',
        top: 12,
        action: 'See all',
        onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DiscoverMatchesScreen())),
      ),
      SizedBox(
        height: 64 + MediaQuery.textScalerOf(context).scale(12) * 1.5,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _matches.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final m = _matches[i];
            final name = m['name'] as String? ?? '';
            return Semantics(
              button: true,
              label: 'Message $name',
              child: GestureDetector(
                onTap: () => _openChat(
                    m['userId'] as String, name, m['avatarUrl'] as String?),
                child: SizedBox(
                  width: 62,
                  child: Column(children: [
                    Avatar(
                        src: m['avatarUrl'] as String?,
                        name: name,
                        size: AvatarSize.md,
                        ring: true),
                    const SizedBox(height: 5),
                    Text(name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
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
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        if (count != null) ...[
          const SizedBox(width: 8),
          CountBadge(count!),
        ],
        const SizedBox(width: 8),
        if (trailing != null)
          Expanded(
            child: Text(trailing!,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          )
        else
          const Spacer(),
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
    return Semantics(
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
  const _Preview(this.c);

  @override
  Widget build(BuildContext context) {
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
        Semantics(
          label: c.lastMessageSeen ? 'Seen' : 'Sent',
          child: InIcon(InIcons.check,
              size: 15,
              color: c.lastMessageSeen ? AppColors.lilac : AppColors.textFaint),
        ),
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
  final VoidCallback onTap;
  final void Function(String roomId) onJoin;
  const _ConversationRow(
      {required this.c, required this.onTap, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final unread = c.unreadCount > 0;
    return InkWell(
      onTap: onTap,
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
                Expanded(
                  child: Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15)),
                ),
                const SizedBox(width: 8),
                Text(formatRelativeTime(c.lastMessageAt),
                    style: TextStyle(
                        color: unread ? AppColors.lilac : AppColors.textDim,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _Preview(c)),
                if (unread) ...[
                  const SizedBox(width: 8),
                  _UnreadBadge(c.unreadCount),
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
  final VoidCallback onOpen;
  final void Function(String roomId) onJoin;
  const _YourTurnCard(
      {required this.c, required this.onOpen, required this.onJoin});

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
                          const SizedBox(width: 6),
                          Text(formatRelativeTime(c.lastMessageAt),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lilac,
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 3),
                        _Preview(c),
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

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count unread',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 22),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFF1C1638),
                borderRadius: BorderRadius.circular(16)),
            child: const Center(
                child: InIcon(InIcons.users, size: 22, color: AppColors.lilac)),
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
