import '../../theme/insync_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../../core/format.dart';
import '../communities/community_detail_screen.dart';
import '../feed/hashtag_screen.dart';
import '../messages/message_thread_screen.dart';
import '../profile/creator_profile_screen.dart';

/// "In Movie night" / "Active now" / "Active 5m ago" for a friend row.
String? friendActivity(Map<String, dynamic> f) {
  if (f['roomTitle'] != null) return 'In ${f['roomTitle']}';
  if (f['online'] == true) return 'Active now';
  final last = DateTime.tryParse('${f['lastActiveAt'] ?? ''}');
  if (last != null) return 'Active ${formatRelativeTime(last)}';
  return null;
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String _tab = 'friends';
  bool _loading = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _suggested = [];
  final Set<String> _suggestedSent = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/friends').catchError((_) => []),
      ApiClient.get('/friends/requests').catchError((_) => []),
      ApiClient.get('/friends/suggestions').catchError((_) => []),
    ]);
    if (!mounted) return;
    setState(() {
      _friends = ((results[0] as List?) ?? []).cast<Map<String, dynamic>>();
      _requests = ((results[1] as List?) ?? []).cast<Map<String, dynamic>>();
      _suggested = ((results[2] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _accept(String id) async {
    try {
      await ApiClient.post('/friends/$id/accept');
      _load();
    } catch (_) {}
  }

  Future<void> _reject(String id) async {
    try {
      await ApiClient.post('/friends/$id/reject');
      _load();
    } catch (_) {}
  }

  Future<void> _addSuggested(String userId) async {
    try {
      await ApiClient.post('/friends/request', body: {'toUserId': userId});
      if (mounted) setState(() => _suggestedSent.add(userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send request')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tabChip('friends', 'Friends'),
                _tabChip(
                    'requests',
                    _requests.isNotEmpty
                        ? 'Requests · ${_requests.length}'
                        : 'Requests'),
                _tabChip('find', 'People'),
                _tabChip('communities', 'Communities'),
                _tabChip('tags', '#Tags'),
              ],
            ),
          ),
          Expanded(
            child: _tab == 'find'
                ? const _FindPeopleTab()
                : _tab == 'communities' || _tab == 'tags'
                    ? _SearchTab(key: ValueKey(_tab), tags: _tab == 'tags')
                    : _loading
                        ? const Center(child: Spinner())
                        : _tab == 'friends'
                            ? (_friends.isEmpty
                                ? const Center(
                                    child: Text('No friends yet',
                                        style: TextStyle(
                                            color: AppColors.textFaint)))
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: _friends.length,
                                    itemBuilder: (context, i) {
                                      final f = _friends[i];
                                      return GestureDetector(
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    CreatorProfileScreen(
                                                        userId: f['id']
                                                            as String))),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 9),
                                          child: Row(children: [
                                            Avatar(
                                                src: f['avatarUrl'] as String?,
                                                name: f['name'] as String?,
                                                size: AvatarSize.md),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        f['name'] as String? ??
                                                            '',
                                                        style: const TextStyle(
                                                            color:
                                                                AppColors.text,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13.5)),
                                                    if (friendActivity(f) !=
                                                        null)
                                                      Text(friendActivity(f)!,
                                                          style: TextStyle(
                                                              color: f['roomTitle'] !=
                                                                          null ||
                                                                      f['online'] ==
                                                                          true
                                                                  ? AppColors
                                                                      .success
                                                                  : AppColors
                                                                      .textFaint,
                                                              fontSize: 12)),
                                                  ]),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  'Message ${f['name'] ?? ''}',
                                              onPressed: () => Navigator
                                                      .of(context)
                                                  .push(MaterialPageRoute(
                                                      builder: (_) =>
                                                          MessageThreadScreen(
                                                              userId: f['id']
                                                                  as String,
                                                              name: f['name']
                                                                      as String? ??
                                                                  '',
                                                              avatarUrl: f[
                                                                      'avatarUrl']
                                                                  as String?))),
                                              icon: const InIcon(InIcons.chat,
                                                  size: 20,
                                                  color: AppColors.lilac),
                                            ),
                                          ]),
                                        ),
                                      );
                                    },
                                  ))
                            : ListView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                children: [
                                  if (_requests.isEmpty && _suggested.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 40),
                                      child: Center(
                                          child: Text('No pending requests',
                                              style: TextStyle(
                                                  color: AppColors.textFaint))),
                                    ),
                                  ..._requests.map((r) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 9),
                                        child: Row(
                                          children: [
                                            Avatar(
                                                src: r['fromAvatarUrl']
                                                    as String?,
                                                name: r['fromName'] as String?,
                                                size: AvatarSize.md),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        r['fromName']
                                                                as String? ??
                                                            '',
                                                        style: const TextStyle(
                                                            color:
                                                                AppColors.text,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13.5)),
                                                    Text(
                                                        [
                                                          if (r['fromUsername'] !=
                                                              null)
                                                            '@${r['fromUsername']}',
                                                          if (((r['mutualCount']
                                                                      as num?) ??
                                                                  0) >
                                                              0)
                                                            '${r['mutualCount']} mutual',
                                                        ].join(' · '),
                                                        style: const TextStyle(
                                                            color: AppColors
                                                                .textFaint,
                                                            fontSize: 11.5)),
                                                  ]),
                                            ),
                                            GestureDetector(
                                              onTap: () =>
                                                  _accept(r['id'] as String),
                                              child: Container(
                                                height: 32,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14),
                                                decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                            colors: AppGradients
                                                                .brand),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999)),
                                                alignment: Alignment.center,
                                                child: const Text('Accept',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () =>
                                                  _reject(r['id'] as String),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color:
                                                            AppColors.border)),
                                                child: const InIcon(
                                                    InIcons.close,
                                                    color: AppColors.textDim,
                                                    size: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  // Friends-of-friends you're not already friends
                                  // with, matching FriendsDark.dc.html's
                                  // "Suggested" section — GET /friends/suggestions
                                  // didn't exist before, this section had nothing
                                  // to show.
                                  if (_suggested.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 18, 20, 8),
                                      child: Text('SUGGESTED',
                                          style: const TextStyle(
                                              color: AppColors.textFaint,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6)),
                                    ),
                                    ..._suggested.map((s) {
                                      final id = s['id'] as String;
                                      final sent = _suggestedSent.contains(id);
                                      final mutualCount =
                                          s['mutualCount'] as int? ?? 0;
                                      return GestureDetector(
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    CreatorProfileScreen(
                                                        userId: id))),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 9),
                                          child: Row(
                                            children: [
                                              Avatar(
                                                  src:
                                                      s['avatarUrl'] as String?,
                                                  name: s['name'] as String?,
                                                  size: AvatarSize.md),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        s['name'] as String? ??
                                                            '',
                                                        style: const TextStyle(
                                                            color:
                                                                AppColors.text,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13.5)),
                                                    Text(
                                                        s['reason']
                                                                as String? ??
                                                            '$mutualCount mutual friend${mutualCount == 1 ? '' : 's'}',
                                                        style: const TextStyle(
                                                            color: AppColors
                                                                .textFaint,
                                                            fontSize: 11.5)),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: sent
                                                    ? null
                                                    : () => _addSuggested(id),
                                                child: Container(
                                                  height: 32,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 14),
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999),
                                                      border: Border.all(
                                                          color: AppColors
                                                              .border)),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                      sent ? 'Sent' : 'Add',
                                                      style: const TextStyle(
                                                          color:
                                                              AppColors.textDim,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 12)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) => ChoiceChip(
        label: Text(label),
        selected: _tab == key,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _tab == key ? AppColors.primary : AppColors.textDim,
            fontSize: 12),
        backgroundColor: AppColors.surface,
        onSelected: (_) => setState(() => _tab = key),
      );
}

