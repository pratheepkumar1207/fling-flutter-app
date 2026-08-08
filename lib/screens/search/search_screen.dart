import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../profile/creator_profile_screen.dart';

/// Mirrors GET /search?q=&type=users — the web app's SearchPage also
/// surfaces communities/rooms/events/hashtags; this focuses on the people
/// search first since that's the most-used case for a social/dating app.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<Map<String, dynamic>> _users = [];

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _users = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/search?q=${Uri.encodeQueryComponent(q)}&type=users');
      final users = (data as Map)['users'] as List? ?? [];
      if (!mounted) return;
      setState(() => _users = users.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _users = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(hintText: 'Search people…', border: InputBorder.none),
        ),
      ),
      body: _loading
          ? const Center(child: Spinner())
          : _users.isEmpty
              ? const Center(child: Text('Search by name or @username', style: TextStyle(color: AppColors.textFaint)))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: Avatar(src: u['avatarUrl'] as String?, name: u['name'] as String?, size: AvatarSize.sm),
                      title: Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text)),
                      subtitle: u['username'] != null ? Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint)) : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: u['id'] as String)),
                      ),
                    );
                  },
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
