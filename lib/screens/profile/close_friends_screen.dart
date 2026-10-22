import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/insync_clay.dart';
import '../../widgets/people_picker_sheet.dart';
import 'profile_post_grid.dart';

/// Close friends — who sees the stories and notes you share to "Close
/// friends". They aren't told when you add or remove them.
class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({super.key});

  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen> {
  List<PickedPerson> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/close-friends') as List;
      if (!mounted) return;
      setState(() {
        _friends = data
            .map((e) => PickedPerson.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String id) async {
    try {
      await ApiClient.post('/close-friends/$id');
    } catch (_) {}
  }

  Future<void> _add() async {
    final picked = await showPeoplePicker(context,
        title: 'Add close friends', initial: _friends, doneLabel: 'Save');
    if (picked == null) return;
    final before = {for (final f in _friends) f.id};
    final after = {for (final p in picked) p.id};
    for (final id in after.difference(before)) {
      await _toggle(id);
    }
    for (final id in before.difference(after)) {
      await _toggle(id);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const InsyncPageTitle('Close friends'),
        actions: [
          IconButton(
              tooltip: 'Add people',
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_rounded))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                      'Only these people see stories and notes you share to Close friends. Nobody is told when you add or remove them.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                ),
                if (_friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Add close friends'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: const Color(0xFF06210F)),
                      ),
                    ),
                  ),
                for (final f in _friends)
                  ListTile(
                    leading: Avatar(
                        src: f.avatarUrl, name: f.name, size: AvatarSize.sm),
                    title: Text(f.name,
                        style: const TextStyle(color: AppColors.text)),
                    subtitle: f.username == null
                        ? null
                        : Text('@${f.username}',
                            style: const TextStyle(
                                color: AppColors.textFaint, fontSize: 12)),
                    trailing: TextButton(
                      onPressed: () async {
                        await _toggle(f.id);
                        _load();
                      },
                      child: const Text('Remove',
                          style: TextStyle(color: AppColors.textDim)),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Archive — posts you've hidden from your profile. Only you see these;
/// open one and use ⋯ to show it on your profile again.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = context.read<AuthProvider>().user?.id;
    if (me == null) return;
    try {
      final data = await ApiClient.get('/feed/user/$me?kind=archived') as List;
      if (!mounted) return;
      setState(() {
        _posts = data
            .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unarchive(Post p) async {
    try {
      await ApiClient.patch('/feed/${p.id}/options', body: {'archived': false});
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Back on your profile')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Archive')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                      'Only you can see archived posts. Long-press one to show it on your profile again.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                ),
                Expanded(
                  child: _posts.isEmpty
                      ? const Center(
                          child: Text('Nothing archived',
                              style: TextStyle(color: AppColors.textFaint)))
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2),
                          itemCount: _posts.length,
                          itemBuilder: (context, i) => GestureDetector(
                            onLongPress: () => _unarchive(_posts[i]),
                            child: ProfilePostGrid(
                                    posts: [_posts[i]], emptyText: '')
                                .tile(context, _posts[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
