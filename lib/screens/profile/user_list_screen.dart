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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: Spinner())
          : _users.isEmpty
              ? Center(child: Text('No one here yet.', style: const TextStyle(color: AppColors.textFaint)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: Avatar(src: u['avatarUrl'] as String?, name: u['name'] as String?, size: AvatarSize.sm),
                      title: Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text)),
                      subtitle: u['username'] != null ? Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)) : null,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: u['id'] as String))),
                    );
                  },
                ),
    );
  }
}
