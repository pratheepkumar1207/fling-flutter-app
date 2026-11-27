import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import 'community_home_screen.dart';

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Widget _radio<T>(
        {required T value,
        required T group,
        required String title,
        required String sub,
        required ValueChanged<T> onTap}) =>
    InkWell(
      onTap: () => onTap(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(
              value == group
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: value == group ? AppColors.lilac : AppColors.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sub,
                  style:
                      const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );

/// A new group that starts inside a community (admins).
class CommunityGroupCreateScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  const CommunityGroupCreateScreen(
      {super.key, required this.communityId, required this.communityName});

  @override
  State<CommunityGroupCreateScreen> createState() =>
      _CommunityGroupCreateScreenState();
}

class _CommunityGroupCreateScreenState
    extends State<CommunityGroupCreateScreen> {
  final _name = TextEditingController();
  final _about = TextEditingController();
  String _mode = 'open';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return _toast(context, 'Give the group a name');
    setState(() => _busy = true);
    try {
      await ApiClient.post('/communities/${widget.communityId}/groups', body: {
        'name': _name.text.trim(),
        'description': _about.text.trim(),
        'joinMode': _mode,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('New group')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('In ${widget.communityName}',
            style: const TextStyle(color: AppColors.lilac, fontSize: 13)),
        const SizedBox(height: 10),
        TextField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(hintText: 'Group name')),
        TextField(
            controller: _about,
            maxLength: 300,
            decoration: const InputDecoration(
                hintText: 'What’s this group about? (optional)')),
        const SizedBox(height: 8),
        const Text('WHO CAN JOIN',
            style: TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        _radio(
            value: 'open',
            group: _mode,
            title: 'Any community member',
            sub: 'Tap Join and they’re in',
            onTap: (v) => setState(() => _mode = v)),
        _radio(
            value: 'ask',
            group: _mode,
            title: 'Ask to join',
            sub: 'Group admins approve',
            onTap: (v) => setState(() => _mode = v)),
        _radio(
            value: 'invite',
            group: _mode,
            title: 'Invite only',
            sub: 'Hidden from the group list; add people from inside',
            onTap: (v) => setState(() => _mode = v)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : _create,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_busy ? 'Creating…' : 'Create group'),
          ),
        ),
      ),
    );
  }
}

/// Bring groups you own into the community (admins).
class CommunityAddGroupsScreen extends StatefulWidget {
  final String communityId;
  const CommunityAddGroupsScreen({super.key, required this.communityId});

  @override
  State<CommunityAddGroupsScreen> createState() =>
      _CommunityAddGroupsScreenState();
}

class _CommunityAddGroupsScreenState extends State<CommunityAddGroupsScreen> {
  List<Map<String, dynamic>>? _groups;
  List<Map<String, dynamic>> _elsewhere = const [];
  final _picked = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.get(
              '/communities/${widget.communityId}/addable-groups')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _groups = (r['groups'] as List).cast<Map<String, dynamic>>();
        _elsewhere = (r['elsewhere'] as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (mounted) setState(() => _groups = const []);
    }
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await ApiClient.post('/communities/${widget.communityId}/groups/add',
          body: {'groupIds': _picked.toList()});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Add groups')),
      body: groups == null
          ? const Center(child: Spinner())
          : ListView(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Groups you’re the admin of',
                    style: TextStyle(color: AppColors.textFaint)),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('You don’t own any groups that aren’t in a community.',
                      style: TextStyle(color: AppColors.textDim)),
                ),
              for (final g in groups)
                CheckboxListTile(
                  value: _picked.contains(g['id']),
                  onChanged: (v) => setState(() => v == true
                      ? _picked.add(g['id'] as String)
                      : _picked.remove(g['id'])),
                  title: Text(g['name'] as String? ?? ''),
                  subtitle: Text('${g['memberCount']} members'),
                ),
              for (final g in _elsewhere)
                ListTile(
                  enabled: false,
                  title: Text(g['name'] as String? ?? ''),
                  subtitle: const Text('Already in another community'),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Their members are told the group joined this community, '
                    'and they see its Announcements too.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 13)),
              ),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy || _picked.isEmpty ? null : _add,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_picked.isEmpty
                ? 'Pick groups'
                : 'Add ${_picked.length} group${_picked.length == 1 ? '' : 's'}'),
          ),
        ),
      ),
    );
  }
}

/// Ask-to-join requests for the community and its groups (admins).
class CommunityRequestsScreen extends StatefulWidget {
  final String communityId;
  const CommunityRequestsScreen({super.key, required this.communityId});

  @override
  State<CommunityRequestsScreen> createState() =>
      _CommunityRequestsScreenState();
}