/// Communities or #tags, from GET /search.
class _SearchTab extends StatefulWidget {
  final bool tags;
  const _SearchTab({super.key, required this.tags});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  Timer? _debounce;
  List<Map<String, dynamic>>? _results;

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final type = widget.tags ? 'hashtags' : 'communities';
        final data = await ApiClient.get(
                '/search?type=$type&q=${Uri.encodeQueryComponent(q.trim())}')
            as Map;
        if (!mounted) return;
        if (widget.tags) {
          // Count each tag that starts with what you typed.
          final want = q.trim().replaceFirst('#', '').toLowerCase();
          final counts = <String, int>{};
          for (final p in (data['posts'] as List? ?? []).cast<Map>()) {
            for (final m
                in RegExp(r'#(\w+)').allMatches('${p['text'] ?? ''}')) {
              final t = m.group(1)!.toLowerCase();
              if (t.startsWith(want)) counts[t] = (counts[t] ?? 0) + 1;
            }
          }
          final list = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          setState(() => _results = [
                for (final e in list) {'tag': e.key, 'count': e.value}
              ]);
        } else {
          setState(() => _results = (data['communities'] as List? ?? [])
              .cast<Map>()
              .map(Map<String, dynamic>.from)
              .toList());
        }
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _results;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        TextField(
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: AppColors.text),
          decoration: InputDecoration(
              hintText: widget.tags ? 'Search #tags' : 'Search communities'),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: r == null
              ? const SizedBox.shrink()
              : r.isEmpty
                  ? const Center(
                      child: Text('No results',
                          style: TextStyle(color: AppColors.textFaint)))
                  : ListView(children: [
                      for (final x in r)
                        widget.tags
                            ? ListTile(
                                leading: const InIcon(InIcons.hash,
                                    size: 20, color: AppColors.lilac),
                                title: Text('#${x['tag']}'),
                                subtitle: Text(
                                    '${x['count']} post${x['count'] == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 12)),
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => HashtagScreen(
                                            tag: x['tag'] as String))),
                              )
                            : ListTile(
                                leading: Avatar(
                                    src: x['avatarUrl'] as String?,
                                    name: x['name'] as String?,
                                    size: AvatarSize.sm),
                                title: Text(x['name'] as String? ?? ''),
                                subtitle: Text(
                                    '${x['memberCount'] ?? 0} members',
                                    style: const TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 12)),
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => CommunityDetailScreen(
                                            communityId: x['id'] as String,
                                            name: x['name'] as String?))),
                              ),
                    ]),
        ),
      ]),
    );
  }
}

