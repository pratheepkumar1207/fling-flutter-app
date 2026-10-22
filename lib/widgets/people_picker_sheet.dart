import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// A person in a picker — the same {id, name, username, avatarUrl} shape
/// /social/following and /search return.
class PickedPerson {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  const PickedPerson(
      {required this.id, required this.name, this.username, this.avatarUrl});

  factory PickedPerson.fromJson(Map<String, dynamic> j) => PickedPerson(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Someone',
        username: j['username'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'username': username, 'avatarUrl': avatarUrl};
}

/// Pick people — starts with who you follow, search finds anyone. Returns
/// the chosen people (one when [single]), or null if dismissed.
Future<List<PickedPerson>?> showPeoplePicker(
  BuildContext context, {
  required String title,
  bool single = false,
  List<PickedPerson> initial = const [],
  String doneLabel = 'Done',
}) {
  return showModalBottomSheet<List<PickedPerson>>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PeoplePicker(
        title: title, single: single, initial: initial, doneLabel: doneLabel),
  );
}

class _PeoplePicker extends StatefulWidget {
  final String title;
  final bool single;
  final List<PickedPerson> initial;
  final String doneLabel;
  const _PeoplePicker(
      {required this.title,
      required this.single,
      required this.initial,
      required this.doneLabel});

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  late final Map<String, PickedPerson> _selected = {
    for (final p in widget.initial) p.id: p
  };
  List<PickedPerson> _following = [];
  List<PickedPerson>? _results;
  Timer? _debounce;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final data = await ApiClient.get('/social/following') as List;
      if (!mounted) return;
      setState(() {
        _following = data
            .map((e) => PickedPerson.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final data = await ApiClient.get(
                '/search?type=users&q=${Uri.encodeQueryComponent(q.trim())}')
            as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _results = ((data['users'] as List?) ?? [])
            .map((e) => PickedPerson.fromJson(Map<String, dynamic>.from(e)))
            .toList());
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  void _tap(PickedPerson p) {
    if (widget.single) {
      Navigator.of(context).pop([p]);
      return;
    }
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected[p.id] = p;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _results ?? _following;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (!widget.single)
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_selected.values.toList()),
                        child: Text(widget.doneLabel,
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: _search,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Search people',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.surface2,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: _loading && _results == null
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())
                    : list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No one found',
                                style: TextStyle(color: AppColors.textFaint)))
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final p in list)
                                ListTile(
                                  onTap: () => _tap(p),
                                  leading: Avatar(
                                      src: p.avatarUrl,
                                      name: p.name,
                                      size: AvatarSize.sm),
                                  title: Text(p.name,
                                      style: const TextStyle(
                                          color: AppColors.text, fontSize: 14)),
                                  subtitle: p.username == null
                                      ? null
                                      : Text('@${p.username}',
                                          style: const TextStyle(
                                              color: AppColors.textFaint,
                                              fontSize: 12)),
                                  trailing: widget.single
                                      ? null
                                      : Icon(
                                          _selected.containsKey(p.id)
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked,
                                          color: _selected.containsKey(p.id)
                                              ? AppColors.accent
                                              : AppColors.textFaint),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
