import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Presentational only — all rules (whose turn, win/draw detection, illegal
/// moves) are enforced server-side in src/games/tictactoe.js on the
/// backend; this just renders whatever `game` state the server last
/// broadcast and sends a cell index on tap.
class TicTacToeBoard extends StatelessWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(int cellIndex) onMove;
  final VoidCallback onReset;

  const TicTacToeBoard({
    super.key,
    required this.game,
    required this.myUserId,
    required this.isHost,
    required this.onJoin,
    required this.onMove,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final players = (game['players'] as List? ?? []).cast<Map>();
    final board = (game['board'] as List? ?? List.filled(9, null));
    final status = game['status'] as String? ?? 'waiting';
    final turn = game['turn'] as String?;
    final winner = game['winner'] as String?;
    final isPlayer = players.any((p) => p['userId'] == myUserId);
    final isMyTurn = isPlayer && status == 'playing' && turn == myUserId;
    final winnerPlayer = winner != null ? players.cast<Map?>().firstWhere((p) => p?['userId'] == winner, orElse: () => null) : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in players)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => openProfile(context, p['userId'] as String?),
                          child: Avatar(name: p['name'] as String?, size: AvatarSize.sm),
                        ),
                        const SizedBox(height: 2),
                        Text('${p['name']} ${p['symbol']}', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                        if (status == 'playing' && turn == p['userId'])
                          const Text('Their turn', style: TextStyle(color: AppColors.accent, fontSize: 9)),
                      ],
                    ),
                  ),
                if (players.length < 2) const Text('Waiting for a second player…', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              height: 200,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: 9,
                itemBuilder: (context, i) {
                  final cell = board[i] as String?;
                  return GestureDetector(
                    onTap: (isMyTurn && cell == null) ? () => onMove(i) : null,
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Text(
                        cell ?? '',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cell == 'X' ? AppColors.primary : AppColors.accent),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (!isPlayer && status == 'waiting')
              ElevatedButton(onPressed: onJoin, child: const Text('Join game')),
            if (status == 'won') Text('${winnerPlayer?['name'] ?? 'Someone'} won! 🎉', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            if (status == 'draw') const Text("It's a draw!", style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            if (isHost && (status == 'won' || status == 'draw'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(onPressed: onReset, child: const Text('Play again')),
              ),
          ],
        ),
      ),
    );
  }
}
