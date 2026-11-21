import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import 'community_home_screen.dart';
import 'new_community_screen.dart';

/// Chat → Communities → Find communities: search, topics, Join or Ask.
/// Invite-only communities never show; they're joined with a code.
class FindCommunitiesScreen extends StatefulWidget {
  const FindCommunitiesScreen({super.key});

  @override
  State<FindCommunitiesScreen> createState() => _FindCommunitiesScreenState();
}

class _FindCommunitiesScreenState extends State<FindCommunitiesScreen> {
  static const _topics = ['Movies', 'Games', 'Music', 'College', 'Sports', 'Books', 'Tech', 'Friends'];
  String _q = '';
  String? _topic;
  List<Map<String, dynamic>>? _rows;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final params = [
      if (_q.isNotEmpty) 'q=${Uri.encodeQueryComponent(_q)}',
      if (_topic != null) 'topic=${Uri.encodeQueryComponent(_topic!)}',
    ].join('&');
    try {
      final r = await ApiClient.get('/communities/find${params.isEmpty ? '' : '?$params'}');
      if (mounted) setState(() => _rows = (r as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _rows = const []);
    }
  }

  Future<void> _join(Map<String, dynamic> c) async {
    try {
      final r = await ApiClient.post('/communities/${c['id']}/join')
          as Map<String, dynamic>;
      if (!mounted) return;
      if (r['requested'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Asked to join. An admin will approve you.')));
        _load();
      } else {
        _open(c);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CommunityHomeScreen(communityId: c['id'] as String)));
    _load();
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Join with an invite code'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Invite code')),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(controller.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    try {
      final r = await ApiClient.post('/communities/join-code/${Uri.encodeComponent(code)}')
          as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              CommunityHomeScreen(communityId: r['communityId'] as String)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Find communities')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: TextField(
            onChanged: (v) {
              _q = v.trim();
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
            decoration: const InputDecoration(
                hintText: 'Search communities',
                prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                    label: const Text('For you'),
                    selected: _topic == null,
                    onSelected: (_) {
                      setState(() => _topic = null);
                      _load();
                    }),
              ),
              for (final t in _topics)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                      label: Text(t),
                      selected: _topic == t,
                      onSelected: (_) {
                        setState(() => _topic = t);
                        _load();
                      }),
                ),
            ],
          ),
        ),
        Expanded(
          child: rows == null
              ? const Center(child: Spinner())
              : ListView(padding: const EdgeInsets.only(bottom: 100), children: [
                  ListTile(
                    onTap: _enterCode,
                    leading: const Icon(Icons.vpn_key_rounded, color: AppColors.lilac),
                    title: const Text('Have an invite code?',
                        style: TextStyle(color: AppColors.lilac)),
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('No communities found.',
                              style: TextStyle(color: AppColors.textFaint))),
                    ),
                  for (final c in rows)
                    ListTile(
                      onTap: () => _open(c),
                      leading: CommunityAvatar(
                          name: c['name'] as String? ?? '',
                          url: c['avatarUrl'] as String?),
                      title: Text(c['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${c['memberCount']} members · ${c['groupCount']} groups · '
                          '${c['joinMode'] == 'ask' ? 'Ask to join' : 'Public'}',
                          style: const TextStyle(fontSize: 12.5)),
                      trailing: c['isJoined'] == true
                          ? const Text('Joined',
                              style: TextStyle(color: Color(0xFF5DCAA5)))
                          : c['requested'] == true
                              ? const Text('Asked',
                                  style: TextStyle(color: AppColors.textFaint))
                              : OutlinedButton(
                                  onPressed: () => _join(c),
                                  style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      shape: const StadiumBorder()),
                                  child: Text(c['joinMode'] == 'ask' ? 'Ask' : 'Join'),
                                ),
                    ),
                ]),
        ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewCommunityScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New community'),
      ),
    );
  }
}
