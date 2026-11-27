import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';
import '../messages/group_thread_screen.dart';
import '../party/party_screen.dart';
import 'community_manage_screens.dart';

/// A community's picture, or its first letter on a colour.
class CommunityAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const CommunityAvatar(
      {super.key, required this.name, this.url, this.size = 40});

  static const _colors = [
    Color(0xFFFF5266),
    Color(0xFF2F8F6B),
    Color(0xFFCD172C),
    Color(0xFFFFFFFF),
    Color(0xFFB81427),
    Color(0xFF8A6A1E),
  ];

  @override
  Widget build(BuildContext context) {
    final u = url;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: _colors[name.hashCode.abs() % _colors.length],
          borderRadius: BorderRadius.circular(size * 0.28)),
      child: u != null && u.isNotEmpty
          ? AppImage(source: u, fit: BoxFit.cover)
          : Center(
              child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w800))),
    );
  }
}

/// A community: the preview (about, rules, groups, Join / Ask) for people
/// not in it, and the home (voice room, Announcements, groups, admin
/// tools) for members.
class CommunityHomeScreen extends StatefulWidget {
  final String communityId;
  const CommunityHomeScreen({super.key, required this.communityId});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/communities/${widget.communityId}/home')
          as Map<String, dynamic>;
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load this community.');
    }
  }

  Map<String, dynamic> get _c =>
      Map<String, dynamic>.from(_data?['community'] as Map? ?? {});

  void _toast(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final r = await ApiClient.post('/communities/${widget.communityId}/join')
          as Map<String, dynamic>;
      if (r['requested'] == true) _toast('Asked to join. An admin will approve you.');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> g) async {
    try {
      final r = await ApiClient.post('/communities/groups/${g['id']}/join')
          as Map<String, dynamic>;
      if (r['requested'] == true) {
        _toast('Asked to join ${g['name']}');
      } else {
        _openGroup(g);
      }
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _openGroup(Map<String, dynamic> g) => Navigator.of(context)
      .push(MaterialPageRoute(
          builder: (_) => GroupThreadScreen(
              groupId: g['id'] as String, name: g['name'] as String? ?? '')))
      .then((_) => _load());

  Future<void> _voiceRoom() async {
    try {
      final room = await ApiClient.get('/communities/${widget.communityId}/room')
          as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } catch (_) {
      _toast('Couldn’t open the voice room.');
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(),
        body: Center(
            child: _error != null
                ? Text(_error!, style: const TextStyle(color: AppColors.textDim))
                : const Spinner()),
      );
    }
    return _c['isJoined'] == true ? _home() : _preview();
  }

  Widget _header() {
    final c = _c;
    final members = (c['memberCount'] as num?)?.toInt() ?? 0;
    final groups = (c['groupCount'] as num?)?.toInt() ?? 0;
    final mode = switch (c['joinMode']) {
      'ask' => 'Ask to join',
      'invite' => 'Invite only',
      _ => 'Public',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(children: [
        CommunityAvatar(
            name: c['name'] as String? ?? '',
            url: c['avatarUrl'] as String?,
            size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['name'] as String? ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('$members member${members == 1 ? '' : 's'} · $groups group${groups == 1 ? '' : 's'} · $mode',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700)),
      );

  Widget _groupTile(Map<String, dynamic> g, {Widget? trailing, VoidCallback? onTap}) {
    final unread = (g['unread'] as num?)?.toInt() ?? 0;
    final sub = (g['lastMessage'] as String?)?.isNotEmpty == true
        ? g['lastMessage'] as String
        : '${g['memberCount'] ?? 0} members${g['joinMode'] == 'ask' ? ' · Ask to join' : ''}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: g['isAnnouncements'] == true
            ? const Color(0xFF5A3A2A)
            : const Color(0xFF000000),
        child: InIcon(
            g['isAnnouncements'] == true ? InIcons.bell : InIcons.users,
            size: 18,
            color: Colors.white),
      ),
      title: Text(g['name'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
      trailing: trailing ??
          (unread > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.lilac,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                )
              : null),
    );
  }

  Widget _preview() {
    final c = _c;
    final groups = [
      if (_data!['announcements'] != null)
        Map<String, dynamic>.from(_data!['announcements'] as Map),
      for (final g in (_data!['moreGroups'] as List? ?? const []))
        Map<String, dynamic>.from(g as Map),
    ];
    final requested = c['requested'] == true;
    final invite = c['joinMode'] == 'invite';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
        _header(),
        if ((c['description'] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(c['description'] as String,
                style: const TextStyle(color: AppColors.textDim, height: 1.45)),
          ),
        if ((c['rules'] as String?)?.isNotEmpty == true) ...[
          _section('Rules'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(c['rules'] as String,
                style: const TextStyle(color: AppColors.textDim, height: 1.45)),
          ),
        ],
        _section('Groups · ${groups.length}'),
        for (final g in groups)
          _groupTile(g,
              trailing: Text('${g['memberCount'] ?? 0}',
                  style: const TextStyle(color: AppColors.textFaint))),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text('Messages show once you join.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy || requested || invite ? null : _join,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(invite
                ? 'Invite only · ask a member for the link'
                : requested
                    ? 'Asked · waiting for an admin'
                    : c['joinMode'] == 'ask'
                        ? 'Ask to join'
                        : 'Join community'),
          ),
        ),
      ),
    );
  }

  Widget _home() {
    final c = _c;
    final isAdmin = c['isAdmin'] == true;
    final pending = (c['pendingRequests'] as num?)?.toInt() ?? 0;
    final ann = _data!['announcements'] as Map?;
    final mine = [
      for (final g in (_data!['myGroups'] as List? ?? const []))
        Map<String, dynamic>.from(g as Map)
    ];
    final more = [
      for (final g in (_data!['moreGroups'] as List? ?? const []))
        Map<String, dynamic>.from(g as Map)
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(actions: [
        if (isAdmin)
          IconButton(
            tooltip: 'Join requests',
            onPressed: () => _push(
                CommunityRequestsScreen(communityId: widget.communityId)),
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.how_to_reg_rounded),
            ),
          ),
        IconButton(
          tooltip: 'Community info',
          onPressed: () =>
              _push(CommunityInfoScreen(communityId: widget.communityId)),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
          _header(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: const Color(0xFF15261F),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _voiceRoom,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(children: [
                    InIcon(InIcons.mic, size: 20, color: Color(0xFF5DCAA5)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Community voice room',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('Join',
                        style: TextStyle(
                            color: Color(0xFF5DCAA5),
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
          if (ann != null) ...[
            _section('Announcements'),
            _groupTile(Map<String, dynamic>.from(ann),
                onTap: () => _openGroup(Map<String, dynamic>.from(ann))),
          ],
          _section('Your groups'),
          if (mine.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('Join a group below to start chatting.',
                  style: TextStyle(color: AppColors.textFaint)),
            ),
          for (final g in mine) _groupTile(g, onTap: () => _openGroup(g)),
          if (more.isNotEmpty) ...[
            _section('More groups'),
            for (final g in more)
              _groupTile(g,
                  trailing: g['requested'] == true
                      ? const Text('Asked',
                          style: TextStyle(color: AppColors.textFaint))
                      : OutlinedButton(
                          onPressed: () => _joinGroup(g),
                          style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder()),
                          child: Text(g['joinMode'] == 'ask' ? 'Ask' : 'Join'),
                        )),
          ],
        ]),
      ),
      bottomNavigationBar: isAdmin
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _push(CommunityGroupCreateScreen(
                          communityId: widget.communityId,
                          communityName: c['name'] as String? ?? '')),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create group'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _push(
                          CommunityAddGroupsScreen(communityId: widget.communityId)),
                      child: const Text('Add a group'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
