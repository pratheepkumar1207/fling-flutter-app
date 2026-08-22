import 'package:flutter/material.dart';
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
  (icon: Icons.star_rounded, colors: [Color(0xFFE0836B), Color(0xFFB8422C)]),
  (
    icon: Icons.card_giftcard_rounded,
    colors: [Color(0xFF6ED9A0), Color(0xFF2E9B5F)]
  ),
  (icon: Icons.bolt_rounded, colors: [Color(0xFFDBB155), Color(0xFFB98A3D)]),
  (
    icon: Icons.emoji_events_rounded,
    colors: [Color(0xFF7FA8D9), Color(0xFF4272D9)]
  ),
];

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _challenges = [];
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
        title: const Text('Challenges'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: AppColors.gold, size: 13),
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
              itemCount: _challenges.length,
              itemBuilder: (context, i) {
                final c = _challenges[i];
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
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border)),
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
                              child: Icon(
                                  claimed ? Icons.check_rounded : style.icon,
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
