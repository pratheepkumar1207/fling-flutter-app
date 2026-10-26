import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../models/blend.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/people_picker_sheet.dart';

const _maxMembers = 8;

/// Blend settings: the mix of whose likes make up the feed, the sync and
/// mic options (the creator changes them; everyone else sees them), the
/// people in it, reels two or more of you liked, and Leave Blend.
/// Pops with a reel id to jump to it, or 'left' after leaving.
class BlendSettingsScreen extends StatefulWidget {
  final Blend blend;
  final Map<String, int> mix;
  final List<Post> shared;
  const BlendSettingsScreen(
      {super.key,
      required this.blend,
      required this.mix,
      required this.shared});

  @override
  State<BlendSettingsScreen> createState() => _BlendSettingsScreenState();
}

class _BlendSettingsScreenState extends State<BlendSettingsScreen> {
  late Blend _blend = widget.blend;
  bool _saving = false;

  String? get _myId => context.read<AuthProvider>().user?.id;

  Future<void> _patch(Map<String, dynamic> body) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = await ApiClient.patch('/blends/${_blend.id}', body: body);
      if (mounted) {
        setState(() => _blend = Blend.fromJson(data as Map<String, dynamic>));
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _blend.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Name this Blend'),
        content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Movie gang')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return;
    await _patch({'name': name.isEmpty ? null : name});
  }

  Future<void> _chooseDriver() async {
    final creatorName = _blend.creator?.firstName ?? 'the creator';
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (value, label) in [
            ('everyone', 'Everyone'),
            ('creator', _blend.isCreator ? 'Only you' : 'Only $creatorName'),
          ])
            ListTile(
              title: Text(label, style: const TextStyle(color: AppColors.text)),
              trailing: _blend.whoCanSwipe == value
                  ? const InIcon(InIcons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.of(sheet).pop(value),
            ),
        ]),
      ),
    );
    if (choice != null && choice != _blend.whoCanSwipe) {
      await _patch({'whoCanSwipe': choice});
    }
  }

  Future<void> _addPeople() async {
    final picked = await showPeoplePicker(context,
        title: 'Add people to this Blend', doneLabel: 'Add');
    if (picked == null || picked.isEmpty) return;
    final existing = _blend.members.map((m) => m.id).toSet();
    final ids =
        picked.map((p) => p.id).where((id) => !existing.contains(id)).toList();
    if (ids.isEmpty) return;
    if (existing.length + ids.length > _maxMembers) {
      _snack('A Blend can have up to $_maxMembers people');
      return;
    }
    try {
      final data = await ApiClient.post('/blends/${_blend.id}/members',
          body: {'memberIds': ids});
      if (mounted) {
        setState(() => _blend = Blend.fromJson(data as Map<String, dynamic>));
      }
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _leave() async {
    final ends = _blend.members.length <= 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave this Blend?'),
        content: Text(ends
            ? 'This ends the Blend for both of you.'
            : 'Your likes stop showing in it. The others can keep watching.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.post('/blends/${_blend.id}/leave');
      if (mounted) Navigator.of(context).pop('left');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Widget _mixCard() {
    final total = widget.mix.values.fold<int>(0, (a, b) => a + b);
    final members = _blend.members;
    String share(String id) =>
        total == 0 ? '0%' : '${((widget.mix[id] ?? 0) * 100 / total).round()}%';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mix of this feed',
              style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? Container(color: AppColors.border)
                  : Row(children: [
                      for (final m in members)
                        if ((widget.mix[m.id] ?? 0) > 0)
                          Expanded(
                              flex: widget.mix[m.id]!,
                              child: Container(
                                  color: blendColorFor(_blend, m.id))),
                    ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final m in members)
                // Text.rich so a long name wraps instead of running off.
                Text.rich(
                  TextSpan(children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                              color: blendColorFor(_blend, m.id),
                              shape: BoxShape.circle)),
                    ),
                    TextSpan(
                        text:
                            '${m.id == _myId ? 'Your' : '${m.firstName}\'s'} likes ${share(m.id)}'),
                  ]),
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 11.5),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = _blend.isCreator && !_saving;
    final creatorName = _blend.creator?.firstName ?? 'the creator';
    final ends = _blend.members.length <= 2;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Blend with ${_blend.title(_myId)}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _mixCard(),
          const SizedBox(height: 8),
          if (!_blend.isCreator)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Only $creatorName can change these settings.',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 12)),
            ),
          if (_blend.isGroup)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Name', style: TextStyle(color: AppColors.text)),
              subtitle: Text(_blend.name ?? 'No name yet',
                  style: const TextStyle(color: AppColors.textFaint)),
              trailing: editable
                  ? const InIcon(InIcons.tune, color: AppColors.textDim)
                  : null,
              onTap: editable ? _rename : null,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
                ends ? 'Swipe moves both phones' : 'Swipe moves everyone',
                style: const TextStyle(color: AppColors.text)),
            subtitle: const Text('Off: everyone watches at their own pace',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            value: _blend.swipeSync,
            onChanged: editable ? (v) => _patch({'swipeSync': v}) : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: _blend.swipeSync,
            title: const Text('Who can swipe',
                style: TextStyle(color: AppColors.text)),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                  _blend.whoCanSwipe == 'creator'
                      ? (_blend.isCreator ? 'Only you' : 'Only $creatorName')
                      : (ends ? 'Both' : 'Everyone'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDim)),
            ),
            onTap: editable && _blend.swipeSync ? _chooseDriver : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mic during watch',
                style: TextStyle(color: AppColors.text)),
            value: _blend.micEnabled,
            onChanged: editable ? (v) => _patch({'micEnabled': v}) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show reel owner tag',
                style: TextStyle(color: AppColors.text)),
            subtitle: const Text('“From Bala’s likes” on each reel',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            value: _blend.showOwnerTag,
            onChanged: editable ? (v) => _patch({'showOwnerTag': v}) : null,
          ),
          const Divider(color: AppColors.border, height: 24),
          Row(
            children: [
              Expanded(
                child: Text('People · ${_blend.members.length}',
                    style: const TextStyle(
                        color: AppColors.text, fontWeight: FontWeight.w600)),
              ),
              if (_blend.isCreator && _blend.members.length < _maxMembers)
                TextButton.icon(
                  onPressed: _addPeople,
                  icon: const InIcon(InIcons.useradd, size: 18),
                  label: const Text('Add people'),
                ),
            ],
          ),
          for (final m in _blend.members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Avatar(src: m.avatarUrl, name: m.name, size: AvatarSize.sm),
              title: Text(m.id == _myId ? '${m.name} (you)' : m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text)),
              trailing: m.id == _blend.createdBy
                  ? const Text('Started it',
                      style:
                          TextStyle(color: AppColors.textFaint, fontSize: 12))
                  : null,
            ),
          const Divider(color: AppColors.border, height: 24),
          Text(
              '${ends ? 'Reels you both liked' : 'Reels 2 or more of you liked'} · ${widget.shared.length}',
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (widget.shared.isEmpty)
            const Text('None yet. Like the same reel and it shows up here.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12.5))
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 9 / 14,
              children: [
                for (final p in widget.shared)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(p.id),
                    child: Container(
                      decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const InIcon(InIcons.play,
                              filled: true, color: AppColors.textDim, size: 30),
                          const SizedBox(height: 6),
                          Text(p.author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textDim, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _leave,
              child: const Text('Leave Blend',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