class _CommunityRequestsScreenState extends State<CommunityRequestsScreen> {
  List<Map<String, dynamic>>? _rows;
  String _tab = 'community';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.get('/communities/${widget.communityId}/requests');
      if (mounted) setState(() => _rows = (r as List).cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (mounted) {
        _toast(context, e.message);
        setState(() => _rows = const []);
      }
    }
  }

  Future<void> _answer(List<Map<String, dynamic>> rows, bool approve) async {
    for (final r in rows) {
      try {
        await ApiClient.post('/communities/requests/${r['id']}',
            body: {'approve': approve});
      } catch (_) {}
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows;
    final shown = all?.where((r) => r['kind'] == _tab).toList() ?? const [];
    int count(String k) => all?.where((r) => r['kind'] == k).length ?? 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Requests')),
      body: all == null
          ? const Center(child: Spinner())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  ChoiceChip(
                      label: Text('Community · ${count('community')}'),
                      selected: _tab == 'community',
                      onSelected: (_) => setState(() => _tab = 'community')),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: Text('Groups · ${count('group')}'),
                      selected: _tab == 'group',
                      onSelected: (_) => setState(() => _tab = 'group')),
                ]),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text('No requests right now.',
                            style: TextStyle(color: AppColors.textFaint)))
                    : ListView(children: [
                        for (final r in shown)
                          ListTile(
                            leading: Avatar(
                                src: r['avatarUrl'] as String?,
                                name: r['name'] as String?,
                                size: AvatarSize.sm),
                            title: Text(r['name'] as String? ?? ''),
                            subtitle: r['groupName'] != null
                                ? Text('Wants to join ${r['groupName']}')
                                : null,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Decline',
                                onPressed: () => _answer([r], false),
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textFaint),
                              ),
                              FilledButton(
                                onPressed: () => _answer([r], true),
                                style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                child: const Text('Approve'),
                              ),
                            ]),
                          ),
                      ]),
              ),
            ]),
      bottomNavigationBar: shown.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => _answer(shown, false),
                        child: const Text('Decline all')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                        onPressed: () => _answer(shown, true),
                        child: const Text('Approve all')),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

/// Community info: invite link, members, who can join, rules, leave.
class CommunityInfoScreen extends StatefulWidget {
  final String communityId;
  const CommunityInfoScreen({super.key, required this.communityId});

  @override
  State<CommunityInfoScreen> createState() => _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends State<CommunityInfoScreen> {
  Map<String, dynamic>? _c;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/communities/${widget.communityId}/home')
          as Map<String, dynamic>;
      if (mounted) setState(() => _c = Map<String, dynamic>.from(d['community'] as Map));
    } catch (_) {}
  }

  bool get _isAdmin => _c?['isAdmin'] == true;

  Future<void> _invite() async {
    try {
      final r = await ApiClient.get('/communities/${widget.communityId}/invite')
          as Map<String, dynamic>;
      final code = r['code'];
      await Share.share('Join ${_c?['name']} on InSync. Open Chat → '
          'Communities → Find communities → “Have an invite code?” and enter: $code');
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Future<void> _resetInvite() async {
    try {
      await ApiClient.post('/communities/${widget.communityId}/invite/reset');
      if (mounted) _toast(context, 'Invite code reset. Old codes no longer work.');
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Future<void> _edit() async {
    final c = _c!;
    final name = TextEditingController(text: c['name'] as String? ?? '');
    final about = TextEditingController(text: c['description'] as String? ?? '');
    final rules = TextEditingController(text: c['rules'] as String? ?? '');
    var mode = c['joinMode'] as String? ?? 'public';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000000),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Edit community',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                TextField(controller: name, maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: about, maxLength: 500, maxLines: 3, minLines: 1,
                    decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: rules, maxLength: 1000, maxLines: 4, minLines: 1,
                    decoration: const InputDecoration(labelText: 'Rules')),
                _radio(value: 'public', group: mode, title: 'Public',
                    sub: 'Anyone can find and join', onTap: (v) => setSheet(() => mode = v)),
                _radio(value: 'ask', group: mode, title: 'Ask to join',
                    sub: 'Admins approve', onTap: (v) => setSheet(() => mode = v)),
                _radio(value: 'invite', group: mode, title: 'Invite only',
                    sub: 'Only with the invite code; not listed',
                    onTap: (v) => setSheet(() => mode = v)),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: () => Navigator.of(sheet).pop(true),
                    child: const Text('Save')),
              ]),
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ApiClient.patch('/communities/${widget.communityId}', body: {
        'name': name.text.trim(),
        'description': about.text.trim(),
        'rules': rules.text.trim(),
        'joinMode': mode,
      });
      _load();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Leave this community?'),
        content: const Text('You’ll also leave all of its groups.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.post('/communities/${widget.communityId}/leave');
      if (!mounted) return;
      Navigator.of(context)
        ..pop()
        ..pop();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    Widget item(IconData icon, String title, String? sub, VoidCallback onTap,
            {Color? color}) =>
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: color ?? AppColors.lilac),
          title: Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          subtitle: sub == null ? null : Text(sub),
        );
    final mode = switch (c?['joinMode']) {
      'ask' => 'Ask to join',
      'invite' => 'Invite only',
      _ => 'Public',
    };
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Community info'), actions: [
        if (_isAdmin)
          IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit_rounded)),
      ]),
      body: c == null
          ? const Center(child: Spinner())
          : ListView(children: [
              const SizedBox(height: 8),
              Center(
                  child: CommunityAvatar(
                      name: c['name'] as String? ?? '',
                      url: c['avatarUrl'] as String?,
                      size: 72)),
              const SizedBox(height: 8),
              Center(
                child: Text(c['name'] as String? ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Center(
                child: Text(
                    '$mode · ${c['memberCount']} members · ${c['groupCount']} groups',
                    style: const TextStyle(color: AppColors.textDim)),
              ),
              if ((c['description'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(c['description'] as String,
                      style: const TextStyle(color: AppColors.textDim)),
                ),
              const SizedBox(height: 8),
              item(Icons.link_rounded, 'Share invite', 'Send the invite code', _invite),
              if (_isAdmin)
                item(Icons.refresh_rounded, 'Reset invite code',
                    'Old codes stop working', _resetInvite),
              item(Icons.group_rounded, 'Members and admins', null, () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CommunityMembersScreen(
                        communityId: widget.communityId,
                        myRole: c['myRole'] as String?)));
              }),
              if (_isAdmin)
                item(Icons.how_to_reg_rounded, 'Join requests',
                    '${c['pendingRequests'] ?? 0} waiting', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          CommunityRequestsScreen(communityId: widget.communityId)));
                }),
              if ((c['rules'] as String?)?.isNotEmpty == true)
                ListTile(
                  leading: const Icon(Icons.rule_rounded, color: AppColors.lilac),
                  title: const Text('Rules',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(c['rules'] as String),
                ),
              if (c['myRole'] != 'owner')
                item(Icons.logout_rounded, 'Leave community', null, _leave,
                    color: AppColors.danger),
            ]),
    );
  }
}

