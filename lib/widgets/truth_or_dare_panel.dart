import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Presentational only — turn rotation and prompt selection are all
/// server-side in src/games/truthOrDare.js on the backend; this just
/// renders whatever `game` state the server last broadcast.
class TruthOrDarePanel extends StatelessWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;

  const TruthOrDarePanel({super.key, required this.game, required this.myUserId, required this.onJoin, required this.onMove});

  @override
  Widget build(BuildContext context) {
    final players = (game['players'] as List? ?? []).cast<Map>();
    final status = game['status'] as String? ?? 'waiting';
    final turn = game['turn'] as String?;
    final prompt = game['currentPrompt'] as Map?;
    final isPlayer = players.any((p) => p['userId'] == myUserId);
    final isMyTurn = isPlayer && status == 'playing' && turn == myUserId;
    final currentPlayer = players.cast<Map?>().firstWhere((p) => p?['userId'] == turn, orElse: () => null);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                for (final p in players)
                  Column(
                    children: [
                      Avatar(name: p['name'] as String?, size: AvatarSize.sm),
                      Text(p['name'] as String? ?? '', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                      if (status == 'playing' && turn == p['userId']) const Text('Their turn', style: TextStyle(color: AppColors.accent, fontSize: 9)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (status == 'waiting') const Text('Waiting for a second player…', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            if (status == 'playing')
              if (prompt == null)
                isMyTurn
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () => onMove({'action': 'choose', 'choice': 'truth'}),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            child: const Text('🤔 Truth'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => onMove({'action': 'choose', 'choice': 'dare'}),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                            child: const Text('🔥 Dare'),
                          ),
                        ],
                      )
                    : Text('Waiting for ${currentPlayer?['name'] ?? 'them'} to choose…', style: const TextStyle(color: AppColors.textDim, fontSize: 13))
              else
                Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Column(
                        children: [
                          Text((prompt['type'] as String? ?? '').toUpperCase(), style: const TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(prompt['text'] as String? ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (isMyTurn)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(onPressed: () => onMove({'action': 'next'}), child: const Text('Next player →')),
                      ),
                  ],
                ),
            if (!isPlayer)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(onPressed: onJoin, child: const Text('Join game')),
              ),
          ],
        ),
      ),
    );
  }
}
