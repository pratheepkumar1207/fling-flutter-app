import '../../theme/insync_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

/// Friends / Recents (people who've joined this room before, via
/// GET /rooms/:id/recent-participants) / Communities tabs, plus a
/// tap-to-search field for anyone else — same POST /rooms/:id/invite
/// endpoint underneath regardless of which list a pick came from. A folding
/// "Share room" bar stays at the top for the link, apps and a QR code.
/// Communities open to their members (online first); the owner and
/// moderators can also post the room to the community.
class InviteScreen extends StatefulWidget {
  final String roomId;
  final String? roomTitle;
  const InviteScreen({super.key, required this.roomId, this.roomTitle});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  bool _loadingFriends = true;
  bool _loadingRecents = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _recents = [];

  bool _searching = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  final Set<String> _selected = {};
  bool _inviting = false;

  // Communities tab.
  bool _loadingCommunities = true;
  List<Map<String, dynamic>> _communities = [];
  String? _openCommunity;
  final Map<String, List<Map<String, dynamic>>> _members = {};
  final Map<String, int> _memberTotals = {};
  final Set<String> _loadingMembers = {};
  final Set<String> _postTo = {};

  // The folding share bar.
  bool _shareOpen = false;

  bool get _nothingPicked => _selected.isEmpty && _postTo.isEmpty;

  String get _buttonLabel {
    final n = _selected.length, c = _postTo.length;
    final invite = n == 0 ? null : 'Invite $n ${n == 1 ? 'person' : 'people'}';
    final post =
        c == 0 ? null : 'Post to $c ${c == 1 ? 'community' : 'communities'}';
    if (invite == null && post == null) return 'Send invites';
    return [invite, post].whereType<String>().join(' · ');
  }

