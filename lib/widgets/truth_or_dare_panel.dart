import 'dart:math';
import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

const _kSeatColors = [Color(0xFFFF3D78), Color(0xFFFFC93C), Color(0xFF38E6C5), Color(0xFF8B7BFF), Color(0xFFFF8A3D), Color(0xFF4DC4FF)];
const _kSpinDuration = Duration(milliseconds: 3200);
const _kTableRadius = 78.0;

/// Presentational only — turn selection (the "spin the bottle" random pick)
/// and prompt selection both happen server-side in src/games/truthOrDare.js;
/// this just renders whatever `game` state the server last broadcast, and
/// plays a local bottle-spin animation toward the new turn whenever it
/// changes so the reveal feels like an actual spin rather than a jump-cut.
class TruthOrDarePanel extends StatefulWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;

  const TruthOrDarePanel({super.key, required this.game, required this.myUserId, required this.onJoin, required this.onMove});

  @override
  State<TruthOrDarePanel> createState() => _TruthOrDarePanelState();
}

class _TruthOrDarePanelState extends State<TruthOrDarePanel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _fromAngle = 0;
  double _toAngle = 0;
  String? _prevTurn;
  String? _displayTurn;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _prevTurn = widget.game['turn'] as String?;
    _displayTurn = _prevTurn;
    _controller = AnimationController(vsync: this, duration: _kSpinDuration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _spinning = false;
            _displayTurn = widget.game['turn'] as String?;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant TruthOrDarePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTurn = widget.game['turn'] as String?;
    if (newTurn == _prevTurn) return;
    _prevTurn = newTurn;
    final players = (widget.game['players'] as List? ?? []).cast<Map>();
    final idx = players.indexWhere((p) => p['userId'] == newTurn);
    if (newTurn == null || players.isEmpty || idx == -1) {
      setState(() => _displayTurn = newTurn);
      return;
    }
    final n = players.length;
    final seatAngle = (360 / n) * idx - 90;
    final targetRotation = seatAngle + 90;
    final extraSpins = 4 + Random().nextInt(3);
    _fromAngle = _toAngle;
    _toAngle = _fromAngle + extraSpins * 360 + (targetRotation - (_fromAngle % 360));
    setState(() => _spinning = true);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final players = (game['players'] as List? ?? []).cast<Map>();
    final status = game['status'] as String? ?? 'waiting';
    final prompt = game['currentPrompt'] as Map?;
    final isPlayer = players.any((p) => p['userId'] == widget.myUserId);
    final isMyTurn = isPlayer && status == 'playing' && _displayTurn == widget.myUserId && !_spinning;
    final currentPlayer = players.cast<Map?>().firstWhere((p) => p?['userId'] == _displayTurn, orElse: () => null);
    final n = players.length;

    final eased = Curves.easeOutCubic.transform(_controller.value);
    final currentAngle = _fromAngle + (_toAngle - _fromAngle) * eased;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.all(12),
        child: status == 'waiting'
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      for (final p in players)
                        GestureDetector(
                          onTap: () => openProfile(context, p['userId'] as String?),
                          child: Column(
                            children: [
                              Avatar(name: p['name'] as String?, size: AvatarSize.sm),
                              Text(p['name'] as String? ?? '', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Waiting for a second player…', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  if (!isPlayer)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton(onPressed: widget.onJoin, child: const Text('Join game')),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _kTableRadius * 2 + 60,
                    height: _kTableRadius * 2 + 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: _kTableRadius * 2,
                          height: _kTableRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                            gradient: RadialGradient(colors: [AppColors.surface3, AppColors.surface], center: const Alignment(-0.3, -0.4)),
                          ),
                        ),
                        for (var i = 0; i < n; i++)
                          Builder(builder: (context) {
                            final p = players[i];
                            final angle = (360 / n) * i - 90;
                            final rad = angle * pi / 180;
                            final x = cos(rad) * _kTableRadius;
                            final y = sin(rad) * _kTableRadius;
                            final chosen = !_spinning && p['userId'] == _displayTurn;
                            return Transform.translate(
                              offset: Offset(x, y),
                              child: SizedBox(
                                width: 64,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => openProfile(context, p['userId'] as String?),
                                      child: Avatar(name: p['name'] as String?, size: AvatarSize.sm),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: chosen ? AppColors.primary : AppColors.surface2,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: _kSeatColors[i % _kSeatColors.length]),
                                        boxShadow: chosen ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 12)] : null,
                                      ),
                                      child: Text(
                                        p['name'] as String? ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: chosen ? Colors.white : AppColors.textDim),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        Transform.rotate(
                          angle: currentAngle * pi / 180,
                          alignment: const Alignment(0, 0.85),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 14, decoration: const BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
                              Container(
                                width: 22,
                                height: 56,
                                decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_spinning) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Spinning…', style: TextStyle(color: AppColors.textFaint, fontSize: 11))),
                  if (!_spinning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: prompt == null
                          ? (isMyTurn
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => widget.onMove({'action': 'choose', 'choice': 'truth'}),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                      child: const Text('🤔 Truth'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => widget.onMove({'action': 'choose', 'choice': 'dare'}),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                      child: const Text('🔥 Dare'),
                                    ),
                                  ],
                                )
                              : Text('Waiting for ${currentPlayer?['name'] ?? 'them'} to choose…', style: const TextStyle(color: AppColors.textDim, fontSize: 13)))
                          : Column(
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
                                    child: ElevatedButton(
                                      onPressed: () => widget.onMove({'action': 'next'}),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF241A0A)),
                                      child: const Text('🍾 Spin the bottle'),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  if (!isPlayer)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton(onPressed: widget.onJoin, child: const Text('Join game')),
                    ),
                ],
              ),
      ),
    );
  }
}
