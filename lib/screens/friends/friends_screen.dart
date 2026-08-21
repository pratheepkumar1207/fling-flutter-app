import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../profile/creator_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String _tab = 'friends';
  bool _loading = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/friends').catchError((_) => []),
      ApiClient.get('/friends/requests').catchError((_) => []),
    ]);
    if (!mounted) return;
    setState(() {
      _friends = ((results[0] as List?) ?? []).cast<Map<String, dynamic>>();
      _requests = ((results[1] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _accept(String id) async {
    try {
      await ApiClient.post('/friends/$id/accept');
      _load();
    } catch (_) {}
  }

  Future<void> _reject(String id) async {
    try {
      await ApiClient.post('/friends/$id/reject');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _tabChip('friends', 'Friends'),
                const SizedBox(width: 8),
                _tabChip('requests', 'Requests${_requests.isNotEmpty ? ' (${_requests.length})' : ''}'),
                const SizedBox(width: 8),
                _tabChip('find', 'Find people'),
              ],
            ),
          ),
          Expanded(
            child: _tab == 'find'
                ? const _FindPeopleTab()
                : _loading
                    ? const Center(child: Spinner())
                    : _tab == 'friends'
                        ? (_friends.isEmpty
                            ? const Center(child: Text('No friends yet', style: TextStyle(color: AppColors.textFaint)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _friends.length,
                                itemBuilder: (context, i) {
                                  final f = _friends[i];
                                  return GestureDetector(
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: f['id'] as String))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                                      child: Row(children: [
                                        Avatar(src: f['avatarUrl'] as String?, name: f['name'] as String?, size: AvatarSize.md),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(f['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5))),
                                      ]),
                                    ),
                                  );
                                },
                              ))
                        : (_requests.isEmpty
                            ? const Center(child: Text('No pending requests', style: TextStyle(color: AppColors.textFaint)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _requests.length,
                                itemBuilder: (context, i) {
                                  final r = _requests[i];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                                    child: Row(
                                      children: [
                                        Avatar(name: r['fromName'] as String?, size: AvatarSize.md),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(r['fromName'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5))),
                                        GestureDetector(
                                          onTap: () => _accept(r['id'] as String),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            decoration: BoxDecoration(gradient: const LinearGradient(colors: AppGradients.brand), borderRadius: BorderRadius.circular(999)),
                                            alignment: Alignment.center,
                                            child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => _reject(r['id'] as String),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                                            child: const Icon(Icons.close_rounded, color: AppColors.textDim, size: 15),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) => ChoiceChip(
        label: Text(label),
        selected: _tab == key,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: _tab == key ? AppColors.primary : AppColors.textDim, fontSize: 12),
        backgroundColor: AppColors.surface,
        onSelected: (_) => setState(() => _tab = key),
      );
}

class _FindPeopleTab extends StatefulWidget {
  const _FindPeopleTab();

  @override
  State<_FindPeopleTab> createState() => _FindPeopleTabState();
}

class _FindPeopleTabState extends State<_FindPeopleTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>>? _results;
  final Set<String> _sentIds = {};

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final data = await ApiClient.get('/users/search?q=${Uri.encodeQueryComponent(q.trim())}');
        if (mounted) setState(() => _results = (data as List).cast<Map<String, dynamic>>());
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  Future<void> _send(String userId) async {
    try {
      await ApiClient.post('/friends/request', body: {'toUserId': userId});
      if (mounted) setState(() => _sentIds.add(userId));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send request')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: 'Search by name or username…'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _results?.length ?? 0,
              itemBuilder: (context, i) {
                final u = _results![i];
                final id = u['id'] as String;
                final sent = _sentIds.contains(id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Avatar(src: u['avatarUrl'] as String?, name: u['name'] as String?, size: AvatarSize.sm),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                            if (u['username'] != null) Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(onPressed: sent ? null : () => _send(id), child: Text(sent ? 'Sent' : 'Add', style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
