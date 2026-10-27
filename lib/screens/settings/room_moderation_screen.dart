import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/spinner.dart';

/// Room moderation for every room you host: slow mode, mic approval,
/// friends only, link blocking, keyword filters, co-hosts and bans
/// (GET/PATCH /moderation). Changes save as you make them.
class RoomModerationScreen extends StatefulWidget {
  const RoomModerationScreen({super.key});

  @override
  State<RoomModerationScreen> createState() => _RoomModerationScreenState();
}

class _RoomModerationScreenState extends State<RoomModerationScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/moderation') as Map<String, dynamic>;
      if (mounted) setState(() => _data = d);
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load moderation');
    }
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _save(String key, dynamic value) async {
    final before = _data![key];
    setState(() => _data = {..._data!, key: value});
    try {
      await ApiClient.patch('/moderation', body: {key: value});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _data = {..._data!, key: before});
      _snack(e.message);
    }
  }

  List<String> get _words => (_data!['words'] as List).cast<String>();

  Future<void> _addWord() async {
    final c = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add a word'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
              hintText: 'Messages with this word are blocked'),
          onSubmitted: (v) => Navigator.of(d).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(c.text),
              child: const Text('Add')),
        ],
      ),
    );
    final w = word?.trim().toLowerCase() ?? '';
    if (w.isEmpty || _words.contains(w)) return;
    _save('words', [..._words, w]);
  }

  Future<void> _addCoHost() async {
    List friends = [];
    try {
      friends = await ApiClient.get('/friends') as List;
    } catch (_) {}
    if (!mounted) return;
    final have = {
      for (final c in _data!['coHosts'] as List) (c as Map)['id'] as String
    };
    final pick = await showModalBottomSheet<Map>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: friends.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text('Add friends first — co-hosts are picked from them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim)),
              )
            : ListView(shrinkWrap: true, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Pick a co-host',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                for (final f in friends.cast<Map>())
                  if (!have.contains(f['id']))
                    ListTile(
                      leading: Avatar(
                          name: f['name'] as String?, size: AvatarSize.sm),
                      title: Text(f['name'] as String? ?? ''),
                      onTap: () => Navigator.of(sheet).pop(f),
                    ),
              ]),
      ),
    );
    if (pick == null || !mounted) return;
    final role = await _pickRole(pick['name'] as String? ?? '');
    if (role == null) return;
    await _setRole(pick['id'] as String, role);
  }

  Future<String?> _pickRole(String name) => showDialog<String>(
        context: context,
        builder: (d) => SimpleDialog(
          title: Text('What can ${name.split(' ').first} do?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(d).pop('full'),
              child: const Text('Mute, remove and approve mics'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(d).pop('mics'),
              child: const Text('Approve mics only'),
            ),
          ],
        ),
      );

  Future<void> _setRole(String userId, String role) async {
    try {
      await ApiClient.put('/moderation/cohosts/$userId', body: {'role': role});
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _removeCoHost(Map c) async {
    try {
      await ApiClient.delete('/moderation/cohosts/${c['id']}');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _unban(Map b) async {
    try {
      await ApiClient.delete('/moderation/bans/${b['id']}');
      _load();
      _snack('${b['name']} can join your rooms again');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: InIconButton(InIcons.back,
            tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Room moderation'),
      ),
      body: d == null
          ? Center(
              child: _error == null
                  ? const Spinner()
                  : Text(_error!,
                      style: const TextStyle(color: AppColors.textDim)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                const Text('Applies to every room you host.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                const _Label('CONTROLS'),
                _Card(children: [
                  _Switch('Slow mode', 'One message every 10 seconds',
                      d['slowMode'] == true, (v) => _save('slowMode', v)),
                  _Switch('Mics need host approval', null,
                      d['micApproval'] == true, (v) => _save('micApproval', v)),
                  _Switch('Only friends can join', 'For new rooms you start',
                      d['friendsOnly'] == true, (v) => _save('friendsOnly', v)),
                  _Switch('Block links in chat', null, d['blockLinks'] == true,
                      (v) => _save('blockLinks', v)),
                ]),
                const _Label('KEYWORD FILTERS'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final w in _words)
                    InputChip(
                      label: Text(w),
                      onDeleted: () =>
                          _save('words', [..._words]..remove(w)),
                      deleteButtonTooltipMessage: 'Remove $w',
                    ),
                  ActionChip(
                    avatar: const InIcon(InIcons.plus,
                        size: 16, color: AppColors.lilac),
                    label: const Text('Add word'),
                    onPressed: _addWord,
                  ),
                ]),
                const _Label('CO-HOSTS'),
                _Card(children: [
                  for (final c in (d['coHosts'] as List).cast<Map>())
                    ListTile(
                      leading: Avatar(
                          src: c['avatarUrl'] as String?,
                          name: c['name'] as String?,
                          size: AvatarSize.sm),
                      title: Text(c['name'] as String? ?? ''),
                      subtitle: Text(
                          c['role'] == 'full'
                              ? 'Can mute, remove and approve mics'
                              : 'Can approve mics',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                      onTap: () async {
                        final role = await _pickRole(c['name'] as String? ?? '');
                        if (role != null) _setRole(c['id'] as String, role);
                      },
                      trailing: TextButton(
                          onPressed: () => _removeCoHost(c),
                          child: const Text('Remove')),
                    ),
                  ListTile(
                    leading: const InIcon(InIcons.useradd,
                        size: 20, color: AppColors.lilac),
                    title: const Text('Add co-host'),
                    onTap: _addCoHost,
                  ),
                ]),
                const _Label('BANNED'),
                if ((d['banned'] as List).isEmpty)
                  const Text(
                      'Nobody’s banned. Ban someone from a room’s people list.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 13))
                else
                  _Card(children: [
                    for (final b in (d['banned'] as List).cast<Map>())
                      ListTile(
                        leading: Avatar(
                            src: b['avatarUrl'] as String?,
                            name: b['name'] as String?,
                            size: AvatarSize.sm),
                        title: Text(b['username'] as String? ??
                            b['name'] as String? ??
                            ''),
                        subtitle: const Text('Banned from your rooms',
                            style: TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                        trailing: TextButton(
                            onPressed: () => _unban(b),
                            child: const Text('Unban')),
                      ),
                  ]),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _Switch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch(this.title, this.subtitle, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
      );
}
