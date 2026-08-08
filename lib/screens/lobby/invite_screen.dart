import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

/// Simplified from the web app's 5-tab InviteScreen (Friends/Followers/
/// Following/Search/Recently Joined) into one deduped, multi-select list —
/// same POST /rooms/:id/invite endpoint underneath.
class InviteScreen extends StatefulWidget {
  final String roomId;
  const InviteScreen({super.key, required this.roomId});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _people = [];
  final Set<String> _selected = {};
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiClient.get('/friends').catchError((_) => []),
      ApiClient.get('/social/followers').catchError((_) => []),
      ApiClient.get('/social/following').catchError((_) => []),
    ]);
    if (!mounted) return;
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final list in results) {
      for (final raw in (list as List? ?? [])) {
        final p = Map<String, dynamic>.from(raw as Map);
        final id = (p['id'] ?? p['userId']) as String?;
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        merged.add(p);
      }
    }
    setState(() {
      _people = merged;
      _loading = false;
    });
  }

  Future<void> _invite() async {
    if (_selected.isEmpty) return;
    setState(() => _inviting = true);
    try {
      await ApiClient.post('/rooms/${widget.roomId}/invite', body: {'userIds': _selected.toList()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invites sent')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send invites')));
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Invite')),
      body: _loading
          ? const Center(child: Spinner())
          : _people.isEmpty
              ? const Center(child: Text('No friends or followers yet.', style: TextStyle(color: AppColors.textFaint)))
              : ListView.builder(
                  itemCount: _people.length,
                  itemBuilder: (context, i) {
                    final p = _people[i];
                    final id = (p['id'] ?? p['userId']) as String;
                    final selected = _selected.contains(id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      }),
                      secondary: Avatar(src: p['avatarUrl'] as String?, name: p['name'] as String?, size: AvatarSize.sm),
                      title: Text(p['name'] as String? ?? '', style: const TextStyle(color: AppColors.text)),
                      activeColor: AppColors.primary,
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (_selected.isEmpty || _inviting) ? null : _invite,
            child: Text(_inviting ? 'Sending…' : 'Invite (${_selected.length})'),
          ),
        ),
      ),
    );
  }
}
