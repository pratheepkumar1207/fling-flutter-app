import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'game_seat.dart';

/// Presentational only — every rule (legal-play matching, skip/reverse/+2/+4,
/// wild-color choice, the "can't +4 while holding a matching color" check,
/// UNO-call/catch penalty, win detection) is enforced server-side in
/// src/games/uno.js. This client also only ever sees a REDACTED view of the
/// game: `game['hand']` is this player's own cards, `game['players'][i]
/// ['handCount']` is all we know about anyone else's hand — see uno.js's
/// getStateForPlayer and syncHandler.js's broadcastGameState. Mirrors
/// UnoBoard.jsx; the two must be kept in sync with each other.

const List<String> _colors = ['red', 'yellow', 'green', 'blue'];
const Map<String, Color> _colorHex = {
  'red': AppColors.danger,
  'yellow': AppColors.gold,
  'green': AppColors.success,
  'blue': Color(0xFF4F9DFF), // matches ludo_board.dart's one-off blue
};
const Map<String, String> _colorName = {
  'red': 'Red',
  'yellow': 'Yellow',
  'green': 'Green',
  'blue': 'Blue'
};

bool _isLegalPlay(Map card, Map? topCard, String? currentColor) {
  if (topCard == null) return true;
  if (card['color'] == 'wild') return true;
  if (card['color'] == currentColor) return true;
  if (card['type'] == 'number' &&
      topCard['type'] == 'number' &&
      card['value'] == topCard['value']) return true;
  if (card['type'] != 'number' && card['type'] == topCard['type']) return true;
  return false;
}

String _cardLabel(Map card) {
  switch (card['type']) {
    case 'number':
      return '${card['value']}';
    case 'skip':
      return '⊘';
    case 'reverse':
      return '⤾';
    case 'draw2':
      return '+2';
    case 'wild':
      return '★';
    case 'wild4':
      return '+4';
    default:
      return '';
  }
}

class _CardFace extends StatelessWidget {
  final Map card;
  final double width;
  final double height;
  final double fontSize;
  const _CardFace(
      {required this.card,
      this.width = 46,
      this.height = 68,
      this.fontSize = 19});

