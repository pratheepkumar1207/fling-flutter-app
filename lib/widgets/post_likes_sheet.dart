import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../screens/profile/creator_profile_screen.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';
import 'spinner.dart';

void showPostLikesSheet(BuildContext context, {required String postId}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (_) => _PostLikesSheet(postId: postId),
  );
}

class _PostLikesSheet extends StatefulWidget {
  final String postId;
  const _PostLikesSheet({required this.postId});

  @override
  State<_PostLikesSheet> createState() => _PostLikesSheetState();
}

class _PostLikesSheetState extends State<_PostLikesSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _likes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/feed/${widget.postId}/likes');
      if (!mounted) return;
      setState(() {
        _likes = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text('Likes (${_likes.length})', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold))),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : _likes.isEmpty
                    ? const Center(child: Text('No likes yet.', style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _likes.length,
                        itemBuilder: (context, i) {
                          final u = _likes[i];
                          return ListTile(
                            leading: Avatar(src: u['avatarUrl'] as String?, name: u['name'] as String?, size: AvatarSize.sm),
                            title: Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text)),
                            subtitle: u['username'] != null ? Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)) : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: u['id'] as String)));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
