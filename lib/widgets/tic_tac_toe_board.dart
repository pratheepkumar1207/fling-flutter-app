import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'game_seat.dart';

const _kX = Color(0xFFFF7AA8);
const _kO = Color(0xFF7AD7FF);

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
    final winnerPlayer = winner != null
        ? players
            .cast<Map?>()
            .firstWhere((p) => p?['userId'] == winner, orElse: () => null)
        : null;

    final full = players.length >= 2;
    String statusText() {
      if (status == 'won') return '${winnerPlayer?['name'] ?? 'Someone'} won!';
      if (status == 'draw') return "It's a draw";
      if (status == 'waiting') {
        return players.isEmpty
            ? 'Waiting for players'
            : 'Waiting for a second player';
      }
      if (isMyTurn) return 'Your turn';
      final current = players
          .cast<Map?>()
          .firstWhere((p) => p?['userId'] == turn, orElse: () => null);
      return "${current?['name'] ?? 'Their'}'s turn";
    }

    Widget seat(int i) {
      if (i >= players.length) return const GameOpenSeat();
      final p = players[i];
      final symbol = p['symbol'] as String? ?? '';
      return GameSeat(
        userId: p['userId'] as String?,
        name: p['name'] as String?,
        isMe: p['userId'] == myUserId,
        isTurn: status == 'playing' && turn == p['userId'],
        detail: Text(symbol,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: symbol == 'X' ? _kX : _kO)),
      );
    }

    // Seats left and right of the grid — X on the left, O on the right.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameStatusLine(statusText(), highlight: status != 'waiting'),
        const SizedBox(height: 6),
        Row(
          children: [
            seat(0),
            const SizedBox(width: 6),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14)),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6),
                    itemCount: 9,
                    itemBuilder: (context, i) {
                      final cell = board[i] as String?;
                      return GestureDetector(
                        onTap:
                            (isMyTurn && cell == null) ? () => onMove(i) : null,
                        child: Container(
                          decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(9)),
                          alignment: Alignment.center,
                          child: Text(
                            cell ?? '',
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: cell == 'X' ? _kX : _kO),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            seat(1),
          ],
        ),
        const SizedBox(height: 14),
        GameJoinButton(seated: isPlayer, full: full, fallbackJoin: onJoin),
        if (isHost && (status == 'won' || status == 'draw'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
                onPressed: onReset, child: const Text('Play again')),
          ),
      ],
    );
  }
}
