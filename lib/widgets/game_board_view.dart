import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'chess_board.dart';
import 'ludo_board.dart';
import 'tic_tac_toe_board.dart';
import 'truth_or_dare_panel.dart';
import 'uno_board.dart';

/// Renders in the same media-area slot SyncVideoPlayer/LiveVideoView
/// occupy for 'watch'/'live' rooms, switched by the room's gameType.
/// Ludo/Truth or Dare arms land here as their own modules land — see
/// src/games/*.js on the backend for the matching server-side logic.
class GameBoardView extends StatelessWidget {
  final String? gameType;
  final Map<String, dynamic>? game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;
  final VoidCallback onReset;

  const GameBoardView({
    super.key,
    required this.gameType,
    required this.game,
    required this.myUserId,
    required this.isHost,
    required this.onJoin,
    required this.onMove,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: const Text('🎮', style: TextStyle(fontSize: 48)),
        ),
      );
    }

    if (gameType == 'tictactoe') {
      return TicTacToeBoard(
        game: game!,
        myUserId: myUserId,
        isHost: isHost,
        onJoin: onJoin,
        onMove: (cellIndex) => onMove({'cellIndex': cellIndex}),
        onReset: onReset,
      );
    }

    if (gameType == 'truth_or_dare') {
      return TruthOrDarePanel(game: game!, myUserId: myUserId, onJoin: onJoin, onMove: onMove);
    }

    if (gameType == 'ludo') {
      return LudoBoard(game: game!, myUserId: myUserId, isHost: isHost, onJoin: onJoin, onMove: onMove, onReset: onReset);
    }

    if (gameType == 'chess') {
      return ChessBoard(game: game!, myUserId: myUserId, isHost: isHost, onJoin: onJoin, onMove: onMove, onReset: onReset);
    }

    if (gameType == 'uno') {
      return UnoBoard(game: game!, myUserId: myUserId, isHost: isHost, onJoin: onJoin, onMove: onMove, onReset: onReset);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🎮', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text("This game isn't available yet.", style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
