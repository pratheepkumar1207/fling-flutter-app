import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../communities/community_detail_screen.dart';
import '../profile/creator_profile_screen.dart';

const _kRecentSearchesKey = 'recent_searches';
const _kMaxRecentSearches = 8;

/// Mirrors GET /search?q=&type=all — people + communities, matching
/// SearchDark.dc.html. Recent searches are stored locally (SharedPreferences,
/// same pattern as OnboardingScreen's seen-flag) since there's no backend
/// table for search history — this is purely a per-device convenience, not
/// something that needs to sync across devices.
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
  List<Map<String, dynamic>> _communities = [];
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _recent = prefs.getStringList(_kRecentSearchesKey) ?? []);
  }

  Future<void> _saveRecent(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [trimmed, ..._recent.where((r) => r.toLowerCase() != trimmed.toLowerCase())].take(_kMaxRecentSearches).toList();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recent = updated);
  }

  Future<void> _removeRecent(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = _recent.where((r) => r != q).toList();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recent = updated);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  void _runSearch(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _search(q);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _users = [];
        _communities = [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/search?q=${Uri.encodeQueryComponent(q)}&type=all') as Map;
      final users = data['users'] as List? ?? [];
      final communities = data['communities'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _users = users.cast<Map<String, dynamic>>();
        _communities = communities.cast<Map<String, dynamic>>();
      });
      if (users.isNotEmpty || communities.isNotEmpty) _saveRecent(q);
    } catch (_) {
      if (mounted) {
        setState(() {
          _users = [];
          _communities = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingResults = _controller.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(hintText: 'Search people, communities…', border: InputBorder.none),
        ),
      ),
      body: _loading
          ? const Center(child: Spinner())
          : !showingResults
              ? _recentSearchesView()
              : (_users.isEmpty && _communities.isEmpty)
                  ? const Center(child: Text('No results found', style: TextStyle(color: AppColors.textFaint)))
                  : ListView(
                      children: [
                        if (_users.isNotEmpty) ...[
                          _sectionLabel('PEOPLE'),
                          ..._users.map(_userRow),
                        ],
                        if (_communities.isNotEmpty) ...[
                          _sectionLabel('COMMUNITIES'),
                          ..._communities.map(_communityRow),
                        ],
                      ],
                    ),
    );
  }

  Widget _recentSearchesView() {
    if (_recent.isEmpty) {
      return const Center(child: Text('Search by name, @username, or community', style: TextStyle(color: AppColors.textFaint)));
    }
    return ListView(
      children: [
        _sectionLabel('RECENT SEARCHES'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent.map((q) {
              return GestureDetector(
                onTap: () => _runSearch(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(q, style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeRecent(q),
                        child: const Icon(Icons.close_rounded, size: 12, color: AppColors.textFaint),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(text, style: const TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );

  Widget _userRow(Map<String, dynamic> u) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: u['id'] as String))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
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
          ]),
        ),
      );

  Widget _communityRow(Map<String, dynamic> c) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: c['id'] as String, name: c['name'] as String?))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: AppGradients.brand)),
              alignment: Alignment.center,
              child: const Text('🏘️', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text('${c['memberCount'] ?? 0} members', style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                ],
              ),
            ),
          ]),
        ),
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
