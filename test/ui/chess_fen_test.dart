import 'package:flutter_test/flutter_test.dart';
import 'package:insync/widgets/chess_3d_board.dart';

Map<String, dynamic> _start() {
  final board = List.generate(8, (_) => List<Map?>.filled(8, null));
  const back = ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'];
  for (var c = 0; c < 8; c++) {
    board[0][c] = {'type': back[c], 'color': 'white'};
    board[1][c] = {'type': 'p', 'color': 'white'};
    board[6][c] = {'type': 'p', 'color': 'black'};
    board[7][c] = {'type': back[c], 'color': 'black'};
  }
  return {
    'board': board,
    'turnColor': 'white',
    'castlingRights': {
      'white': {'k': true, 'q': true},
      'black': {'k': true, 'q': true}
    },
    'enPassantTarget': null,
    'halfMoveClock': 0,
  };
}

void main() {
  test('Starting room board reads as the standard FEN', () {
    expect(chessFenOf(_start()),
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  });

  test('After e4: black to move, en passant square, last move', () {
    final g = _start();
    final board = g['board'] as List;
    board[3][4] = board[1][4];
    board[1][4] = null;
    g['turnColor'] = 'black';
    g['enPassantTarget'] = [2, 4];
    g['lastMove'] = {'from': [1, 4], 'to': [3, 4]};
    expect(chessFenOf(g),
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
    expect(chessLastMoveUci(g), 'e2e4');
  });
}
