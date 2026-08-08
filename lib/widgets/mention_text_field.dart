import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Drop-in @mention autocomplete for a [TextField] — Dart port of the web
/// app's MentionInput.jsx. Watches the text immediately before the cursor
/// for an "@handle" token, queries GET /search?type=users while typing it,
/// and on selection replaces just that token with "@username ". Suggestions
/// render as an inline list below the field (simpler than an Overlay/
/// CompositedTransformFollower popup, and just as functional). Mentions
/// aren't tracked separately — the backend re-parses @handles out of the
/// raw text at post/comment-creation time.
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final int? maxLength;

  const MentionTextField({super.key, required this.controller, this.hintText, this.maxLines = 1, this.maxLength});

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  int? _queryStart;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final value = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0) return;
    final uptoCursor = value.substring(0, cursor);
    final match = RegExp(r'(?:^|\s)@(\w{0,32})$').firstMatch(uptoCursor);
    if (match == null) {
      if (_suggestions.isNotEmpty || _queryStart != null) setState(() { _suggestions = []; _queryStart = null; });
      return;
    }
    final handle = match.group(1) ?? '';
    _queryStart = cursor - handle.length - 1;
    _debounce?.cancel();
    if (handle.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(handle));
  }

  Future<void> _search(String handle) async {
    try {
      final data = await ApiClient.get('/search?q=${Uri.encodeQueryComponent(handle)}&type=users');
      final users = (data as Map)['users'] as List? ?? [];
      if (mounted) setState(() => _suggestions = users.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    if (_queryStart == null) return;
    final value = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset < 0 ? value.length : widget.controller.selection.baseOffset;
    final before = value.substring(0, _queryStart!);
    final after = value.substring(cursor);
    final inserted = '@${user['username'] ?? user['name']} ';
    final nextValue = '$before$inserted$after';
    final pos = before.length + inserted.length;
    widget.controller.value = TextEditingValue(text: nextValue, selection: TextSelection.collapsed(offset: pos));
    setState(() { _suggestions = []; _queryStart = null; });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          style: const TextStyle(color: AppColors.text),
          decoration: InputDecoration(hintText: widget.hintText),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: ListView(
              shrinkWrap: true,
              children: _suggestions.map((u) {
                return ListTile(
                  dense: true,
                  leading: Avatar(src: u['avatarUrl'] as String?, name: u['name'] as String?, size: AvatarSize.sm),
                  title: Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  trailing: u['username'] != null ? Text('@${u['username']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)) : null,
                  onTap: () => _selectUser(u),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
