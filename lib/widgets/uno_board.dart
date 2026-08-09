import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
const Map<String, String> _colorName = {'red': 'Red', 'yellow': 'Yellow', 'green': 'Green', 'blue': 'Blue'};

bool _isLegalPlay(Map card, Map? topCard, String? currentColor) {
  if (topCard == null) return true;
  if (card['color'] == 'wild') return true;
  if (card['color'] == currentColor) return true;
  if (card['type'] == 'number' && topCard['type'] == 'number' && card['value'] == topCard['value']) return true;
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
  const _CardFace({required this.card, this.width = 46, this.height = 68, this.fontSize = 19});

  @override
  Widget build(BuildContext context) {
    final isWild = card['color'] == 'wild';
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        gradient: isWild ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A1A), Color(0xFF333333)]) : null,
        color: isWild ? null : _colorHex[card['color']],
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
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
                      children: _colors.map((c) => Container(color: _colorHex[c])).toList(),
                    ),
                  ),
                ),
              ),
            ),
          Text(
            _cardLabel(card),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize, shadows: const [Shadow(color: Colors.black45, blurRadius: 3)]),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2A2A), Color(0xFF111111)]),
      ),
      child: Text('U', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w900, fontSize: 10)),
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
            const Text('Choose a color', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
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
                    decoration: BoxDecoration(color: _colorHex[c], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2)),
                    child: Text(_colorName[c]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
    final currentPlayer = players.isNotEmpty && currentPlayerIndex < players.length ? players[currentPlayerIndex] : null;
    final winner = game['winner'] as String?;
    final winnerPlayer = winner != null ? players.cast<Map?>().firstWhere((p) => p?['userId'] == winner, orElse: () => null) : null;
    final hand = (game['hand'] as List? ?? []).cast<Map>();
    final discardTop = game['discardTop'] as Map?;
    final currentColor = game['currentColor'] as String?;
    final drawPileCount = game['drawPileCount'] as int? ?? 0;
    final pendingDraw = game['pendingDraw'] as int? ?? 0;
    final unoFlags = Map<String, dynamic>.from(game['unoFlags'] as Map? ?? {});
    final me = players.cast<Map?>().firstWhere((p) => p?['userId'] == myUserId, orElse: () => null);
    final isPlayer = me != null;
    final isMyTurn = isPlayer && status == 'playing' && currentPlayer?['userId'] == myUserId;
    final mustDraw = isMyTurn && pendingDraw > 0;

    String statusText() {
      if (status == 'won') return "${winnerPlayer?['name'] ?? 'Someone'} won! 🎉";
      if (players.length < 2) return 'Waiting for more players… (up to 6)';
      if (currentPlayer == null) return '';
      if (mustDraw) return isMyTurn ? 'Draw $pendingDraw — tap the deck.' : "${currentPlayer['name']} must draw $pendingDraw.";
      if (isMyTurn) return 'Your turn — play a card or draw.';
      return "${currentPlayer['name']}'s turn";
    }

    Future<void> playCard(Map card) async {
      if (!isMyTurn || mustDraw) return;
      if (!_isLegalPlay(card, discardTop, currentColor)) return;
      if (card['color'] == 'wild') {
        final color = await showDialog<String>(context: context, builder: (_) => const _ColorPickerDialog());
        if (color != null) onMove({'action': 'play', 'cardId': card['id'], 'chosenColor': color});
        return;
      }
      onMove({'action': 'play', 'cardId': card['id']});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Opponents strip
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in players)
                if (p['userId'] != myUserId)
                  Builder(builder: (context) {
                    final isTurn = status == 'playing' && currentPlayer?['userId'] == p['userId'];
                    final handCount = p['handCount'] as int? ?? 0;
                    final showUno = handCount == 1 && unoFlags[p['userId']] != true;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isTurn ? AppColors.primary : AppColors.border, width: isTurn ? 1.5 : 1),
                        boxShadow: isTurn ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10)] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _CardBack(width: 18, height: 26),
                          const SizedBox(width: 6),
                          Text('${p['name']} · $handCount', style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (showUno) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => onMove({'action': 'catchUno', 'targetUserId': p['userId']}),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
                                child: const Text('Catch!', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Table
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: isMyTurn ? () => onMove({'action': 'draw'}) : null,
                child: Opacity(
                  opacity: isMyTurn ? 1 : 0.5,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          const _CardBack(width: 54, height: 78),
                          if (mustDraw)
                            Positioned(
                              top: -12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                                child: Text('Draw $pendingDraw', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('$drawPileCount left', style: const TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (discardTop != null)
                        _CardFace(card: discardTop, width: 64, height: 92, fontSize: 26)
                      else
                        Container(
                          width: 64,
                          height: 92,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 2), borderRadius: BorderRadius.circular(8)),
                          child: const Text('—', style: TextStyle(color: AppColors.textFaint)),
                        ),
                      if (currentColor != null)
                        Positioned(
                          bottom: -6,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: _colorHex[currentColor], shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.7))),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(currentColor != null ? _colorName[currentColor]! : '', style: const TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Status + join/reset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(child: Text(statusText(), style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600))),
              if (!isPlayer && players.length < 6 && status != 'won')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  onPressed: onJoin,
                  child: const Text('Join game', style: TextStyle(fontSize: 12)),
                ),
              if (isHost && status == 'won')
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  onPressed: onReset,
                  child: const Text('Play again', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // My hand
        if (isPlayer)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Your hand (${hand.length})', style: const TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w500)),
                    if (hand.length == 1 && unoFlags[myUserId] != true)
                      GestureDetector(
                        onTap: () => onMove({'action': 'callUno'}),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                          child: const Text('UNO!', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
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
                          final legal = isMyTurn && !mustDraw && _isLegalPlay(card, discardTop, currentColor);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: legal ? () => playCard(card) : null,
                              child: Opacity(opacity: legal ? 1 : 0.4, child: _CardFace(card: card)),
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
