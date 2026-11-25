import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/chat_media.dart';
import 'community_home_screen.dart';

/// New community in two steps: 1) picture, name, description, rules, topic
/// and who can join; 2) bring in groups you own (optional). An
/// Announcements group is made for it; new groups can be created inside
/// from its home afterwards.
class NewCommunityScreen extends StatefulWidget {
  const NewCommunityScreen({super.key});

  @override
  State<NewCommunityScreen> createState() => _NewCommunityScreenState();
}

class _NewCommunityScreenState extends State<NewCommunityScreen> {
  static const _topics = ['Movies', 'Games', 'Music', 'College', 'Sports', 'Books', 'Tech', 'Friends', 'Other'];
  int _step = 1;
  final _name = TextEditingController();
  final _about = TextEditingController();
  final _rules = TextEditingController();
  String _mode = 'public';
  String? _topic;
  String? _photo;
  List<Map<String, dynamic>>? _myGroups;
  final _picked = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the community a name');
      return;
    }
    setState(() {
      _step = 2;
      _error = null;
    });
    final me = context.read<AuthProvider>().user?.id;
    try {
      final groups = (await ApiClient.get('/groups') as List)
          .cast<Map<String, dynamic>>()
          .where((g) =>
              g['ownerId'] == me &&
              g['communityId'] == null &&
              g['isAnnouncements'] != true)
          .toList();
      if (mounted) setState(() => _myGroups = groups);
    } catch (_) {
      if (mounted) setState(() => _myGroups = const []);
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final c = await ApiClient.post('/communities', body: {
        'name': _name.text.trim(),
        'description': _about.text.trim(),
        'rules': _rules.text.trim(),
        'joinMode': _mode,
        if (_topic != null) 'topic': _topic,
        if (_photo != null) 'avatarUrl': _photo,
        'groupIds': _picked.toList(),
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => CommunityHomeScreen(communityId: c['id'] as String)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _mode1(String value, String title, String sub) => InkWell(
        onTap: () => setState(() => _mode = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(
                _mode == value
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: _mode == value ? AppColors.lilac : AppColors.textFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(sub,
                    style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
      );

  Widget _stepOne() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: Semantics(
          button: true,
          label: 'Add a picture',
          child: GestureDetector(
            onTap: () async {
              final uri = await pickChatPhoto();
              if (uri != null && mounted) setState(() => _photo = uri);
            },
            child: Container(
              width: 76,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22)),
              child: _photo != null
                  ? AppImage(source: _photo, fit: BoxFit.cover)
                  : const Icon(Icons.add_a_photo_rounded, color: AppColors.textFaint),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _name,
        maxLength: 60,
        onChanged: (_) => setState(() => _error = null),
        decoration: const InputDecoration(labelText: 'Community name'),
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
      TextField(
          controller: _about,
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Description')),
      TextField(
          controller: _rules,
          maxLength: 1000,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Rules (optional)')),
      const SizedBox(height: 6),
      const Text('TOPIC',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in _topics)
          ChoiceChip(
              label: Text(t),
              selected: _topic == t,
              onSelected: (on) => setState(() => _topic = on ? t : null)),
      ]),
      const SizedBox(height: 12),
      const Text('WHO CAN JOIN',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700)),
      _mode1('public', 'Public', 'Anyone can find and join'),
      _mode1('ask', 'Ask to join', 'Admins approve each person'),
      _mode1('invite', 'Invite only', 'Only with your invite code; never listed'),
    ]);
  }

  Widget _stepTwo() {
    final groups = _myGroups;
    return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Text('ADD GROUPS YOU MANAGE',
            style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      if (groups == null)
        const Padding(
            padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (groups.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('You don’t own any groups yet. That’s fine.',
              style: TextStyle(color: AppColors.textDim)),
        ),
      for (final g in groups ?? const <Map<String, dynamic>>[])
        CheckboxListTile(
          value: _picked.contains(g['id']),
          onChanged: (v) => setState(() =>
              v == true ? _picked.add(g['id'] as String) : _picked.remove(g['id'])),
          title: Text(g['name'] as String? ?? ''),
          subtitle: Text('${g['memberCount'] ?? 0} members'),
        ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
            'An Announcements group is made for you. You can create new groups '
            'inside the community from its home.',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(_step == 1 ? 'New community' : 'Add groups'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('$_step of 2',
                    style: const TextStyle(color: AppColors.textFaint)),
              ),
            ),
          ],
        ),
        body: _step == 1 ? _stepOne() : _stepTwo(),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: _busy ? null : (_step == 1 ? _next : _create),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_step == 1
                  ? 'Next'
                  : _busy
                      ? 'Creating…'
                      : _picked.isEmpty
                          ? 'Create community'
                          : 'Create community · ${_picked.length} group${_picked.length == 1 ? '' : 's'}'),
            ),
          ),
        ),
      ),
    );
  }
}