  String get _link => '${ApiClient.baseUrl}/r/${widget.roomId}';
  String get _shareText => 'Join "${widget.roomTitle ?? 'my room'}" on Insync';

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadRecents();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    try {
      final data = await ApiClient.get('/communities/mine?online=1');
      if (!mounted) return;
      setState(() {
        _communities = ((data as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
          ..sort((a, b) => ((b['onlineCount'] as num?) ?? 0)
              .compareTo((a['onlineCount'] as num?) ?? 0));
        _loadingCommunities = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCommunities = false);
    }
  }

  Future<void> _loadMembers(String id) async {
    if (_loadingMembers.contains(id)) return;
    setState(() => _loadingMembers.add(id));
    try {
      final have = _members[id]?.length ?? 0;
      final data =
          await ApiClient.get('/communities/$id/people?offset=$have&limit=50')
              as Map;
      if (!mounted) return;
      setState(() {
        _members[id] = [
          ...?_members[id],
          ...((data['people'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        ];
        _memberTotals[id] = (data['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMembers.remove(id));
    }
  }

  void _toggleCommunity(String id) {
    setState(() => _openCommunity = _openCommunity == id ? null : id);
    if (_openCommunity == id && _members[id] == null) _loadMembers(id);
  }

  void _selectAllOnline(String id) {
    final online = (_members[id] ?? const [])
        .where((p) => p['online'] == true)
        .map((p) => p['id'] as String);
    setState(() {
      final all = online.every(_selected.contains);
      if (all) {
        _selected.removeAll(online);
      } else {
        _selected.addAll(online);
      }
    });
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) return;
    setState(() => _shareOpen = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _openApp(Uri uri) async {
    setState(() => _shareOpen = false);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Share.share('$_shareText $_link');
    }
  }

  // Instagram has no way to pass text in: the link is copied and Instagram
  // opens, ready to paste.
  Future<void> _instagram() async {
    await Clipboard.setData(ClipboardData(text: '$_shareText $_link'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied — paste it in Instagram')));
    await _openApp(Uri.parse('https://www.instagram.com/direct/inbox/'));
  }

  void _showQr() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Scan to join'),
          content: SizedBox(
            width: 220,
            height: 220,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: QrImageView(data: _link),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done')),
          ],
        ),
      );

  Widget _shareBar() {
    final text = Uri.encodeComponent(_shareText);
    final url = Uri.encodeComponent(_link);
    Widget app(Widget icon, Color bg, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: bg.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 10.5)),
            ]),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Semantics(
            button: true,
            expanded: _shareOpen,
            label: 'Share room',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _shareOpen = !_shareOpen),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9)),
                  child: const InIcon(InIcons.share,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Share room',
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                AnimatedRotation(
                  turns: _shareOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const InIcon(InIcons.down,
                      size: 18, color: AppColors.textDim),
                ),
              ]),
            ),
          ),
          if (_shareOpen) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const InIcon(InIcons.link, size: 14, color: AppColors.textDim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 12)),
                ),
                TextButton(onPressed: _copyLink, child: const Text('Copy')),
              ]),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              app(
                  const FaIcon(FontAwesomeIcons.whatsapp,
                      color: Color(0xFF25D366), size: 20),
                  const Color(0xFF25D366),
                  'WhatsApp',
                  () =>
                      _openApp(Uri.parse('https://wa.me/?text=$text%20$url'))),
              app(
                  const FaIcon(FontAwesomeIcons.instagram,
                      color: Color(0xFFE1306C), size: 20),
                  const Color(0xFFE1306C),
                  'Instagram',
                  _instagram),
              app(
                  const FaIcon(FontAwesomeIcons.telegram,
                      color: Color(0xFF29A9EA), size: 20),
                  const Color(0xFF29A9EA),
                  'Telegram',
                  () => _openApp(
                      Uri.parse('https://t.me/share/url?url=$url&text=$text'))),
              app(const InIcon(InIcons.qr, size: 20, color: Colors.white),
                  Colors.white, 'QR code', _showQr),
              app(const InIcon(InIcons.more, size: 20, color: Colors.white),
                  Colors.white, 'More', () {
                setState(() => _shareOpen = false);
                Share.share('$_shareText $_link');
              }),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _communitiesTab() {
    if (_loadingCommunities) return const Center(child: Spinner());
    if (_communities.isEmpty) {
      return const Center(
          child: Text('You’re not in any communities yet.',
              style: TextStyle(color: AppColors.textFaint)));
    }
    return ListView(children: [
      for (final c in _communities) ..._communityTile(c),
    ]);
  }

  List<Widget> _communityTile(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final open = _openCommunity == id;
    final members = _members[id];
    final online = (c['onlineCount'] as num?)?.toInt() ?? 0;
    final canPost = c['myRole'] == 'owner' ||
        c['myRole'] == 'moderator' ||
        c['myRole'] == 'admin';
    Widget chip(String label, bool on, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: on ? AppColors.primary : AppColors.border),
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? AppColors.lilac : AppColors.textDim,
                    fontSize: 12)),
          ),
        );
    final onlineIds = (members ?? const [])
        .where((p) => p['online'] == true)
        .map((p) => p['id'] as String)
        .toList();
    return [
      InkWell(
        onTap: () => _toggleCommunity(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  ((c['name'] as String?) ?? '?')
                      .characters
                      .first
                      .toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.lilac,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['name'] as String? ?? '',
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5)),
                    Text('${c['memberCount'] ?? 0} members · $online online',
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 11.5)),
                  ]),
            ),
            if (_postTo.contains(id))
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: InIcon(InIcons.pin, size: 15, color: AppColors.lilac),
              ),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const InIcon(InIcons.down,
                  size: 18, color: AppColors.textDim),
            ),
          ]),
        ),
      ),
      if (open)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
              child: Row(children: [
                if (canPost)
                  chip('Post to community', _postTo.contains(id), () {
                    setState(() {
                      if (!_postTo.remove(id)) _postTo.add(id);
                    });
                  }),
                if (onlineIds.isNotEmpty)
                  chip('Select all online', onlineIds.every(_selected.contains),
                      () => _selectAllOnline(id)),
              ]),
            ),
            if (members == null)
              const Padding(
                  padding: EdgeInsets.all(12), child: Spinner(size: 18))
            else if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No one else here yet.',
                    style: TextStyle(color: AppColors.textFaint)),
              )
            else ...[
              for (final p in members)
                _personTile(p, online: p['online'] == true),
              if (members.length < (_memberTotals[id] ?? 0))
                TextButton(
                  onPressed: _loadingMembers.contains(id)
                      ? null
                      : () => _loadMembers(id),
                  child: Text(
                      'Show more (${(_memberTotals[id] ?? 0) - members.length})'),
                ),
            ],
          ]),
        ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final data = await ApiClient.get('/friends');
      if (!mounted) return;
      setState(() {
        _friends = ((data as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loadingFriends = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadRecents() async {
    try {
      final data =
          await ApiClient.get('/rooms/${widget.roomId}/recent-participants');
      if (!mounted) return;
      setState(() {
        _recents = ((data as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loadingRecents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRecents = false);
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final data = await ApiClient.get(
            '/search?q=${Uri.encodeComponent(query)}&type=users');
        if (!mounted) return;
        final users = (data is Map ? data['users'] as List? : null) ?? [];
        setState(() {
          _searchResults =
              users.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _searchLoading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _searchResults = [];
        _searchLoading = false;
      }
    });
  }

  Future<void> _invite() async {
    if (_selected.isEmpty && _postTo.isEmpty) return;
    setState(() => _inviting = true);
    try {
      for (final id in _postTo) {
        await ApiClient.post('/communities/$id/room-post',
            body: {'roomId': widget.roomId});
      }
      if (_selected.isNotEmpty) {
        await ApiClient.post('/rooms/${widget.roomId}/invite',
            body: {'userIds': _selected.toList()});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_selected.isEmpty
                ? 'Posted to ${_postTo.length == 1 ? 'the community' : '${_postTo.length} communities'}'
                : 'Invites sent')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send invites')));
      }
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Widget _personTile(Map<String, dynamic> p, {bool online = false}) {
    final id = (p['id'] ?? p['userId']) as String;
    final selected = _selected.contains(id);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Row(
          children: [
            Stack(clipBehavior: Clip.none, children: [
              Avatar(
                  src: p['avatarUrl'] as String?,
                  name: p['name'] as String?,
                  size: AvatarSize.sm),
              if (online)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3CCF7E),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5)),
                  if (p['username'] != null)
                    Text('@${p['username']}',
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 11.5)),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? const LinearGradient(colors: AppGradients.brand)
                    : null,
                border: selected
                    ? null
                    : Border.all(color: AppColors.border, width: 1.5),
              ),
              child: selected
                  ? const InIcon(InIcons.check, color: Colors.white, size: 15)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
      {required bool loading,
      required List<Map<String, dynamic>> people,
      required String emptyText}) {
    if (loading) return const Center(child: Spinner());
    if (people.isEmpty) {
      return Center(
          child: Text(emptyText,
              style: const TextStyle(color: AppColors.textFaint)));
    }
    return ListView.builder(
      itemCount: people.length,
      itemBuilder: (context, i) => _personTile(people[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                    hintText: 'Search people…',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    border: InputBorder.none),
                onChanged: _onSearchChanged,
              )
            : const Text('Invite to room'),
        actions: [
          if (!_searching && _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                  child: Text('${_selected.length} selected',
                      style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 13,
                          fontWeight: FontWeight.w700))),
            ),
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search people',
            onPressed: _toggleSearch,
            icon: InIcon(_searching ? InIcons.close : InIcons.search,
                color: AppColors.textDim),
          ),
        ],
        bottom: _searching
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textDim,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Recents'),
                  Tab(text: 'Communities'),
                ],
              ),
      ),
      body: Column(children: [
        if (!_searching) _shareBar(),
        Expanded(
            child: _searching
                ? (_searchLoading
                    ? const Center(child: Spinner())
                    : _searchController.text.trim().isEmpty
                        ? const Center(
                            child: Text('Search by name or username.',
                                style: TextStyle(color: AppColors.textFaint)))
                        : _searchResults.isEmpty
                            ? const Center(
                                child: Text('No one found.',
                                    style:
                                        TextStyle(color: AppColors.textFaint)))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, i) =>
                                    _personTile(_searchResults[i]),
                              ))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _list(
                          loading: _loadingFriends,
                          people: _friends,
                          emptyText: 'No friends yet.'),
                      _list(
                          loading: _loadingRecents,
                          people: _recents,
                          emptyText: "No one's joined this room before."),
                      _communitiesTab(),
                    ],
                  )),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GestureDetector(
            onTap: (_nothingPicked || _inviting) ? null : _invite,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: (_nothingPicked || _inviting)
                    ? null
                    : const LinearGradient(colors: AppGradients.brand),
                color:
                    (_nothingPicked || _inviting) ? AppColors.surface2 : null,
              ),
              alignment: Alignment.center,
              child: Text(
                _inviting ? 'Sending…' : _buttonLabel,
                style: TextStyle(
                    color: (_nothingPicked || _inviting)
                        ? AppColors.textFaint
                        : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
