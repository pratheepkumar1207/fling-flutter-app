import 'dart:math';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

class _GiftDef {
  final String type;
  final String label;
  final String name;
  final int coins;
  const _GiftDef(this.type, this.label, this.name, this.coins);
}

const _kGifts = [
  _GiftDef('rose', '🌹', 'Rose', 10),
  _GiftDef('heart', '💖', 'Heart', 25),
  _GiftDef('star', '🌟', 'Star', 50),
  _GiftDef('crown', '👑', 'Crown', 100),
  _GiftDef('diamond', '💎', 'Diamond', 500),
  _GiftDef('rocket', '🚀', 'Rocket', 1000),
];

const _kAnimDuration = Duration(milliseconds: 1000);
const _kCoinCount = 10;
const _kBurstRadius = 55.0;

/// Bottom sheet for sending a gift — Dart port of GiftModal.jsx, presented
/// as a sheet (`showGiftBottomSheet`) rather than a centered dialog to match
/// the app's "spatial UI" bottom-sheet convention. [targetKey] should be
/// attached to whatever on-screen widget represents "the collector's
/// profile" (their avatar) — tapping a gift bursts coins from that gift
/// tile and flies them into that widget; falls back to the top-center of
/// the screen if not given.
Future<void> showGiftBottomSheet(
  BuildContext context, {
  required String toUserId,
  String? roomId,
  VoidCallback? onSent,
  GlobalKey? targetKey,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GiftSheet(toUserId: toUserId, roomId: roomId, onSent: onSent, targetKey: targetKey),
  );
}

class _GiftSheet extends StatefulWidget {
  final String toUserId;
  final String? roomId;
  final VoidCallback? onSent;
  final GlobalKey? targetKey;
  const _GiftSheet({required this.toUserId, this.roomId, this.onSent, this.targetKey});

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  String? _sending;

  Future<void> _send(_GiftDef gift, GlobalKey tileKey) async {
    if (_sending != null) return;
    setState(() => _sending = gift.type);
    final messenger = ScaffoldMessenger.of(context);

    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox;
    final tileBox = tileKey.currentContext?.findRenderObject() as RenderBox?;
    final srcGlobal = tileBox != null ? tileBox.localToGlobal(tileBox.size.center(Offset.zero)) : overlayBox.size.center(Offset.zero);
    final localSrc = overlayBox.globalToLocal(srcGlobal);

    final targetBox = widget.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final localTarget = targetBox != null
        ? overlayBox.globalToLocal(targetBox.localToGlobal(targetBox.size.center(Offset.zero)))
        : Offset(overlayBox.size.width / 2, 24);

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _CoinBurst(source: localSrc, target: localTarget, onDone: () => entry.remove()));
    overlayState.insert(entry);

    try {
      await ApiClient.post('/wallet/gift', body: {'roomId': widget.roomId, 'toUserId': widget.toUserId, 'coins': gift.coins, 'giftType': gift.type});
      widget.onSent?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }

    await Future.delayed(_kAnimDuration + const Duration(milliseconds: 100));
    if (mounted) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Sent a ${gift.name}!')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassSurface(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
            ),
            const Text('Send a gift', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: _kGifts.map((gift) {
                final tileKey = GlobalKey();
                final disabled = _sending != null;
                return GestureDetector(
                  key: tileKey,
                  onTap: disabled ? null : () => _send(gift, tileKey),
                  child: Opacity(
                    opacity: disabled ? 0.5 : 1,
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.label, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 2),
                          Text(gift.name, style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text('${gift.coins} coins', style: const TextStyle(color: AppColors.gold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Coin {
  final Offset burst;
  final Offset target;
  final double delay;
  _Coin({required this.burst, required this.target, required this.delay});
}

/// Full-screen overlay: coins burst a short distance from [source] (0→40%
/// of the animation), then arc into [target] and shrink away (40%→100%) —
/// same three-phase timeline as the web app's `coin-fly` CSS keyframes.
class _CoinBurst extends StatefulWidget {
  final Offset source;
  final Offset target;
  final VoidCallback onDone;
  const _CoinBurst({required this.source, required this.target, required this.onDone});

  @override
  State<_CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<_CoinBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Coin> _coins;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _coins = List.generate(_kCoinCount, (i) {
      final angle = (i / _kCoinCount) * 2 * pi + rand.nextDouble() * 0.6;
      final radius = _kBurstRadius * (0.6 + rand.nextDouble() * 0.5);
      return _Coin(
        burst: Offset(cos(angle) * radius, sin(angle) * radius),
        target: widget.target - widget.source,
        delay: rand.nextDouble() * 0.12,
      );
    });
    _controller = AnimationController(vsync: this, duration: _kAnimDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: _coins.map((coin) {
              final t = (_controller.value - coin.delay).clamp(0.0, 1.0) / (1 - coin.delay).clamp(0.001, 1.0);
              final phase1 = (t / 0.15).clamp(0.0, 1.0); // pop in
              final phase2 = ((t - 0.15) / 0.25).clamp(0.0, 1.0); // burst outward
              final phase3 = ((t - 0.40) / 0.60).clamp(0.0, 1.0); // fly to target

              final scale = t < 0.15
                  ? lerpDouble(0.5, 1.15, phase1)
                  : t < 0.40
                      ? lerpDouble(1.15, 1.0, phase2)
                      : lerpDouble(1.0, 0.25, phase3);
              final opacity = t < 0.15 ? phase1 : (1 - (t >= 0.40 ? phase3 : 0.0)).clamp(0.0, 1.0);
              final pos = t < 0.40 ? coin.burst * phase2.clamp(0.0, 1.0) * (t < 0.15 ? 0.0 : 1.0) : Offset.lerp(coin.burst, coin.target, phase3)!;
              final rotation = t < 0.40 ? lerpDouble(0, 200, (t / 0.40).clamp(0.0, 1.0))! : lerpDouble(200, 560, phase3)!;

              return Positioned(
                left: widget.source.dx + pos.dx - 12,
                top: widget.source.dy + pos.dy - 12,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rotation * pi / 180,
                    child: Transform.scale(scale: scale, child: const Text('🪙', style: TextStyle(fontSize: 22))),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