  @override
  Widget build(BuildContext context) {
    final isWild = card['color'] == 'wild';
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        gradient: isWild
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A1A), Color(0xFF333333)])
            : null,
        color: isWild ? null : _colorHex[card['color']],
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isWild)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Opacity(
                  opacity: 0.4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: GridView.count(
                      crossAxisCount: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _colors
                          .map((c) => Container(color: _colorHex[c]))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          Text(
            _cardLabel(card),
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 3)]),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final double width;
  final double height;
  const _CardBack({this.width = 34, this.height = 50});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2A2A), Color(0xFF111111)]),
      ),
      child: Text('U',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w900,
              fontSize: 10)),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose a color',
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: _colors.map((c) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(c),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _colorHex[c],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 2)),
                    child: Text(_colorName[c]!,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class UnoBoard extends StatelessWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;
  final VoidCallback onReset;

  const UnoBoard({
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
    final status = game['status'] as String? ?? 'waiting';
    final currentPlayerIndex = game['currentPlayerIndex'] as int? ?? 0;
    final currentPlayer =
        players.isNotEmpty && currentPlayerIndex < players.length
            ? players[currentPlayerIndex]
            : null;
    final winner = game['winner'] as String?;
    final winnerPlayer = winner != null
        ? players
            .cast<Map?>()
            .firstWhere((p) => p?['userId'] == winner, orElse: () => null)
        : null;
    final hand = (game['hand'] as List? ?? []).cast<Map>();
    final discardTop = game['discardTop'] as Map?;
    final currentColor = game['currentColor'] as String?;
    final drawPileCount = game['drawPileCount'] as int? ?? 0;
    final pendingDraw = game['pendingDraw'] as int? ?? 0;
    final unoFlags = Map<String, dynamic>.from(game['unoFlags'] as Map? ?? {});
    final me = players
        .cast<Map?>()
        .firstWhere((p) => p?['userId'] == myUserId, orElse: () => null);
    final isPlayer = me != null;
    final isMyTurn =
        isPlayer && status == 'playing' && currentPlayer?['userId'] == myUserId;
    final mustDraw = isMyTurn && pendingDraw > 0;

    String statusText() {
      if (status == 'won') return "${winnerPlayer?['name'] ?? 'Someone'} won!";
      if (players.length < 2) return 'Waiting for players (2 to 6)';
      if (currentPlayer == null) return '';
      if (mustDraw) {
        return isMyTurn
            ? 'Draw $pendingDraw — tap the deck.'
            : "${currentPlayer['name']} must draw $pendingDraw.";
      }
      if (isMyTurn) return 'Your turn';
      return "${currentPlayer['name']}'s turn";
    }

    Future<void> playCard(Map card) async {
      if (!isMyTurn || mustDraw) return;
      if (!_isLegalPlay(card, discardTop, currentColor)) return;
      if (card['color'] == 'wild') {
        final color = await showDialog<String>(
            context: context, builder: (_) => const _ColorPickerDialog());
        if (color != null) {
          onMove(
              {'action': 'play', 'cardId': card['id'], 'chosenColor': color});
        }
        return;
      }
      onMove({'action': 'play', 'cardId': card['id']});
    }

    final opponents = [
      for (final p in players)
        if (p['userId'] != myUserId) p
    ];

    Widget opponentSeat(Map p) {
      final isTurn =
          status == 'playing' && currentPlayer?['userId'] == p['userId'];
      final handCount = p['handCount'] as int? ?? 0;
      final showUno = handCount == 1 && unoFlags[p['userId']] != true;
      return GameSeat(
        userId: p['userId'] as String?,
        name: p['name'] as String?,
        isTurn: isTurn,
        size: 28,
        detail: showUno
            ? GestureDetector(
                onTap: () =>
                    onMove({'action': 'catchUno', 'targetUserId': p['userId']}),
                child: Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Catch!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              )
            : Text(handCount == 1 ? 'UNO' : '$handCount cards'),
      );
    }

    final pile = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isMyTurn ? () => onMove({'action': 'draw'}) : null,
          child: Opacity(
            opacity: isMyTurn ? 1 : 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const _CardBack(width: 46, height: 66),
                    if (mustDraw)
                      Positioned(
                        top: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text('Draw $pendingDraw',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('$drawPileCount left',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 10.5)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (discardTop != null)
                  _CardFace(
                      card: discardTop, width: 52, height: 76, fontSize: 22)
                else
                  Container(
                    width: 52,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, width: 2),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('—',
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                if (currentColor != null)
                  Positioned(
                    bottom: -6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: _colorHex[currentColor],
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(currentColor != null ? _colorName[currentColor]! : '',
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 10.5)),
          ],
        ),
      ],
    );

    // Opponents sit around the top of an oval table (left, over the top,
    // to the right), the piles in the middle, you at the bottom.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameStatusLine(statusText(), highlight: status != 'waiting'),
        SizedBox(
          height: 250,
          child: Stack(
            children: [
              Positioned.fill(
                top: 34,
                bottom: 10,
                left: 6,
                right: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.7),
                    borderRadius:
                        const BorderRadius.all(Radius.elliptical(400, 200)),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
              ),
              Align(alignment: const Alignment(0, 0.35), child: pile),
              for (var i = 0; i < opponents.length; i++)
                Builder(builder: (context) {
                  final a =
                      math.pi + math.pi * (i + 1) / (opponents.length + 1);
                  return Align(
                    alignment:
                        Alignment(math.cos(a) * 0.92, math.sin(a) * 1.0 + 0.1),
                    child: opponentSeat(opponents[i]),
                  );
                }),
              if (opponents.isEmpty && status == 'waiting')
                const Align(
                    alignment: Alignment(0, -0.9),
                    child: GameOpenSeat(size: 28)),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Join / play again
        Center(
            child: GameJoinButton(
                seated: isPlayer,
                full: players.length >= 6 || status == 'won',
                fallbackJoin: onJoin)),
        if (isHost && status == 'won')
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              onPressed: onReset,
              child: const Text('Play again', style: TextStyle(fontSize: 12)),
            ),
          ),
        const SizedBox(height: 8),

        // My hand
        if (isPlayer)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('You · ${hand.length} cards',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    if (hand.length == 1 && unoFlags[myUserId] != true)
                      GestureDetector(
                        onTap: () => onMove({'action': 'callUno'}),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('UNO!',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final card in hand)
                        Builder(builder: (context) {
                          final legal = isMyTurn &&
                              !mustDraw &&
                              _isLegalPlay(card, discardTop, currentColor);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: legal ? () => playCard(card) : null,
                              child: Opacity(
                                  opacity: legal ? 1 : 0.4,
                                  child: _CardFace(card: card)),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
