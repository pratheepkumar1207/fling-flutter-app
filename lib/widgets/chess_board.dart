import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Presentational only — every rule (legal moves, check, checkmate,
/// castling preconditions, en passant, promotion) is enforced server-side
/// in src/games/chess.js. The pseudo-move generator below exists purely so
/// tapping a piece highlights *likely* destinations before committing to a
/// move; it deliberately skips the "does this leave my own king in check"
/// filter the server applies, so an illegal highlighted square just gets
/// silently rejected (no state change) if tapped — a minor UX rough edge,
/// not a rules gap, since the server is always the final word.
const _kGlyphs = {
  'white': {'p': '♙', 'n': '♘', 'b': '♗', 'r': '♖', 'q': '♕', 'k': '♔'},
  'black': {'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚'},
};

const _kKnightOffsets = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
const _kKingOffsets = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
const _kBishopDirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
const _kRookDirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

bool _inBounds(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

Map<String, dynamic>? _pieceAt(List board, int r, int c) => board[r][c] as Map<String, dynamic>?;

List<List<int>> _pseudoMoves(List board, int row, int col, List? enPassantTarget, Map? castlingRights) {
  final piece = _pieceAt(board, row, col);
  if (piece == null) return [];
  final moves = <List<int>>[];
  final enemy = piece['color'] == 'white' ? 'black' : 'white';

  bool addIfOk(int r, int c) {
    if (!_inBounds(r, c)) return false;
    final target = _pieceAt(board, r, c);
    if (target == null) {
      moves.add([r, c]);
      return true;
    }
    if (target['color'] == enemy) moves.add([r, c]);
    return false;
  }

  final type = piece['type'] as String;
  if (type == 'p') {
    final dir = piece['color'] == 'white' ? 1 : -1;
    final startRow = piece['color'] == 'white' ? 1 : 6;
    if (_inBounds(row + dir, col) && _pieceAt(board, row + dir, col) == null) {
      moves.add([row + dir, col]);
      if (row == startRow && _pieceAt(board, row + 2 * dir, col) == null) moves.add([row + 2 * dir, col]);
    }
    for (final dc in [-1, 1]) {
      final r = row + dir, c = col + dc;
      if (!_inBounds(r, c)) continue;
      final target = _pieceAt(board, r, c);
      if (target != null && target['color'] == enemy) {
        moves.add([r, c]);
      } else if (enPassantTarget != null && enPassantTarget[0] == r && enPassantTarget[1] == c) {
        moves.add([r, c]);
      }
    }
  } else if (type == 'n') {
    for (final o in _kKnightOffsets) {
      addIfOk(row + o[0], col + o[1]);
    }
  } else if (type == 'k') {
    for (final o in _kKingOffsets) {
      addIfOk(row + o[0], col + o[1]);
    }
    final rights = castlingRights?[piece['color']] as Map?;
    final homeRow = piece['color'] == 'white' ? 0 : 7;
    if (row == homeRow && col == 4 && rights != null) {
      if (rights['k'] == true && _pieceAt(board, homeRow, 5) == null && _pieceAt(board, homeRow, 6) == null) {
        moves.add([homeRow, 6]);
      }
      if (rights['q'] == true && _pieceAt(board, homeRow, 3) == null && _pieceAt(board, homeRow, 2) == null && _pieceAt(board, homeRow, 1) == null) {
        moves.add([homeRow, 2]);
      }
    }
  } else {
    final dirs = type == 'b' ? _kBishopDirs : type == 'r' ? _kRookDirs : [..._kBishopDirs, ..._kRookDirs];
    for (final d in dirs) {
      var r = row + d[0], c = col + d[1];
      while (addIfOk(r, c)) {
        r += d[0];
        c += d[1];
      }
    }
  }
  return moves;
}

class ChessBoard extends StatefulWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;
  final VoidCallback onReset;

  const ChessBoard({
    super.key,
    required this.game,
    required this.myUserId,
    required this.isHost,
    required this.onJoin,
    required this.onMove,
    required this.onReset,
  });

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  List<int>? _selected;
  Map<String, List<int>>? _pendingPromotion; // {'from': [r,c], 'to': [r,c]}

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final players = (game['players'] as List? ?? []).cast<Map>();
    final board = game['board'] as List;
    final status = game['status'] as String? ?? 'waiting';
    final turnColor = game['turnColor'] as String? ?? 'white';
    final winner = game['winner'] as String?;
    final check = game['check'] == true;
    final drawReason = game['drawReason'] as String?;
    final enPassantTarget = (game['enPassantTarget'] as List?)?.cast<int>();
    final castlingRights = game['castlingRights'] as Map?;

    final me = players.cast<Map?>().firstWhere((p) => p?['userId'] == widget.myUserId, orElse: () => null);
    final isPlayer = me != null;
    final myColor = me?['color'] as String?;
    final isMyTurn = isPlayer && status == 'playing' && myColor == turnColor;
    final winnerPlayer = winner != null ? players.cast<Map?>().firstWhere((p) => p?['userId'] == winner, orElse: () => null) : null;

    final destinations = _selected != null ? _pseudoMoves(board, _selected![0], _selected![1], enPassantTarget, castlingRights) : <List<int>>[];
    bool isDest(int r, int c) => destinations.any((d) => d[0] == r && d[1] == c);

    final flipped = myColor == 'black';
    final rowOrder = flipped ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0];
    final colOrder = flipped ? [7, 6, 5, 4, 3, 2, 1, 0] : [0, 1, 2, 3, 4, 5, 6, 7];

    List<int>? kingSquare;
    if (check) {
      outer:
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final p = _pieceAt(board, r, c);
          if (p != null && p['type'] == 'k' && p['color'] == turnColor) {
            kingSquare = [r, c];
            break outer;
          }
        }
      }
    }

    void handleTap(int row, int col) {
      if (!isMyTurn) return;
      final piece = _pieceAt(board, row, col);

      if (_selected != null && isDest(row, col)) {
        final from = _selected!;
        final movingPiece = _pieceAt(board, from[0], from[1]);
        final isPawn = movingPiece?['type'] == 'p';
        final isPromotionRank = (turnColor == 'white' && row == 7) || (turnColor == 'black' && row == 0);
        setState(() {
          if (isPawn && isPromotionRank) {
            _pendingPromotion = {'from': from, 'to': [row, col]};
          } else {
            widget.onMove({'from': from, 'to': [row, col]});
          }
          _selected = null;
        });
        return;
      }

      setState(() {
        if (piece != null && piece['color'] == myColor) {
          _selected = [row, col];
        } else {
          _selected = null;
        }
      });
    }

    void choosePromotion(String piece) {
      if (_pendingPromotion != null) {
        widget.onMove({'from': _pendingPromotion!['from'], 'to': _pendingPromotion!['to'], 'promotion': piece});
      }
      setState(() => _pendingPromotion = null);
    }

    String? statusText;
    if (status == 'won') {
      statusText = '${winnerPlayer?['name'] ?? 'Someone'} won by checkmate! ♛';
    } else if (status == 'draw') {
      final reason = {'stalemate': 'stalemate', 'insufficient_material': 'insufficient material', 'fifty_move': 'the 50-move rule'}[drawReason] ?? 'a draw';
      statusText = 'Draw — $reason';
    } else if (check) {
      statusText = 'Check!';
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                      Text('${p['name']} ${p['color'] == 'white' ? '♔' : '♚'}', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                      if (status == 'playing' && turnColor == p['color'])
                        const Text('Their turn', style: TextStyle(color: AppColors.accent, fontSize: 9)),
                    ],
                  ),
                ),
              if (players.length < 2) const Text('Waiting for a second player…', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (context, i) {
                  final row = rowOrder[i ~/ 8];
                  final col = colOrder[i % 8];
                  final piece = _pieceAt(board, row, col);
                  final dark = (row + col) % 2 == 0;
                  final isSelected = _selected != null && _selected![0] == row && _selected![1] == col;
                  final isKingInCheck = kingSquare != null && kingSquare[0] == row && kingSquare[1] == col;
                  return GestureDetector(
                    onTap: () => handleTap(row, col),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isKingInCheck
                            ? AppColors.danger.withValues(alpha: 0.4)
                            : dark
                                ? AppColors.surface3
                                : AppColors.surface,
                        border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (piece != null)
                            Text(
                              _kGlyphs[piece['color']]![piece['type']]!,
                              style: TextStyle(fontSize: 22, color: piece['color'] == 'white' ? AppColors.text : AppColors.textDim),
                            ),
                          if (isDest(row, col))
                            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!isPlayer && status == 'waiting') ElevatedButton(onPressed: widget.onJoin, child: const Text('Join game')),
          if (statusText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(statusText, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            ),
          if (widget.isHost && (status == 'won' || status == 'draw'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(onPressed: widget.onReset, child: const Text('Play again')),
            ),
          if (_pendingPromotion != null) ...[
            const SizedBox(height: 10),
            const Text('Promote to', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in ['q', 'r', 'b', 'n'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => choosePromotion(p),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        alignment: Alignment.center,
                        child: Text(_kGlyphs[myColor ?? 'white']![p]!, style: const TextStyle(fontSize: 24, color: AppColors.text)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
