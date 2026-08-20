import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Horizontally-scrolling strip of every current room participant as a
/// framed circular avatar — Dart port of PartyPage.jsx's
/// ParticipantAvatarRow. Whoever's mic is live gets a green ring, everyone
/// else gets a neutral gradient frame so the row still reads as "who's in
/// here" even when nobody's talking. Tapping any avatar opens the roster.
class ParticipantAvatarRow extends StatelessWidget {
  final List<RosterEntry> roster;
  final VoidCallback onOpenRoster;

  const ParticipantAvatarRow({super.key, required this.roster, required this.onOpenRoster});

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roster.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final r = roster[i];
          return GestureDetector(
            onTap: onOpenRoster,
            child: SizedBox(
              width: 48,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: r.micOn
                        ? const BoxDecoration(shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.success, width: 2)))
                        : const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppGradients.brand),
                          ),
                    child: Container(
                      padding: r.micOn ? EdgeInsets.zero : const EdgeInsets.all(2),
                      decoration: r.micOn ? null : const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
                      child: Avatar(src: r.avatarUrl, name: r.name, size: AvatarSize.sm),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.isHost ? '👑 ${r.name}' : r.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textFaint, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
