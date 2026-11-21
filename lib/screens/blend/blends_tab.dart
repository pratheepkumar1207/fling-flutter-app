import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../models/blend.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import 'blend_entry.dart';

/// Messages → Blends tab: start a blend, then your blends with friends
/// (two people) and groups (three to eight). Each opens the shared reels
/// feed; Watch together opens it synced, with everyone in it.
class BlendsTabList extends StatefulWidget {
  const BlendsTabList({super.key});

  @override
  State<BlendsTabList> createState() => _BlendsTabListState();
}

class _BlendsTabListState extends State<BlendsTabList> {
  List<Blend>? _blends;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/blends');
      if (!mounted) return;
      setState(() => _blends = [
            for (final b in data as List)
              Blend.fromJson(Map<String, dynamic>.from(b as Map))
          ]);
    } catch (_) {
      if (mounted) setState(() => _blends = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user?.id;
    final blends = _blends;
    if (blends == null) {
      return const Padding(
          padding: EdgeInsets.all(32), child: Center(child: Spinner()));
    }
    final pairs = blends.where((b) => b.members.length <= 2).toList();
    final groups = blends.where((b) => b.members.length > 2).toList();

    String title(Blend b) {
      if (b.name != null && b.name!.trim().isNotEmpty) return b.name!;
      final others = b.members.where((m) => m.id != me).toList();
      if (others.isEmpty) return 'Blend';
      if (others.length == 1) return 'You + ${others.first.firstName}';
      return 'You + ${others.map((m) => m.firstName).take(2).join(', ')}'
          '${others.length > 2 ? ' +${others.length - 2}' : ''}';
    }

    Widget tile(Blend b) {
      final others = b.members.where((m) => m.id != me).toList();
      final live = b.watching.isNotEmpty;
      return ListTile(
        onTap: () => openBlend(context, b.id),
        leading: SizedBox(
          width: 44,
          height: 44,
          child: Stack(children: [
            for (var i = 0; i < others.take(2).length; i++)
              Positioned(
                left: i * 14.0,
                top: i * 10.0,
                child: Avatar(
                    src: others[i].avatarUrl,
                    name: others[i].name,
                    size: AvatarSize.sm),
              ),
          ]),
        ),
        title: Text(title(b),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            live
                ? '${b.watching.length} watching now'
                : '${b.members.length} people · reels you all liked',
            style: TextStyle(
                color: live ? const Color(0xFF5DCAA5) : AppColors.textFaint,
                fontSize: 12.5)),
        trailing: TextButton(
          onPressed: () => openBlend(context, b.id, together: true),
          child: const Text('Watch together'),
        ),
      );
    }

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Text(t,
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700)),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onTap: () => startNewBlend(context, onCreated: _load),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF2A2140),
              child: Icon(Icons.add_rounded, color: AppColors.lilac),
            ),
            title: const Text('Start a blend',
                style: TextStyle(
                    color: AppColors.lilac, fontWeight: FontWeight.w700)),
            subtitle: const Text('With a friend or up to 7 people'),
          ),
        ),
      ),
      if (blends.isEmpty)
        const Padding(
          padding: EdgeInsets.all(28),
          child: Text(
              'A blend mixes the reels you and your friends liked into one '
              'feed you can watch together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint)),
        ),
      if (pairs.isNotEmpty) header('WITH FRIENDS'),
      for (final b in pairs) tile(b),
      if (groups.isNotEmpty) header('GROUPS'),
      for (final b in groups) tile(b),
    ]);
  }
}
