import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import 'creator_profile_screen.dart';

/// Shared Followers/Following list — both are just GET /social/followers
/// or /social/following (see routes/social.js), same shape, same row UI.
class UserListScreen extends StatefulWidget {
  final String title;
  final String endpoint;

  const UserListScreen({super.key, required this.title, required this.endpoint});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get(widget.endpoint);
      if (!mounted) return;
      setState(() {
        _users = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
      appBar: AppBar(title: Text('${widget.title} · ${_users.length}')),
      body: Column(
        children: [
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
                        hintText: 'Search ${widget.title.toLowerCase()}',
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
}
