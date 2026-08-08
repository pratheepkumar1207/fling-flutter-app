import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Presentational only — every rule (yard-exit-on-6, capture, safe squares,
/// exact-roll-to-finish, bonus turn on 6) is enforced server-side in
/// src/games/ludo.js on the backend; this just renders whatever `game`
/// state the server last broadcast. Rather than the literal cross-shaped
/// physical board, each player gets their own horizontal progress lane
/// (yard -> 51 shared-track squares -> 6-square home stretch -> home) —
/// the exact same state and rules as a physical board, laid out as a
/// scrollable per-color strip so it renders correctly without hand-tuned
/// board geometry.

const Map<String, Color> _colorMap = {
  'red': AppColors.danger,
  'green': AppColors.success,
  'yellow': AppColors.gold,
  'blue': AppColors.primary,
};

// The 8 global safe squares are spaced exactly 13 apart in absolute terms
// (matching the 4 colors' 13-apart start offsets), so every color sees the
// same set of relative step values land on a safe square. Must match
// src/games/ludo.js's SAFE_SQUARES exactly (expressed relative instead of
// absolute).
const Set<int> _safeRelativeSteps = {0, 8, 13, 21, 26, 34, 39, 47};

class LudoBoard extends StatelessWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;
  final VoidCallback onReset;

  const LudoBoard({
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
    final tokensByColor = Map<String, dynamic>.from(game['tokens'] as Map? ?? {});
    final status = game['status'] as String? ?? 'waiting';
    final turn = game['turn'] as String?;
    final winner = game['winner'] as String?;
    final diceValue = game['diceValue'] as int?;
    final movableTokenIndices = (game['movableTokenIndices'] as List? ?? []).cast<int>();
    final isPlayer = players.any((p) => p['userId'] == myUserId);
    final isMyTurn = isPlayer && status == 'playing' && turn == myUserId;
    final winnerPlayer = winner != null ? players.cast<Map?>().firstWhere((p) => p?['userId'] == winner, orElse: () => null) : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final p in players)
                    _LudoLane(
                      player: p,
                      tokens: ((tokensByColor[p['color']] as List?) ?? [-1, -1, -1, -1]).cast<int>(),
                      isCurrentTurn: status == 'playing' && turn == p['userId'],
                      isMe: p['userId'] == myUserId,
                      movableTokenIndices: p['userId'] == myUserId ? movableTokenIndices : const [],
                      onMoveToken: (i) => onMove({'action': 'move', 'tokenIndex': i}),
                    ),
                  if (players.length < 2)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Waiting for more players… (up to 4)', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isPlayer && players.length < 4)
                  ElevatedButton(onPressed: onJoin, child: const Text('Join game')),
                if (isMyTurn && diceValue == null)
                  ElevatedButton(onPressed: () => onMove({'action': 'roll'}), child: const Text('🎲 Roll dice')),
                if (diceValue != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                    child: Text('🎲 $diceValue', style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                if (status == 'won') Text('${winnerPlayer?['name'] ?? 'Someone'} won! 🎉', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                if (isHost && status == 'won')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: OutlinedButton(onPressed: onReset, child: const Text('Play again')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LudoLane extends StatelessWidget {
  final Map player;
  final List<int> tokens;
  final bool isCurrentTurn;
  final bool isMe;
  final List<int> movableTokenIndices;
  final void Function(int tokenIndex) onMoveToken;

  const _LudoLane({
    required this.player,
    required this.tokens,
    required this.isCurrentTurn,
    required this.isMe,
    required this.movableTokenIndices,
    required this.onMoveToken,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorMap[player['color']] ?? AppColors.textDim;
    final yardCount = tokens.where((s) => s == -1).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: player['name'] as String?, size: AvatarSize.sm),
              const SizedBox(width: 6),
              Text(player['name'] as String? ?? '', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
              const SizedBox(width: 4),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              if (isCurrentTurn) const Padding(padding: EdgeInsets.only(left: 6), child: Text('Their turn', style: TextStyle(color: AppColors.accent, fontSize: 9))),
            ],
          ),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Container(
                  width: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(4)),
                  alignment: Alignment.center,
                  child: Text('🏠 $yardCount', style: const TextStyle(color: AppColors.textFaint, fontSize: 9)),
                ),
                for (int step = 0; step < 57; step++) _buildCell(step, color),
                Container(
                  width: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(4)),
                  alignment: Alignment.center,
                  child: const Text('🏁', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          if (isMe && movableTokenIndices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final i in movableTokenIndices)
                    GestureDetector(
                      onTap: () => onMoveToken(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                        child: Text('Move token ${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(int step, Color color) {
    final tokensHere = tokens.where((s) => s == step).length;
    final isHomeStretch = step >= 51;
    final isSafe = step < 51 && _safeRelativeSteps.contains(step);
    return Container(
      width: 24,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isHomeStretch ? color.withValues(alpha: 0.3) : isSafe ? AppColors.gold.withValues(alpha: 0.2) : AppColors.surface3,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: tokensHere > 0
          ? Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$tokensHere', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            )
          : isSafe
              ? const Text('⭐', style: TextStyle(fontSize: 10))
              : null,
    );
  }
}
