import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';

/// Matches CommunityDetailDark.dc.html: banner header with an overlapping
/// logo, name + Join/Joined button, then a Pinned/Chat/Members tab row —
/// previously one long mixed scroll with no banner and no tabs.
class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final String? name;
  const CommunityDetailScreen({super.key, required this.communityId, this.name});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

// Same deterministic per-name gradient as the Communities list, so a
// community's banner color is consistent between the card and this screen.
const _bannerGradients = [
  [Color(0xFFB251C5), Color(0xFF8E3AAF)],
  [Color(0xFF4FB98A), Color(0xFF2E8C64)],
  [Color(0xFFE8A23F), Color(0xFFC66B2E)],
  [Color(0xFF4272D9), Color(0xFF2E4FA3)],
];

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  String _tab = 'pinned';
  bool _loading = true;
  Map<String, dynamic>? _community;
  bool _pinnedLoading = true;
  List<Map<String, dynamic>> _members = [];
  Map<String, Map<String, dynamic>> _profiles = {};
  List<Map<String, dynamic>> _pinned = [];
  final _pinController = TextEditingController();
  bool _pinning = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadMembers();
    _loadPinned();
  }

  Future<void> _loadCommunity() async {
    try {
      final data = await ApiClient.get('/communities/${widget.communityId}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _community = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final data = await ApiClient.get('/communities/${widget.communityId}/members');
      final members = (data as List).cast<Map<String, dynamic>>();
      final pairs = await Future.wait(members.map((m) async {
        try {
          final profile = await ApiClient.get('/creators/${m['userId']}/profile') as Map<String, dynamic>;
          return MapEntry(m['userId'] as String, profile);
        } catch (_) {
          return MapEntry(m['userId'] as String, <String, dynamic>{});
        }
      }));
      if (!mounted) return;
      setState(() {
        _members = members;
        _profiles = Map.fromEntries(pairs);
      });
    } catch (_) {}
  }

  Future<void> _loadPinned() async {
    try {
      final data = await ApiClient.get('/communities/${widget.communityId}/pinned');
      if (!mounted) return;
      setState(() {
        _pinned = (data as List).cast<Map<String, dynamic>>();
        _pinnedLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pinnedLoading = false);
    }
  }

  Future<void> _enterRoom() async {
    try {
      final room = await ApiClient.get('/communities/${widget.communityId}/room') as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active room for this community')));
    }
  }

  Future<void> _toggleMembership() async {
    final joined = _community?['isJoined'] == true;
    setState(() => _joining = true);
    try {
      await ApiClient.post('/communities/${widget.communityId}/${joined ? 'leave' : 'join'}');
      if (joined && mounted) {
        Navigator.of(context).pop();
        return;
      }
      await Future.wait([_loadCommunity(), _loadMembers()]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _boost() async {
    try {
      final res = await ApiClient.post('/communities/${widget.communityId}/boost', body: {'days': 7}) as Map<String, dynamic>;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Boosted until ${res['boostedUntil']}')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to boost')));
    }
  }

  Future<void> _pin() async {
    final text = _pinController.text.trim();
    if (text.isEmpty) return;
    setState(() => _pinning = true);
    try {
      await ApiClient.post('/communities/${widget.communityId}/pinned', body: {'text': text});
      _pinController.clear();
      await _loadPinned();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pin message')));
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  Future<void> _setModerator(String userId) async {
    try {
      await ApiClient.post('/communities/${widget.communityId}/moderators/$userId');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promoted to moderator')));
      _loadMembers();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update role')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    Map<String, dynamic>? myMembership;
    for (final m in _members) {
      if (m['userId'] == myId) {
        myMembership = m;
        break;
      }
    }
    final canModerate = myMembership != null && myMembership['role'] != 'member';
    final name = _community?['name'] as String? ?? widget.name ?? 'Community';
    final gradient = _bannerGradients[name.hashCode.abs() % _bannerGradients.length];
    final joined = _community?['isJoined'] == true;
    final isOwner = myMembership?['role'] == 'owner';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: Spinner())
          : SafeArea(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 84,
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
                      ),
                      Positioned(
                        top: 10,
                        left: 6,
                        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                      ),
                      if (isOwner)
                        Positioned(
                          top: 10,
                          right: 6,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                            color: AppColors.surface2,
                            onSelected: (v) {
                              if (v == 'boost') _boost();
                            },
                            itemBuilder: (_) => const [PopupMenuItem(value: 'boost', child: Text('Boost 7 days', style: TextStyle(color: AppColors.text)))],
                          ),
                        ),
                      Positioned(
                        left: 16,
                        bottom: -22,
                        child: Container(
                          width: 56,
                          height: 56,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
                          child: Container(
                            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient), borderRadius: BorderRadius.circular(13)),
                            alignment: Alignment.center,
                            child: const Text('🏘️', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: _joining ? null : _toggleMembership,
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: joined ? null : const LinearGradient(colors: AppGradients.brand),
                              color: joined ? AppColors.surface2 : null,
                              border: joined ? Border.all(color: AppColors.border) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(joined ? 'Joined' : 'Join', style: TextStyle(color: joined ? AppColors.textDim : Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 3, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        [
                          if (_community?['description'] != null && (_community!['description'] as String).isNotEmpty) _community!['description'],
                          '${_community?['memberCount'] ?? _members.length} members',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        _tabButton('pinned', 'Pinned'),
                        _tabButton('chat', 'Chat'),
                        _tabButton('members', 'Members'),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(child: _tabContent(canModerate)),
                ],
              ),
            ),
    );
  }

  Widget _tabButton(String key, String label) {
    final selected = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = key),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.text : Colors.transparent, width: 2))),
          child: Text(label, style: TextStyle(color: selected ? AppColors.text : AppColors.textFaint, fontSize: 12.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _tabContent(bool canModerate) {
    switch (_tab) {
      case 'chat':
        return _chatTab();
      case 'members':
        return _membersTab(canModerate);
      default:
        return _pinnedTab(canModerate);
    }
  }

  Widget _pinnedTab(bool canModerate) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        if (_pinnedLoading)
          const Center(child: Spinner(size: 22))
        else if (_pinned.isEmpty)
          const Text('Nothing pinned yet.', style: TextStyle(color: AppColors.textFaint, fontSize: 13))
        else
          ..._pinned.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gold.withValues(alpha: 0.4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.push_pin_rounded, size: 12, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text('Pinned', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 5),
                    Text(p['text'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.4)),
                  ],
                ),
              )),
        if (canModerate)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: _pinController,
                      style: const TextStyle(color: AppColors.text, fontSize: 13),
                      decoration: const InputDecoration(hintText: 'Pin a message…', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pinning ? null : _pin,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: _pinning ? null : const LinearGradient(colors: AppGradients.brand), color: _pinning ? AppColors.surface2 : null),
                    alignment: Alignment.center,
                    child: Text('Pin', style: TextStyle(color: _pinning ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: _enterRoom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, color: AppColors.textDim, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Community voice room', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      Text('Tap to join', style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
                    ],
                  ),
                ),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: const LinearGradient(colors: AppGradients.brand)),
                  alignment: Alignment.center,
                  child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // No standalone community-chat backend exists (communities only get a
  // voice room, which carries its own real-time chat via the room socket)
  // — this points there honestly instead of faking a chat UI with nothing
  // behind it.
  Widget _chatTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, color: AppColors.textFaint, size: 36),
            const SizedBox(height: 12),
            const Text('Chat happens in the voice room', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _enterRoom,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: const LinearGradient(colors: AppGradients.brand)),
                alignment: Alignment.center,
                child: const Text('Join voice room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _membersTab(bool canModerate) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: _members.map((m) {
        final userId = m['userId'] as String;
        final profile = _profiles[userId];
        final isMe = userId == Provider.of<AuthProvider>(context, listen: false).user?.id;
        final role = m['role'] as String? ?? 'member';
        return ListTile(
          onTap: () => openProfile(context, userId),
          leading: Avatar(src: profile?['avatarUrl'] as String?, name: profile?['name'] as String?, size: AvatarSize.sm),
          title: Text(isMe ? 'You' : (profile?['name'] as String? ?? 'Member'), style: const TextStyle(color: AppColors.text)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role,
                style: TextStyle(
                  color: role == 'owner' ? AppColors.gold : role == 'moderator' ? AppColors.accent : AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canModerate && role == 'member' && !isMe)
                TextButton(
                  onPressed: () => _setModerator(userId),
                  child: const Text('Make mod', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
