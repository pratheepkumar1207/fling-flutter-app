import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

const _scopeLabels = {
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly'
};

// Deterministic per-challenge icon + gradient, matching
// ChallengesDark.dc.html's colorful icon squares — cycles by index since
// challenges don't carry a "type" field to key off of.
const _kChallengeStyles = [
  (icon: InIcons.star, colors: [Color(0xFFE0836B), Color(0xFFB8422C)]),
  (icon: InIcons.gift, colors: [Color(0xFF6ED9A0), Color(0xFF2E9B5F)]),
  (icon: InIcons.bolt, colors: [Color(0xFFDBB155), Color(0xFFB98A3D)]),
  (icon: InIcons.trophy, colors: [Color(0xFF7FA8D9), Color(0xFF4272D9)]),
];

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _challenges = [];
  // Daily / Weekly / Special (monthly).
  String _scope = 'daily';

  List<Map<String, dynamic>> get _shown =>
      _challenges.where((c) => c['scope'] == _scope).toList();

  String? get _resetsIn {
    final first = _shown.isEmpty ? null : _shown.first['resetsAt'];
    final at = DateTime.tryParse('${first ?? ''}');
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    if (left.isNegative) return null;
    if (left.inDays >= 1) {
      return 'Resets in ${left.inDays}d ${left.inHours % 24}h';
    }
    return 'Resets in ${left.inHours}h ${left.inMinutes % 60}m';
  }

  String? _claiming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/gamification/challenges');
      if (!mounted) return;
      setState(() {
        _challenges = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim(String key) async {
    setState(() => _claiming = key);
    try {
      final res = await ApiClient.post('/gamification/challenges/$key/claim')
          as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('+${res['coinsAwarded']} coins!')));
      }
      _load();
      if (mounted) context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = context.watch<AuthProvider>().user?.coinBalance ?? 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const InsyncPageTitle('Challenges'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: insyncClay(radius: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const InIcon(InIcons.cash, color: AppColors.gold, size: 13),
                    const SizedBox(width: 5),
                    Text(formatNumber(coinBalance),
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Spinner())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              itemCount: _shown.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, children: [
                            for (final (id, label) in const [
                              ('daily', 'Daily'),
                              ('weekly', 'Weekly'),
                              ('monthly', 'Special'),
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: _scope == id,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _scope = id),
                              ),
                          ]),
                          if (_resetsIn != null) ...[
                            const SizedBox(height: 8),
                            Text(_resetsIn!,
                                style: const TextStyle(
                                    color: AppColors.textDim, fontSize: 12.5)),
                          ],
                        ]),
                  );
                }
                final c = _shown[i - 1];
                final progress = asNum(c['progress']).toDouble();
                final target = asNum(c['target']).toDouble();
                final ratio =
                    target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
                final completed = c['completed'] == true;
                final claimed = c['claimed'] == true;
                final style = _kChallengeStyles[i % _kChallengeStyles.length];

                return Opacity(
                  opacity: claimed ? 0.6 : 1,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: insyncClay(radius: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                color: claimed ? AppColors.surface2 : null,
                                gradient: claimed
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: style.colors),
                              ),
                              alignment: Alignment.center,
                              child: InIcon(
                                  claimed ? InIcons.check : style.icon,
                                  color: claimed
                                      ? AppColors.success
                                      : Colors.white,
                                  size: claimed ? 22 : 19),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['label'] as String? ?? '',
                                    style: TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        decoration: claimed
                                            ? TextDecoration.lineThrough
                                            : null),
                                  ),
                                  if (!claimed)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                          '${c['progress']} of ${c['target']} done · ${_scopeLabels[c['scope']] ?? c['scope'] ?? ''}',
                                          style: const TextStyle(
                                              color: AppColors.textFaint,
                                              fontSize: 11.5)),
                                    ),
                                ],
                              ),
                            ),
                            if (claimed)
                              const Text('Claimed',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800))
                            else
                              Text('+${c['reward']}',
                                  style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                          ],
                        ),
                        if (!claimed) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: AppColors.surface2,
                                valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primary),
                                minHeight: 6),
                          ),
                          if (completed) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _claiming == c['key']
                                    ? null
                                    : () => _claim(c['key'] as String),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: const LinearGradient(
                                          colors: AppGradients.brand)),
                                  child: Text(
                                      _claiming == c['key']
                                          ? 'Claiming…'
                                          : 'Claim',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.5)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
