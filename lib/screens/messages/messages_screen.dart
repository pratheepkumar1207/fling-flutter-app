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
import 'group_thread_screen.dart';
import 'message_thread_screen.dart';

/// Messages, opened from the top bar: notes, new matches, blends, search,
/// All / Unread and the conversation list.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _load();
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

  int get _unreadChats => _conversations.where((c) => c.unreadCount > 0).length;

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

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([_load(), _loadMatches()]),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Row(children: [
                  InIconButton(InIcons.back,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('Messages',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  InIconButton(InIcons.community,
                      tooltip: 'New group', onPressed: _newGroup),
                  InIconButton(InIcons.useradd,
                      tooltip: 'Find friends',
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FriendsScreen()))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search chats',
                    isDense: true,
                    prefixIcon: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: InIcon(InIcons.search,
                            size: 18, color: AppColors.textFaint)),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 0, minHeight: 0),
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
            const SliverToBoxAdapter(child: BlendsRow()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Wrap(runSpacing: 8, children: [
                  _filterChip('All', _filter == 'all',
                      () => setState(() => _filter = 'all')),
                  _filterChip(
                      _unreadChats > 0 ? 'Unread · $_unreadChats' : 'Unread',
                      _filter == 'unread',
                      () => setState(() => _filter = 'unread')),
                  _filterChip(
                      _groups.isEmpty ? 'Groups' : 'Groups · ${_groups.length}',
                      _filter == 'groups',
                      () => setState(() => _filter = 'groups')),
                  _filterChip(
                      _requestCount > 0
                          ? 'Requests · $_requestCount'
                          : 'Requests',
                      _filter == 'requests',
                      () => setState(() => _filter = 'requests')),
                ]),
              ),
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
                            : 'No chats here.',
                        style: const TextStyle(color: AppColors.textFaint))),
              )
            else
              SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, i) => _ConversationRow(
                  c: results[i],
                  onTap: () => _openChat(
                      results[i].userId, results[i].name, results[i].avatarUrl),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w500),
          onSelected: (_) => onTap(),
        ),
      );

  Widget _matchesRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: Row(children: [
          const Expanded(
            child: Text('New matches',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w600)),
          ),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const DiscoverMatchesScreen())),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('See all',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.lilac,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: _matches.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                  width: 60,
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
                        style: const TextStyle(fontSize: 11)),
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

class _ConversationRow extends StatelessWidget {
  final ConversationSummary c;
  final VoidCallback onTap;
  const _ConversationRow({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = c.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(children: [
          GestureDetector(
            onTap: () => openProfile(context, c.userId),
            child: Stack(children: [
              Avatar(src: c.avatarUrl, name: c.name, size: AvatarSize.md),
              if (c.online)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2.5)),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 2),
              Text('${c.lastMessageIsMine ? 'You: ' : ''}${c.lastMessage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: unread ? AppColors.text : AppColors.textDim,
                      fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                      fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatRelativeTime(c.lastMessageAt),
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            const SizedBox(height: 6),
            if (unread)
              CountBadge(c.unreadCount)
            else
              const SizedBox(height: 16),
          ]),
        ]),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
                          unread > 0 ? FontWeight.w700 : FontWeight.w600,
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
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 12)),
            const SizedBox(height: 6),
            if (unread > 0) CountBadge(unread) else const SizedBox(height: 16),
          ]),
        ]),
      ),
    );
  }
}
