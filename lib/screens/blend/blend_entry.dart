import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../models/blend.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/people_picker_sheet.dart';
import 'blend_screen.dart';

/// Ways into a Reels Blend: the card in a DM, Messages -> New Blend, and
/// the Blends row at the top of Messages.

void openBlend(BuildContext context, String blendId, {bool together = false}) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlendScreen(blendId: blendId, together: together)));
}

Future<Blend?> _createBlend(
    BuildContext context, List<String> memberIds) async {
  try {
    final data =
        await ApiClient.post('/blends', body: {'memberIds': memberIds});
    return Blend.fromJson(data as Map<String, dynamic>);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  }
}

/// From a DM's header: finds or starts the Blend with this person and
/// shows its card.
Future<Blend?> showDmBlendSheet(BuildContext context, String userId) async {
  final blend = await _createBlend(context, [userId]);
  if (blend == null || !context.mounted) return blend;
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlendCard(blend: blend, onOpen: () => Navigator.of(sheet).pop()),
      ),
    ),
  );
  return blend;
}

/// Messages -> New Blend: pick 1-7 people.
Future<void> startNewBlend(BuildContext context,
    {VoidCallback? onCreated}) async {
  final picked = await showPeoplePicker(context,
      title: 'Start a Blend', doneLabel: 'Start');
  if (picked == null || picked.isEmpty || !context.mounted) return;
  if (picked.length > 7) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A Blend can have up to 8 people')));
    return;
  }
  final blend = await _createBlend(context, picked.map((p) => p.id).toList());
  if (blend == null || !context.mounted) return;
  onCreated?.call();
  openBlend(context, blend.id);
}

class _Faces extends StatelessWidget {
  final List<BlendMember> people;
  final double size;
  const _Faces({required this.people, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final shown = people.take(3).toList();
    return SizedBox(
      width: size + (size * 0.6) * (shown.length - 1).clamp(0, 2),
      height: size,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * size * 0.6,
            child: Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2)),
              child: SizedBox(
                width: size - 4,
                height: size - 4,
                child: FittedBox(
                    child:
                        Avatar(src: shown[i].avatarUrl, name: shown[i].name)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// "You and Bala · Blend" with Open Blend / Watch together. [onOpen]
/// runs first (e.g. to close the sheet it sits in).
class BlendCard extends StatelessWidget {
  final Blend blend;
  final VoidCallback? onOpen;
  final bool compact;
  const BlendCard(
      {super.key, required this.blend, this.onOpen, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    final me = blend.member(myId);
    final faces = [if (me != null) me, ...blend.others(myId)];
    void go(bool together) {
      onOpen?.call();
      openBlend(context, blend.id, together: together);
    }

    final title =
        blend.isGroup ? blend.title(myId) : 'You and ${blend.title(myId)}';
    final buttons = Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => go(false),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border)),
          child: const FittedBox(child: Text('Open Blend')),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          onPressed: () => go(true),
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink),
          child: const FittedBox(child: Text('Watch together')),
        ),
      ),
    ]);
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Row(children: [
            _Faces(people: faces, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$title · Blend',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          buttons,
        ]),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Faces(people: faces, size: 44),
        const SizedBox(height: 10),
        Text('$title · Blend',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Reels from your likes, mixed into one feed',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 14),
        buttons,
      ],
    );
  }
}

/// Top of Messages: New Blend, then your Blends.
class BlendsRow extends StatefulWidget {
  const BlendsRow({super.key});

  @override
  State<BlendsRow> createState() => BlendsRowState();
}

class BlendsRowState extends State<BlendsRow> {
  List<Blend> _blends = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final data = await ApiClient.get('/blends');
      if (!mounted) return;
      setState(() => _blends = [
            for (final b in data as List)
              Blend.fromJson(Map<String, dynamic>.from(b as Map))
          ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;
    Widget tile(
            {required Widget face,
            required String label,
            required VoidCallback onTap,
            bool live = false}) =>
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 72,
            child: Column(children: [
              SizedBox(height: 48, child: Center(child: face)),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: live ? AppColors.success : AppColors.textDim,
                      fontSize: 11)),
            ]),
          ),
        );
    return SizedBox(
      // Room for the face plus one line of label at any text size.
      height: 60 + MediaQuery.textScalerOf(context).scale(11) * 1.4,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          tile(
            face: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border)),
              child: const InIcon(InIcons.blend,
                  color: AppColors.accent, size: 22),
            ),
            label: 'New Blend',
            onTap: () => startNewBlend(context, onCreated: reload),
          ),
          for (final b in _blends)
            tile(
              face: _Faces(people: b.others(myId), size: 36),
              label: b.watching.any((id) => id != myId)
                  ? 'Watching now'
                  : b.title(myId),
              live: b.watching.any((id) => id != myId),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => BlendScreen(blendId: b.id)))
                  .then((_) => reload()),
            ),
        ],
      ),
    );
  }
}