class _FindPeopleTab extends StatefulWidget {
  const _FindPeopleTab();

  @override
  State<_FindPeopleTab> createState() => _FindPeopleTabState();
}

class _FindPeopleTabState extends State<_FindPeopleTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>>? _results;
  final Set<String> _sentIds = {};

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final data = await ApiClient.get(
            '/users/search?q=${Uri.encodeQueryComponent(q.trim())}');
        if (mounted) {
          setState(
              () => _results = (data as List).cast<Map<String, dynamic>>());
        }
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  Future<void> _send(String userId) async {
    try {
      await ApiClient.post('/friends/request', body: {'toUserId': userId});
      if (mounted) setState(() => _sentIds.add(userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send request')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: const TextStyle(color: AppColors.text),
            decoration:
                const InputDecoration(hintText: 'Search by name or username…'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _results?.length ?? 0,
              itemBuilder: (context, i) {
                final u = _results![i];
                final id = u['id'] as String;
                final sent = _sentIds.contains(id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: insyncClay(radius: 22),
                  child: Row(
                    children: [
                      Avatar(
                          src: u['avatarUrl'] as String?,
                          name: u['name'] as String?,
                          size: AvatarSize.sm),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['name'] as String? ?? '',
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w500)),
                            if (u['username'] != null)
                              Text('@${u['username']}',
                                  style: const TextStyle(
                                      color: AppColors.textFaint,
                                      fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                          onPressed: sent ? null : () => _send(id),
                          child: Text(sent ? 'Sent' : 'Add',
                              style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
