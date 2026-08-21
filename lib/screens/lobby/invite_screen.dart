import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

/// Friends / Recents (people who've joined this room before, via
/// GET /rooms/:id/recent-participants) tabs, plus a tap-to-search field for
/// anyone else — same POST /rooms/:id/invite endpoint underneath regardless
/// of which list a pick came from.
class InviteScreen extends StatefulWidget {
  final String roomId;
  const InviteScreen({super.key, required this.roomId});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  bool _loadingFriends = true;
  bool _loadingRecents = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _recents = [];

  bool _searching = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  final Set<String> _selected = {};
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadRecents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final data = await ApiClient.get('/friends');
      if (!mounted) return;
      setState(() {
        _friends = ((data as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingFriends = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadRecents() async {
    try {
      final data = await ApiClient.get('/rooms/${widget.roomId}/recent-participants');
      if (!mounted) return;
      setState(() {
        _recents = ((data as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingRecents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRecents = false);
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final data = await ApiClient.get('/search?q=${Uri.encodeComponent(query)}&type=users');
        if (!mounted) return;
        final users = (data is Map ? data['users'] as List? : null) ?? [];
        setState(() {
          _searchResults = users.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _searchLoading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _searchResults = [];
        _searchLoading = false;
      }
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

  Widget _personTile(Map<String, dynamic> p) {
    final id = (p['id'] ?? p['userId']) as String;
    final selected = _selected.contains(id);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Row(
          children: [
            Avatar(src: p['avatarUrl'] as String?, name: p['name'] as String?, size: AvatarSize.sm),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  if (p['username'] != null) Text('@${p['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? const LinearGradient(colors: AppGradients.brand) : null,
                border: selected ? null : Border.all(color: AppColors.border, width: 1.5),
              ),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 15) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list({required bool loading, required List<Map<String, dynamic>> people, required String emptyText}) {
    if (loading) return const Center(child: Spinner());
    if (people.isEmpty) return Center(child: Text(emptyText, style: const TextStyle(color: AppColors.textFaint)));
    return ListView.builder(
      itemCount: people.length,
      itemBuilder: (context, i) => _personTile(people[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(hintText: 'Search people…', hintStyle: TextStyle(color: AppColors.textFaint), border: InputBorder.none),
                onChanged: _onSearchChanged,
              )
            : const Text('Invite to room'),
        actions: [
          if (!_searching && _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(child: Text('${_selected.length} selected', style: const TextStyle(color: AppColors.textFaint, fontSize: 13, fontWeight: FontWeight.w700))),
            ),
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search people',
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.close : Icons.search, color: AppColors.textDim),
          ),
        ],
        bottom: _searching
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textDim,
                indicatorColor: AppColors.primary,
                tabs: const [Tab(text: 'Friends'), Tab(text: 'Recents')],
              ),
      ),
      body: _searching
          ? (_searchLoading
              ? const Center(child: Spinner())
              : _searchController.text.trim().isEmpty
                  ? const Center(child: Text('Search by name or username.', style: TextStyle(color: AppColors.textFaint)))
                  : _searchResults.isEmpty
                      ? const Center(child: Text('No one found.', style: TextStyle(color: AppColors.textFaint)))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, i) => _personTile(_searchResults[i]),
                        ))
          : TabBarView(
              controller: _tabController,
              children: [
                _list(loading: _loadingFriends, people: _friends, emptyText: 'No friends yet.'),
                _list(loading: _loadingRecents, people: _recents, emptyText: "No one's joined this room before."),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GestureDetector(
            onTap: (_selected.isEmpty || _inviting) ? null : _invite,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: (_selected.isEmpty || _inviting) ? null : const LinearGradient(colors: AppGradients.brand),
                color: (_selected.isEmpty || _inviting) ? AppColors.surface2 : null,
              ),
              alignment: Alignment.center,
              child: Text(
                _inviting ? 'Sending…' : (_selected.isEmpty ? 'Send invites' : 'Send invites (${_selected.length})'),
                style: TextStyle(color: (_selected.isEmpty || _inviting) ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
