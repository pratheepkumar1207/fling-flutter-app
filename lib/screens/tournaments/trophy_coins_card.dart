import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';

const _gold = Color(0xFFFAC775);
const _goldLine = Color(0xFFBA7517);

/// 🏆 Trophy coins — won in tournaments, only spent on VIP, never gifted or
/// withdrawn. In the wallet it shows the balance; in the VIP store
/// (`store: true`) it also offers VIP for Trophy coins.
class TrophyCoinsCard extends StatefulWidget {
  final bool store;
  const TrophyCoinsCard({super.key, this.store = false});

  @override
  State<TrophyCoinsCard> createState() => _TrophyCoinsCardState();
}

class _TrophyCoinsCardState extends State<TrophyCoinsCard> {
  Map<String, dynamic>? _w;
  int? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/tournaments/trophy');
      if (mounted) setState(() => _w = Map<String, dynamic>.from(d as Map));
    } catch (_) {}
  }

  Future<void> _buy(int days) async {
    setState(() => _busy = days);
    try {
      final d = await ApiClient.post('/tournaments/trophy/buy-vip', body: {'days': days});
      if (!mounted) return;
      setState(() => _w = {...?_w, ...Map<String, dynamic>.from(d as Map)});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('VIP added · $days days')));
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _n(num v) {
    final s = v.toInt().toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }

  @override
  Widget build(BuildContext context) {
    final w = _w;
    if (w == null) return const SizedBox.shrink();
    final balance = (w['balance'] as num?)?.toInt() ?? 0;
    // Wallet: only worth a row once you've won some.
    if (!widget.store && balance == 0) return const SizedBox.shrink();
    final next = w['nextExpiry'] as Map?;
    final at = DateTime.tryParse(next?['at'] as String? ?? '')?.toLocal();
    final plans = (w['vipPlans'] as Map?) ?? const {'7': 500, '30': 1800};
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('🏆 Trophy coins', style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(_n(balance), style: const TextStyle(color: _gold, fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 2),
        const Text('Only for VIP · can’t be gifted or withdrawn',
            style: TextStyle(color: AppColors.textDim, fontSize: 11.5)),
        if (next != null && at != null)
          Text('${next['amount']} expire on ${at.day} ${months[at.month - 1]}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
        if (widget.store) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (final days in const [7, 30]) ...[
              Expanded(
                child: Builder(builder: (_) {
                  final cost = (plans['$days'] as num?)?.toInt() ?? (days == 7 ? 500 : 1800);
                  final can = balance >= cost;
                  return OutlinedButton(
                    onPressed: _busy != null || !can ? null : () => _buy(days),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _gold,
                      backgroundColor: can ? const Color(0xFF412402) : null,
                      side: BorderSide(color: can ? _goldLine : AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      _busy == days
                          ? '…'
                          : can
                              ? 'VIP $days days · ${_n(cost)} 🏆'
                              : '$days days · need ${_n(cost - balance)} more',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                }),
              ),
              if (days == 7) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 6),
          Text('Win Trophy coins in tournaments · up to ${_n((w['weeklyCap'] as num?) ?? 1000)} a week',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ],
      ]),
    );
  }
}
