import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final String? name;
  const CommunityDetailScreen({super.key, required this.communityId, this.name});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  bool _loading = true;
  bool _pinnedLoading = true;
  List<Map<String, dynamic>> _members = [];
  Map<String, Map<String, dynamic>> _profiles = {};
  List<Map<String, dynamic>> _pinned = [];
  final _pinController = TextEditingController();
  bool _pinning = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPinned();
  }

  Future<void> _load() async {
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
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _leave() async {
    try {
      await ApiClient.post('/communities/${widget.communityId}/leave');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {}
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
      _load();
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(widget.name ?? 'Community')),
      body: _loading
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _enterRoom,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: AppGradients.brand)),
                          alignment: Alignment.center,
                          child: const Text('🎙️ Voice room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _leave,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        alignment: Alignment.center,
                        child: const Text('Leave', style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _boost,
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.gold.withValues(alpha: 0.08), border: Border.all(color: AppColors.gold.withValues(alpha: 0.5))),
                    alignment: Alignment.center,
                    child: const Text('🚀 Boost 7 days', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Pinned', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (_pinnedLoading)
                  const Center(child: Spinner(size: 22))
                else if (_pinned.isEmpty)
                  const Text('Nothing pinned yet.', style: TextStyle(color: AppColors.textFaint, fontSize: 13))
                else
                  ..._pinned.map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                        child: Text('📌 ${p['text']}', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                      )),
                if (canModerate)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
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
                const SizedBox(height: 20),
                Text('Members (${_members.length})', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ..._members.map((m) {
                  final userId = m['userId'] as String;
                  final profile = _profiles[userId];
                  final isMe = userId == myId;
                  final role = m['role'] as String? ?? 'member';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
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
                }),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
