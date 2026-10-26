import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Notes — a short status (or a song) above someone's avatar that lasts
/// 24 hours. NotesRow sits at the top of Messages; NoteBubble shows one
/// person's note on their profile.
class NoteBubble extends StatelessWidget {
  final String? text;
  final String? songTitle;
  final double maxWidth;
  const NoteBubble({super.key, this.text, this.songTitle, this.maxWidth = 110});

  @override
  Widget build(BuildContext context) {
    final label = songTitle != null && songTitle!.isNotEmpty
        ? '♪ $songTitle'
        : (text ?? '');
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.text, fontSize: 11)),
    );
  }
}

class NotesRow extends StatefulWidget {
  final String? myUserId;
  final String? myName;
  final String? myAvatar;
  const NotesRow({super.key, this.myUserId, this.myName, this.myAvatar});

  @override
  State<NotesRow> createState() => _NotesRowState();
}

class _NotesRowState extends State<NotesRow> {
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/notes') as List;
      if (mounted) setState(() => _notes = data.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Map<String, dynamic>? get _mine => _notes
      .cast<Map<String, dynamic>?>()
      .firstWhere((n) => n?['userId'] == widget.myUserId, orElse: () => null);

  Future<void> _editMine() async {
    final mine = _mine;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NoteEditor(existing: mine),
    );
    if (changed == true) _load();
  }

  Widget _person(
      {required String? name,
      required String? avatar,
      Map<String, dynamic>? note,
      VoidCallback? onTap,
      bool mine = false}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: note != null
                    ? NoteBubble(
                        text: note['text'] as String?,
                        songTitle: note['songTitle'] as String?,
                        maxWidth: 80)
                    : mine
                        ? const NoteBubble(text: 'Note…', maxWidth: 80)
                        : null,
              ),
            ),
            const SizedBox(height: 2),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(src: avatar, name: name, size: AvatarSize.md),
                if (mine && note == null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2)),
                      child: const InIcon(InIcons.plus,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(mine ? 'Your note' : (name ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final n in _notes)
        if (n['userId'] != widget.myUserId) n
    ];
    // Grows with the system text size (note bubble + name lines).
    return SizedBox(
      height: 94 + MediaQuery.textScalerOf(context).scale(12) * 1.6,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _person(
              name: widget.myName,
              avatar: widget.myAvatar,
              note: _mine,
              onTap: _editMine,
              mine: true),
          for (final n in others)
            _person(
              name: (n['user'] as Map?)?['name'] as String?,
              avatar: (n['user'] as Map?)?['avatarUrl'] as String?,
              note: n,
              onTap: () => openProfile(context, n['userId'] as String?),
            ),
        ],
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _NoteEditor({this.existing});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _text =
      TextEditingController(text: widget.existing?['text'] as String? ?? '');
  late final _song = TextEditingController(
      text: widget.existing?['songTitle'] as String? ?? '');
  late bool _closeFriends = widget.existing?['audience'] == 'closeFriends';
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _song.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _saving = true);
    try {
      await ApiClient.put('/notes/me', body: {
        'text': _text.text.trim(),
        'songTitle': _song.text.trim(),
        'audience': _closeFriends ? 'closeFriends' : 'followers',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(e is ApiException ? e.message : "Couldn't share note")));
    }
  }

  Future<void> _delete() async {
    try {
      await ApiClient.delete('/notes/me');
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            const Text('Your note',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Text('Shows above your avatar for 24 hours.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              maxLength: 60,
              autofocus: true,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'Share a thought…'),
            ),
            TextField(
              controller: _song,
              maxLength: 120,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                  hintText: 'Or a song you\'re listening to',
                  prefixIcon: InIcon(InIcons.music)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _closeFriends,
              onChanged: (v) => setState(() => _closeFriends = v),
              activeTrackColor: AppColors.success,
              title: const Text('Close friends only',
                  style: TextStyle(color: AppColors.text, fontSize: 13.5)),
            ),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton(
                      onPressed: _delete,
                      child: const Text('Delete note',
                          style: TextStyle(color: AppColors.danger))),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _share,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink),
                  child: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