/// Everyone in the community; the owner can make admins, admins can remove.
class CommunityMembersScreen extends StatefulWidget {
  final String communityId;
  final String? myRole;
  const CommunityMembersScreen(
      {super.key, required this.communityId, required this.myRole});

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  List<Map<String, dynamic>>? _people;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.get(
          '/communities/${widget.communityId}/people-list?q=${Uri.encodeQueryComponent(_q)}');
      if (mounted) setState(() => _people = (r as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _people = const []);
    }
  }

  Future<void> _act(Map<String, dynamic> p) async {
    final owner = widget.myRole == 'owner';
    final admin = owner || widget.myRole == 'moderator';
    final isAdmin = p['role'] == 'moderator';
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF000000),
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (owner)
            ListTile(
                title: Text(isAdmin ? 'Remove as admin' : 'Make admin'),
                onTap: () => Navigator.of(s).pop('admin')),
          if (admin && (owner || !isAdmin))
            ListTile(
                title: const Text('Remove from community',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.of(s).pop('remove')),
        ]),
      ),
    );
    try {
      if (choice == 'admin') {
        await ApiClient.post('/communities/${widget.communityId}/admins/${p['id']}',
            body: {'admin': !isAdmin});
      } else if (choice == 'remove') {
        await ApiClient.delete('/communities/${widget.communityId}/members/${p['id']}');
      } else {
        return;
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user?.id;
    final canManage = widget.myRole == 'owner' || widget.myRole == 'moderator';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Members')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) {
              _q = v.trim();
              _load();
            },
            decoration: const InputDecoration(
                hintText: 'Search members', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        Expanded(
          child: _people == null
              ? const Center(child: Spinner())
              : ListView(children: [
                  for (final p in _people!)
                    ListTile(
                      onTap: canManage && p['id'] != me && p['role'] != 'owner'
                          ? () => _act(p)
                          : null,
                      leading: Avatar(
                          src: p['avatarUrl'] as String?,
                          name: p['name'] as String?,
                          size: AvatarSize.sm),
                      title: Text(p['name'] as String? ?? ''),
                      trailing: p['role'] == 'member'
                          ? null
                          : Text(p['role'] == 'owner' ? 'Owner' : 'Admin',
                              style: const TextStyle(color: AppColors.lilac)),
                    ),
                ]),
        ),
      ]),
    );
  }
}
