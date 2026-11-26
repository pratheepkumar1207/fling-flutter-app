import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/insync_icons.dart';
import '../wallet/vip_store_screen.dart';
import 'discover_ui.dart';

/// "You've used today's likes" (or super likes). [limits] is what the
/// server sent with the 429 (see GET /swipe/limits).
Future<void> showOutOfLikesSheet(BuildContext context, Map limits,
    {bool superLike = false}) {
  final reset = DateTime.tryParse('${limits['resetAt'] ?? ''}')?.toLocal();
  String left() {
    if (reset == null) return 'tomorrow';
    final d = reset.difference(DateTime.now());
    if (d.isNegative) return 'a moment';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  final perDay = superLike ? limits['superLikesPerDay'] : limits['likesPerDay'];
  final vip = limits['vip'] == true;
  return showModalBottomSheet(
    context: context,
    backgroundColor: DColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(76, 76), painter: _UsedRing()),
              InIcon(superLike ? InIcons.star : InIcons.heart,
                  size: 28, color: Colors.white, filled: true),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
              superLike
                  ? 'You’ve used today’s ${perDay != null ? '$perDay ' : ''}super likes'
                  : 'You’ve used today’s ${perDay != null ? '$perDay ' : ''}likes',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'More in '),
                TextSpan(
                    text: left(), style: const TextStyle(color: Colors.white)),
              ]),
              style: const TextStyle(color: DColors.dim, fontSize: 13)),
          if (!vip) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Perk('Unlimited likes'),
                    _Perk('See everyone who liked you'),
                    _Perk('Free rewind and 5 super likes a day'),
                  ]),
            ),
            const SizedBox(height: 14),
            DButton('Get VIP', icon: InIcons.crown, kind: DButtonKind.white,
                onPressed: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VipStoreScreen()));
            }),
          ],
          TextButton(
            onPressed: () => Navigator.of(sheet).pop(),
            child: Text(vip ? 'OK' : 'Wait for tomorrow',
                style: const TextStyle(color: DColors.dim)),
          ),
        ]),
      ),
    ),
  );
}

class _Perk extends StatelessWidget {
  final String text;
  const _Perk(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const InIcon(InIcons.check, size: 16, color: DColors.red),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ]),
      );
}

class _UsedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        r, 0, math.pi * 2, false, p..color = const Color(0xFF2A2A2A));
    canvas.drawArc(
        r, -math.pi / 2, math.pi * 2 * 0.999, false, p..color = DColors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The boost sheet: one boost, or a pack (one used now, the rest kept).
/// Returns the new "boosted until", or null when nothing was bought.
Future<DateTime?> showBoostSheet(BuildContext context) async {
  Map info;
  try {
    info = await ApiClient.get('/discover/boost') as Map;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t load boosts. Try again.')));
    }
    return null;
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: DColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _BoostSheet(info: info),
  );
}

class _BoostSheet extends StatefulWidget {
  final Map info;
  const _BoostSheet({required this.info});
  @override
  State<_BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends State<_BoostSheet> {
  bool _pack = false;
  bool _busy = false;
  String? _error;

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ApiClient.post('/discover/boost',
          body: {if (_pack) 'pack': true}) as Map;
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      Navigator.of(context).pop(DateTime.tryParse('${r['boostedUntil']}'));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t boost right now. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    final credits = (i['credits'] as num?)?.toInt() ?? 0;
    final minutes = i['minutes'] ?? 30;
    final until = DateTime.tryParse('${i['boostedUntil'] ?? ''}');
    final label = credits > 0
        ? 'Boost now · use 1 of $credits'
        : _pack
            ? 'Buy ${i['packSize']} boosts · ${i['packCost']} coins'
            : 'Boost now · ${i['cost']} coins';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          Container(
            width: 60,
            height: 60,
            decoration:
                const BoxDecoration(color: DColors.red, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const InIcon(InIcons.bolt,
                size: 30, color: Colors.white, filled: true),
          ),
          const SizedBox(height: 12),
          Text('Be seen first for $minutes minutes',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              until != null && until.isAfter(DateTime.now())
                  ? 'You’re boosted now. A new boost adds $minutes more minutes.'
                  : 'You go to the top of Discover and the map nearby.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DColors.dim, fontSize: 13)),
          const SizedBox(height: 16),
          if (credits == 0)
            Row(children: [
              Expanded(
                  child: _option('1 boost', '${i['cost']}', !_pack,
                      () => setState(() => _pack = false))),
              const SizedBox(width: 10),
              Expanded(
                  child: _option('${i['packSize']} boosts', '${i['packCost']}',
                      _pack, () => setState(() => _pack = true),
                      badge: 'Best')),
            ])
          else
            Text('You have $credits boost${credits == 1 ? '' : 's'} left.',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: DColors.redSoft, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          DButton(label, busy: _busy, onPressed: _buy),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Not now', style: TextStyle(color: DColors.dim))),
        ]),
      ),
    );
  }

  Widget _option(String title, String coins, bool on, VoidCallback tap,
      {String? badge}) {
    return GestureDetector(
      onTap: tap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: on ? DColors.red : const Color(0xFF333333),
                width: on ? 1.6 : 0.8),
          ),
          child: Column(children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const InIcon(InIcons.wallet, size: 13, color: DColors.dim),
              const SizedBox(width: 4),
              Text('$coins coins',
                  style: const TextStyle(color: DColors.dim, fontSize: 12)),
            ]),
          ]),
        ),
        if (badge != null)
          Positioned(
              top: -9,
              left: 0,
              right: 0,
              child:
                  Center(child: DChip(badge, tone: DTone.red, fontSize: 11))),
      ]),
    );
  }
}

/// The red "Boost active 18:42" strip shown above the deck while a boost runs.
class BoostBanner extends StatefulWidget {
  final DateTime until;
  final VoidCallback onEnded;
  const BoostBanner({super.key, required this.until, required this.onEnded});
  @override
  State<BoostBanner> createState() => _BoostBannerState();
}

class _BoostBannerState extends State<BoostBanner> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(widget.until)) {
        widget.onEnded();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DColors.redTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DColors.red, width: 0.8),
      ),
      child: Row(children: [
        const InIcon(InIcons.bolt, size: 18, color: DColors.red, filled: true),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Boost active · you’re shown first',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text(left.isNegative ? '00:00' : '$mm:$ss',
            style: const TextStyle(
                color: DColors.redSoft,
                fontWeight: FontWeight.w700,
                fontFeatures: [])),
      ]),
    );
  }
}
