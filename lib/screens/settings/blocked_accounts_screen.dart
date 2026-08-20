import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

/// GET /social/blocklist + POST /social/unblock/:userId — the app could
/// block someone (from CreatorProfileScreen) but had no way to see or undo
/// it afterward. This is the missing other half of that flow.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _blocked = [];
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/social/blocklist');
      if (!mounted) return;
      setState(() {
        _blocked = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String userId) async {
    setState(() => _unblocking.add(userId));
    try {
      await ApiClient.post('/social/unblock/$userId');
      if (!mounted) return;
      setState(() => _blocked.removeWhere((u) => u['id'] == userId));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to unblock')));
    } finally {
      if (mounted) setState(() => _unblocking.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: _loading
          ? const Center(child: Spinner())
          : _blocked.isEmpty
              ? const Center(child: Text("You haven't blocked anyone.", style: TextStyle(color: AppColors.textFaint)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _blocked.length,
                  itemBuilder: (context, i) {
                    final u = _blocked[i];
                    final id = u['id'] as String;
                    final unblocking = _unblocking.contains(id);
                    return ListTile(
                      leading: Avatar(name: u['name'] as String?, size: AvatarSize.sm),
                      title: Text(u['name'] as String? ?? 'Unknown', style: const TextStyle(color: AppColors.text)),
                      subtitle: u['username'] != null ? Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)) : null,
                      trailing: OutlinedButton(
                        onPressed: unblocking ? null : () => _unblock(id),
                        child: Text(unblocking ? 'Unblocking…' : 'Unblock'),
                      ),
                    );
                  },
                ),
    );
  }
}
