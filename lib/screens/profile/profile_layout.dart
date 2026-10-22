import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/insync_clay.dart';

/// One arrangeable part of a profile — a section above the tabs, or a tab.
class ProfileLayoutEntry {
  final String id;
  final bool visible;
  const ProfileLayoutEntry(this.id, {this.visible = true});

  ProfileLayoutEntry copyWith({bool? visible}) =>
      ProfileLayoutEntry(id, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {'id': id, 'visible': visible};
}

/// The order (and on/off) of a profile's sections and tabs, as the owner
/// arranged it — stored on the user (PATCH /auth/me profileLayout) so
/// everyone who visits sees the same order. Mirrors the backend's
/// PROFILE_SECTIONS / PROFILE_TABS (routes/auth.js): unknown ids are
/// dropped and missing ones appended, so a part added later still shows.
class ProfileLayout {
  static const sectionIds = ['rightNow', 'highlights', 'interests', 'progress'];
  static const tabIds = [
    'posts',
    'reels',
    'photos',
    'music',
    'tagged',
    'supporters'
  ];

  final List<ProfileLayoutEntry> sections;
  final List<ProfileLayoutEntry> tabs;
  const ProfileLayout(this.sections, this.tabs);

  static List<ProfileLayoutEntry> _parse(dynamic raw, List<String> allowed) {
    final out = <ProfileLayoutEntry>[];
    final seen = <String>{};
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final id = e['id'];
        if (id is! String || !allowed.contains(id) || !seen.add(id)) continue;
        out.add(ProfileLayoutEntry(id, visible: e['visible'] != false));
      }
    }
    for (final id in allowed) {
      if (!seen.contains(id)) out.add(ProfileLayoutEntry(id));
    }
    return out;
  }

  factory ProfileLayout.fromJson(Map<String, dynamic>? json) => ProfileLayout(
        _parse(json?['sections'], sectionIds),
        _parse(json?['tabs'], tabIds),
      );

  Map<String, dynamic> toJson() => {
        'sections': [for (final e in sections) e.toJson()],
        'tabs': [for (final e in tabs) e.toJson()],
      };

  bool showSection(String id) => sections.any((e) => e.id == id && e.visible);

  List<String> visibleSections() => [
        for (final e in sections)
          if (e.visible) e.id
      ];

  /// Visible tabs in order, limited to the ones this profile can show
  /// (e.g. "supporters" is only on other people's profiles).
  List<String> visibleTabs(Set<String> available) => [
        for (final e in tabs)
          if (e.visible && available.contains(e.id)) e.id
      ];

  static String label(String id) => switch (id) {
        'rightNow' => 'Right now (room I\'m in)',
        'highlights' => 'Highlights',
        'interests' => 'Interests',
        'progress' => 'Progress cards',
        'posts' => 'Posts',
        'reels' => 'Reels',
        'photos' => 'Photos',
        'music' => 'Music',
        'tagged' => 'Tagged',
        'supporters' => 'Supporters',
        _ => id,
      };

  static IconData icon(String id) => switch (id) {
        'rightNow' => Icons.sensors_rounded,
        'highlights' => Icons.auto_awesome_rounded,
        'interests' => Icons.local_offer_outlined,
        'progress' => Icons.insights_rounded,
        'posts' => Icons.grid_on_rounded,
        'reels' => Icons.movie_outlined,
        'photos' => Icons.photo_outlined,
        'music' => Icons.music_note_outlined,
        'tagged' => Icons.assignment_ind_outlined,
        'supporters' => Icons.volunteer_activism_outlined,
        _ => Icons.circle_outlined,
      };
}

/// Arrange profile — drag sections and tabs into any order and switch any
/// of them off. The first visible tab is the one the profile opens on.
class ArrangeProfileScreen extends StatefulWidget {
  const ArrangeProfileScreen({super.key});

  @override
  State<ArrangeProfileScreen> createState() => _ArrangeProfileScreenState();
}

class _ArrangeProfileScreenState extends State<ArrangeProfileScreen> {
  late ProfileLayout _layout =
      ProfileLayout.fromJson(context.read<AuthProvider>().user?.profileLayout);
  bool _saving = false;

  Future<void> _done() async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/auth/me',
          body: {'profileLayout': _layout.toJson()});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't save — check your connection")));
    }
  }

  Widget _list(String title, List<ProfileLayoutEntry> entries,
      void Function(List<ProfileLayoutEntry>) onChanged,
      {bool tabs = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) {
            final next = [...entries];
            final item = next.removeAt(from);
            next.insert(to, item);
            onChanged(next);
          },
          children: [
            for (var i = 0; i < entries.length; i++)
              ListTile(
                key: ValueKey(entries[i].id),
                contentPadding: const EdgeInsets.only(left: 8, right: 12),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator_rounded,
                            color: AppColors.textFaint,
                            semanticLabel: 'Drag to reorder'),
                      ),
                    ),
                    Icon(ProfileLayout.icon(entries[i].id),
                        color: AppColors.textDim, size: 20),
                  ],
                ),
                title: Text(ProfileLayout.label(entries[i].id),
                    style:
                        const TextStyle(color: AppColors.text, fontSize: 14)),
                subtitle: tabs && entries.indexWhere((e) => e.visible) == i
                    ? const Text('Opens first',
                        style:
                            TextStyle(color: AppColors.accent, fontSize: 11.5))
                    : null,
                trailing: Switch(
                  value: entries[i].visible,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) {
                    final next = [...entries];
                    next[i] = next[i].copyWith(visible: v);
                    onChanged(next);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const InsyncPageTitle('Arrange profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _done,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Done',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
                'Drag to reorder. Switch off to hide. Everyone who visits sees your order.',
                style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          ),
          _list(
              'Sections',
              _layout.sections,
              (next) =>
                  setState(() => _layout = ProfileLayout(next, _layout.tabs))),
          _list(
              'Tabs',
              _layout.tabs,
              (next) => setState(
                  () => _layout = ProfileLayout(_layout.sections, next)),
              tabs: true),
          TextButton(
            onPressed: () =>
                setState(() => _layout = ProfileLayout.fromJson(null)),
            child: const Text('Reset to default',
                style: TextStyle(color: AppColors.textDim)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
