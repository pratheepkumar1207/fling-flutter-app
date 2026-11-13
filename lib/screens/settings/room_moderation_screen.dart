import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/room_sheet.dart';
import '../../widgets/spinner.dart';

/// Moderation for every room you host, in the room sheets' black style:
/// slow mode (Off · 5s · 10s · 30s), links in chat (Allow · Hosts only ·
/// Block), blocked words, co-hosts and banned people (GET/PATCH
/// /moderation). Changes save as you make them.
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
                child: Text(
                    'Add friends first — co-hosts are picked from them.',
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

  int get _slowSeconds {
    final d = _data!;
    final n = d['slowSeconds'];
    if (n is num) return n.toInt();
    return d['slowMode'] == true ? 10 : 0;
  }

  String get _linkMode {
    final m = _data!['linkMode'];
    if (m is String) return m;
    return _data!['blockLinks'] == true ? 'hosts' : 'allow';
  }

  Future<void> _setSlow(String v) async {
    final n = int.parse(v);
    final before = Map<String, dynamic>.from(_data!);
    setState(() => _data = {..._data!, 'slowSeconds': n, 'slowMode': n > 0});
    try {
      await ApiClient.patch('/moderation', body: {'slowSeconds': n});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _data = before);
      _snack(e.message);
    }
  }

  Future<void> _setLinks(String v) async {
    final before = Map<String, dynamic>.from(_data!);
    setState(() =>
        _data = {..._data!, 'linkMode': v, 'blockLinks': v != 'allow'});
    try {
      await ApiClient.patch('/moderation', body: {'linkMode': v});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _data = before);
      _snack(e.message);
    }
  }

  // Tap a co-host's face: change what they can do, or remove them.
  Future<void> _coHostOptions(Map c) async {
    final name = (c['name'] as String? ?? '').split(' ').first;
    final pick = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(d).pop('full'),
            child: const Text('Full: mute, remove and approve mics'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(d).pop('mics'),
            child: const Text('Mics: approve mics only'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(d).pop('remove'),
            child: const Text('Remove as co-host',
                style: TextStyle(color: Color(0xFFFF6B75))),
          ),
        ],
      ),
    );
    if (pick == null) return;
    if (pick == 'remove') {
      _removeCoHost(c);
    } else if (pick != c['role']) {
      _setRole(c['id'] as String, pick);
    }
  }

  Future<void> _openBanned() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: kSheetBorder)),
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) {
          final banned = (_data!['banned'] as List).cast<Map>();
          return SafeArea(
            child: banned.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                        'Nobody’s banned. Ban someone from a room’s people list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kSheetDim)),
                  )
                : ListView(shrinkWrap: true, children: [
                    const RoomSheetHandle(),
                    for (final b in banned)
                      ListTile(
                        leading: Avatar(
                            src: b['avatarUrl'] as String?,
                            name: b['name'] as String?,
                            size: AvatarSize.sm),
                        title: Text(
                            b['username'] as String? ??
                                b['name'] as String? ??
                                '',
                            style: const TextStyle(color: Colors.white)),
                        trailing: TextButton(
                            onPressed: () async {
                              await _unban(b);
                              if (sheet.mounted) Navigator.of(sheet).pop();
                            },
                            child: const Text('Unban')),
                      ),
                  ]),
          );
        },
      ),
    );
  }

  Widget _face(
      {required Widget avatar, required String name, String? tag, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            SizedBox(width: 48, height: 48, child: avatar),
            if (tag != null)
              Positioned(
                right: -4,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                      color: kSheetOn,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black)),
                  child: Text(tag,
                      style: const TextStyle(
                          color: Color(0xFFC9BCFF), fontSize: 9.5)),
                ),
              ),
          ]),
          const SizedBox(height: 5),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD8D8DE), fontSize: 11)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: InIconButton(InIcons.back,
            tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Moderation'),
        actions: const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text('All your rooms',
                  style: TextStyle(color: kSheetDim, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: d == null
          ? Center(
              child: _error == null
                  ? const Spinner()
                  : Text(_error!, style: const TextStyle(color: kSheetDim)))
          : DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  const RoomSheetLabel('SLOW MODE'),
                  RoomChoiceRow(
                    options: const [
                      ('0', InIcons.bolt, 'Off'),
                      ('5', InIcons.hourglass, '5s'),
                      ('10', InIcons.hourglass, '10s'),
                      ('30', InIcons.hourglass, '30s'),
                    ],
                    value: '$_slowSeconds',
                    onChanged: _setSlow,
                  ),
                  const RoomSheetLabel('LINKS IN CHAT'),
                  RoomChoiceRow(
                    options: const [
                      ('allow', InIcons.link, 'Allow'),
                      ('hosts', InIcons.crown, 'Hosts only'),
                      ('block', InIcons.block, 'Block'),
                    ],
                    value: _linkMode,
                    onChanged: _setLinks,
                  ),
                  const RoomSheetLabel('BLOCKED WORDS'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _chip(
                          label: 'Add',
                          icon: InIcons.plus,
                          dashed: true,
                          onTap: _addWord),
                      for (final w in _words)
                        _chip(
                            label: w,
                            trailing: InIcons.close,
                            semantic: 'Remove $w',
                            onTap: () =>
                                _save('words', [..._words]..remove(w))),
                    ]),
                  ),
                  const RoomSheetLabel('CO-HOSTS'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _face(
                            avatar: Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFF111111),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF555555))),
                              child: const Center(
                                  child: InIcon(InIcons.plus,
                                      size: 20, color: AppColors.lilac)),
                            ),
                            name: 'Add',
                            onTap: _addCoHost,
                          ),
                          for (final c in (d['coHosts'] as List).cast<Map>())
                            _face(
                              avatar: Avatar(
                                  src: c['avatarUrl'] as String?,
                                  name: c['name'] as String?,
                                  size: AvatarSize.md),
                              name: (c['name'] as String? ?? '').split(' ').first,
                              tag: c['role'] == 'full' ? 'Full' : 'Mics',
                              onTap: () => _coHostOptions(c),
                            ),
                        ]),
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: kSheetBorder)),
                    child: InkWell(
                      customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onTap: _openBanned,
                      child: SizedBox(
                        height: 46,
                        child: Row(children: [
                          const SizedBox(width: 12),
                          const InIcon(InIcons.block,
                              size: 18, color: Color(0xFFFF6B75)),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Banned people')),
                          Text('${(d['banned'] as List).length}',
                              style: const TextStyle(
                                  color: kSheetDim, fontSize: 12)),
                          const SizedBox(width: 4),
                          const InIcon(InIcons.right,
                              size: 16, color: Color(0xFF666666)),
                          const SizedBox(width: 10),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _chip(
      {required String label,
      InIconData? icon,
      InIconData? trailing,
      bool dashed = false,
      String? semantic,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        label: semantic ?? label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: dashed ? AppColors.lilac : kSheetBorder),
            ),
            child: ExcludeSemantics(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  InIcon(icon, size: 14, color: AppColors.lilac),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: dashed ? AppColors.lilac : const Color(0xFFDDDDDD))),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  InIcon(trailing, size: 13, color: kSheetDim),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
