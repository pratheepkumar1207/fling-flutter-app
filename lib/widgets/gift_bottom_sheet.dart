import '../theme/insync_icons.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/auth_provider.dart';
import '../core/format.dart';
import '../models/gift.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';
import 'spinner.dart';
import '../screens/wallet/wallet_buy_screen.dart';

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
    builder: (_) => _GiftSheet(
        toUserId: toUserId,
        roomId: roomId,
        onSent: onSent,
        targetKey: targetKey),
  );
}

class _GiftSheet extends StatefulWidget {
  final String toUserId;
  final String? roomId;
  final VoidCallback? onSent;
  final GlobalKey? targetKey;
  const _GiftSheet(
      {required this.toUserId, this.roomId, this.onSent, this.targetKey});

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  String? _sending;
  List<Gift>? _gifts;
  Gift? _selected;
  String _tab = 'popular';
  int _qty = 1;
  // Same gift sent again within a few seconds builds a combo.
  String? _comboType;
  int _combo = 0;
  DateTime _comboAt = DateTime(2000);

  static const _tabs = [
    ('popular', 'Popular'),
    ('lucky', 'Lucky'),
    ('love', 'Love'),
    ('fan', 'Fan club'),
  ];
  // Kept alive across rebuilds (not recreated per-build) so a tile's
  // GlobalKey still resolves to its live Element after selecting it
  // triggers a setState — matches GiftSheetDark.dc.html's select-then-
  // confirm flow (tap a tile to highlight it, tap the CTA to actually send).
  final Map<String, GlobalKey> _tileKeys = {};

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final data = await ApiClient.get('/wallet/gifts');
      if (!mounted) return;
      final gifts = (data as List)
          .map((e) => Gift.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final g in gifts) {
        _tileKeys[g.id] = GlobalKey();
      }
      setState(() => _gifts = gifts);
    } catch (_) {
      if (mounted) setState(() => _gifts = []);
    }
  }

  Future<void> _send(Gift gift, GlobalKey tileKey) async {
    if (_sending != null) return;
    setState(() => _sending = gift.type);
    final messenger = ScaffoldMessenger.of(context);

    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox;
    final tileBox = tileKey.currentContext?.findRenderObject() as RenderBox?;
    final srcGlobal = tileBox != null
        ? tileBox.localToGlobal(tileBox.size.center(Offset.zero))
        : overlayBox.size.center(Offset.zero);
    final localSrc = overlayBox.globalToLocal(srcGlobal);

    final targetBox =
        widget.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final localTarget = targetBox != null
        ? overlayBox.globalToLocal(
            targetBox.localToGlobal(targetBox.size.center(Offset.zero)))
        : Offset(overlayBox.size.width / 2, 24);

    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _CoinBurst(
            source: localSrc,
            target: localTarget,
            onDone: () => entry.remove()));
    overlayState.insert(entry);

    try {
      // No `coins` in the body — the server looks up the price from the
      // Gift catalog by type, not from whatever the client sends.
      await ApiClient.post('/wallet/gift', body: {
        'roomId': widget.roomId,
        'toUserId': widget.toUserId,
        'giftType': gift.type,
        'quantity': _qty,
      });
      widget.onSent?.call();
      if (mounted) context.read<AuthProvider>().refreshUser();
      final now = DateTime.now();
      final again =
          _comboType == gift.type && now.difference(_comboAt).inSeconds < 6;
      _combo = again ? _combo + 1 : 1;
      _comboType = gift.type;
      _comboAt = now;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(_combo >= 3
              ? 'Combo ×$_combo! ${gift.emoji}'
              : 'Sent ${gift.name}${_qty > 1 ? ' ×$_qty' : ''}')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    // The sheet stays open so you can keep sending (and build a combo).
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _sending = null);
  }

  // Deterministic per-gift glossy gradient (matches GiftSheetDark.dc.html's
  // distinct color per gift icon, since the catalog has no color field).
  static const _giftGradients = [
    [Color(0xFFE0A3A8), Color(0xFFC13750)],
    [Color(0xFFE8CB8F), Color(0xFFB5893A)],
    [Color(0xFFD9B08F), Color(0xFF8F5A38)],
    [Color(0xFFCC9DE8), Color(0xFF8F5AB0)],
    [Color(0xFFE8D89D), Color(0xFFC9A23F)],
    [Color(0xFF9DC5E8), Color(0xFF5A8FC1)],
    [Color(0xFFE8B0A3), Color(0xFFB55A3E)],
  ];

  @override
  Widget build(BuildContext context) {
    final coinBalance = context.watch<AuthProvider>().user?.coinBalance ?? 0;
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
                child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999))),
              ),
              Row(
                children: [
                  const Text('Send a gift',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const InIcon(InIcons.cash,
                          color: AppColors.gold, size: 14),
                      const SizedBox(width: 5),
                      Text(formatNumber(coinBalance),
                          style: const TextStyle(
                              color: AppColors.textDim,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const WalletBuyScreen())),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(44, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text('Top up',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (_combo >= 2 && _comboType != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.pink,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('Combo ×$_combo',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              const SizedBox(height: 16),
              if (_gifts == null)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Spinner(size: 20)))
              else if (_gifts!.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('No gifts available right now.',
                            style: TextStyle(color: AppColors.textFaint))))
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final (id, label) in _tabs)
                      if (_gifts!.any((g) => g.category == id))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _tab == id,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _tab = id),
                          ),
                        ),
                  ]),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.8,
                  children: (_gifts!.any((g) => g.category == _tab)
                          ? _gifts!.where((g) => g.category == _tab).toList()
                          : _gifts!)
                      .asMap()
                      .entries
                      .map((entry) {
                    final gift = entry.value;
                    final tileKey = _tileKeys[gift.id] ??= GlobalKey();
                    final disabled = _sending != null;
                    final selected = _selected?.id == gift.id;
                    final gradient =
                        _giftGradients[entry.key % _giftGradients.length];
                    return GestureDetector(
                      key: tileKey,
                      onTap: disabled
                          ? null
                          : () => setState(() => _selected = gift),
                      child: Opacity(
                        opacity: disabled ? 0.5 : 1,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: gradient),
                                  border: selected
                                      ? Border.all(
                                          color: AppColors.accent, width: 2)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            gradient[1].withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6))
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(gift.emoji,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                              if (gift.tag != null)
                                Positioned(
                                  top: -4,
                                  right: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: gift.tag == 'LUCKY'
                                            ? AppColors.success
                                            : gift.tag == 'NEW'
                                                ? AppColors.blue
                                                : AppColors.pink,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(gift.tag!,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 4),
                            Text(gift.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: selected
                                        ? AppColors.text
                                        : AppColors.textDim,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600)),
                            Text('${gift.coins}',
                                style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text(
                    'Send 3 in a row for a combo. Big gifts play full-screen for everyone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim, fontSize: 11.5)),
                const SizedBox(height: 10),
                Row(children: [
                  for (final q in const [1, 10, 99])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('×$q'),
                        selected: _qty == q,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _qty = q),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: (_selected == null || _sending != null)
                      ? null
                      : () => _send(_selected!, _tileKeys[_selected!.id]!),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: (_selected == null || _sending != null)
                          ? null
                          : const LinearGradient(colors: AppGradients.brand),
                      color: (_selected == null || _sending != null)
                          ? AppColors.surface2
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selected == null
                          ? 'Pick a gift'
                          : 'Send ${_selected!.name}${_qty > 1 ? ' ×$_qty' : ''} — ${_selected!.coins * _qty} coins',
                      style: TextStyle(
                          color: (_selected == null || _sending != null)
                              ? AppColors.textFaint
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5),
                    ),
                  ),
                ),
              ],
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
  const _CoinBurst(
      {required this.source, required this.target, required this.onDone});

  @override
  State<_CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<_CoinBurst>
    with SingleTickerProviderStateMixin {
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
              final t = (_controller.value - coin.delay).clamp(0.0, 1.0) /
                  (1 - coin.delay).clamp(0.001, 1.0);
              final phase1 = (t / 0.15).clamp(0.0, 1.0); // pop in
              final phase2 =
                  ((t - 0.15) / 0.25).clamp(0.0, 1.0); // burst outward
              final phase3 =
                  ((t - 0.40) / 0.60).clamp(0.0, 1.0); // fly to target

              final scale = t < 0.15
                  ? lerpDouble(0.5, 1.15, phase1)
                  : t < 0.40
                      ? lerpDouble(1.15, 1.0, phase2)
                      : lerpDouble(1.0, 0.25, phase3);
              final opacity = t < 0.15
                  ? phase1
                  : (1 - (t >= 0.40 ? phase3 : 0.0)).clamp(0.0, 1.0);
              final pos = t < 0.40
                  ? coin.burst * phase2.clamp(0.0, 1.0) * (t < 0.15 ? 0.0 : 1.0)
                  : Offset.lerp(coin.burst, coin.target, phase3)!;
              final rotation = t < 0.40
                  ? lerpDouble(0, 200, (t / 0.40).clamp(0.0, 1.0))!
                  : lerpDouble(200, 560, phase3)!;

              return Positioned(
                left: widget.source.dx + pos.dx - 12,
                top: widget.source.dy + pos.dy - 12,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rotation * pi / 180,
                    child: Transform.scale(
                        scale: scale,
                        child:
                            const Text('🪙', style: TextStyle(fontSize: 22))),
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
