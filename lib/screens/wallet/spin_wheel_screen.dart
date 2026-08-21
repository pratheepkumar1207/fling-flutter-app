import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

const _kCooldown = Duration(hours: 24);

/// Daily spin wheel — matches SpinWheelDark.dc.html. All backend logic
/// already existed (POST /wallet/spin, 7 weighted reward tiers) but only
/// wallet_screen.dart's plain "Daily spin" tile called it directly with no
/// visual wheel; this gives it a dedicated screen with an actual spinning
/// wheel. New: lastSpinAt now returned from GET /auth/me (for the cooldown
/// state on load) and GET /wallet/spin-history (for "Recent wins").
class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _rotation;
  bool _spinning = false;
  int? _lastWin;
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = true;

  static const _segmentColors = [
    AppColors.accent,
    AppColors.gold,
    AppColors.accent2,
    AppColors.success,
    AppColors.accent,
    AppColors.gold,
    AppColors.accent2,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _rotation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await ApiClient.get('/wallet/spin-history');
      if (!mounted) return;
      setState(() {
        _history = (data as List).cast<Map<String, dynamic>>();
        _historyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  DateTime? get _lastSpinAt => context.read<AuthProvider>().user?.lastSpinAt;

  bool get _canSpin {
    final last = _lastSpinAt;
    return last == null || DateTime.now().difference(last) >= _kCooldown;
  }

  Duration get _timeUntilNextSpin {
    final last = _lastSpinAt;
    if (last == null) return Duration.zero;
    final remaining = _kCooldown - DateTime.now().difference(last);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _spin() async {
    if (_spinning || !_canSpin) return;
    setState(() {
      _spinning = true;
      _lastWin = null;
    });
    try {
      final res = await ApiClient.post('/wallet/spin') as Map<String, dynamic>;
      final coinsWon = res['coinsWon'] as int;
      final rand = Random();
      final targetTurns = 6 + rand.nextInt(3);
      final targetAngle = targetTurns * 2 * pi + rand.nextDouble() * 2 * pi;
      _rotation = Tween<double>(begin: _rotation.value, end: _rotation.value + targetAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
      await Future.delayed(const Duration(milliseconds: 2400));
      if (!mounted) return;
      setState(() => _lastWin = coinsWon);
      await context.read<AuthProvider>().refreshUser();
      _loadHistory();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spin failed')));
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final canSpin = _canSpin && !_spinning;
    return Scaffold(
      backgroundColor: const Color(0xFF241D33),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Daily Spin', style: TextStyle(color: Colors.white))),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _rotation,
                          builder: (context, child) => Transform.rotate(angle: _rotation.value, child: child),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(colors: [..._segmentColors, _segmentColors.first]),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 6),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 20))],
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))]),
                          alignment: Alignment.center,
                          child: const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 24),
                        ),
                        const Positioned(
                          top: -6,
                          child: Icon(Icons.arrow_drop_down_rounded, color: AppColors.gold, size: 46),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (_lastWin != null)
                    Text('You won 🪙 $_lastWin coins!', style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700))
                  else if (!canSpin && !_spinning)
                    Text('Next free spin in ${_formatCountdown(_timeUntilNextSpin)}', style: const TextStyle(color: Colors.white70, fontSize: 12.5))
                  else
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                        children: const [TextSpan(text: 'You have '), TextSpan(text: '1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), TextSpan(text: ' free spin today')],
                      ),
                    ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: canSpin ? _spin : null,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: canSpin ? const LinearGradient(colors: AppGradients.brand) : null,
                        color: canSpin ? null : Colors.white.withValues(alpha: 0.08),
                        boxShadow: canSpin ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 26, offset: const Offset(0, 10))] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _spinning ? 'Spinning…' : 'Spin now',
                        style: TextStyle(color: canSpin ? Colors.white : Colors.white38, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RECENT WINS', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 10),
                if (_historyLoading)
                  const Center(child: Spinner(size: 18))
                else if (_history.isEmpty)
                  const Text('No spins yet.', style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  Row(
                    children: _history.take(3).map((h) {
                      final coins = (h['coins'] as num?)?.toInt() ?? 0;
                      final date = DateTime.tryParse(h['createdAt']?.toString() ?? '');
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Text(date != null ? formatRelativeTime(date) : '', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9.5)),
                              Text('+$coins', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
