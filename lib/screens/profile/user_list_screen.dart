import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import 'creator_profile_screen.dart';

/// Followers/Following — both are just GET /social/followers or
/// /social/following (see routes/social.js), same shape, same row UI, so
/// this is one screen with a Followers/Following tab switcher instead of
/// two separate pushes. Matches FollowListDark.dc.html's own tab header.
class UserListScreen extends StatefulWidget {
  final bool startOnFollowing;

  const UserListScreen({super.key, this.startOnFollowing = false});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late bool _following = widget.startOnFollowing;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  String _query = '';
  Map<String, dynamic>? _counts;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _load();
  }

  Future<void> _loadCounts() async {
    try {
      final data = await ApiClient.get('/social/stats') as Map<String, dynamic>;
      if (mounted) setState(() => _counts = data);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get(_following ? '/social/following' : '/social/followers');
      if (!mounted) return;
      setState(() {
        _users = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchTab(bool following) {
    if (_following == following) return;
    setState(() {
      _following = following;
      _query = '';
    });
    _load();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _users;
    final q = _query.trim().toLowerCase();
    return _users.where((u) {
      final name = (u['name'] as String? ?? '').toLowerCase();
      final username = (u['username'] as String? ?? '').toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(_following ? 'Following' : 'Followers')),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: _tab('Followers', _counts?['followers'], !_following, () => _switchTab(false))),
              Expanded(child: _tab('Following', _counts?['following'], _following, () => _switchTab(true))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: AppColors.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(color: AppColors.text, fontSize: 12.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Search ${_following ? 'following' : 'followers'}',
                        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : results.isEmpty
                    ? Center(child: Text(_users.isEmpty ? 'No one here yet.' : 'No matches.', style: const TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final u = results[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: u['id'] as String))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                              child: Row(
                                children: [
                                  Avatar(src: u['avatarUrl'] as String?, name: u['name'] as String?, size: AvatarSize.md),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                        if (u['username'] != null)
                                          Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, dynamic count, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.text : Colors.transparent, width: 2))),
        child: Text(
          count != null ? '$label · ${formatNumber(count)}' : label,
          style: TextStyle(color: selected ? AppColors.text : AppColors.textFaint, fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
        ),
      ),
    );
  }
}
