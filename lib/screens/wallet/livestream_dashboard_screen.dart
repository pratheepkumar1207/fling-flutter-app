import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// Streamer-facing dashboard — wallet balance, lifetime coins collected
/// while live, stream history, and the redeem-eligibility thresholds (see
/// GET /creators/me/livestream-dashboard and GET /wallet/cashouts).
class LivestreamDashboardScreen extends StatefulWidget {
  const LivestreamDashboardScreen({super.key});

  @override
  State<LivestreamDashboardScreen> createState() => _LivestreamDashboardScreenState();
}

class _LivestreamDashboardScreenState extends State<LivestreamDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  List<dynamic> _cashouts = [];
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/creators/me/livestream-dashboard').catchError((_) => null),
      ApiClient.get('/wallet/cashouts').catchError((_) => []),
    ]);
    if (!mounted) return;
    setState(() {
      _dashboard = results[0] as Map<String, dynamic>?;
      _cashouts = (results[1] as List?) ?? [];
      _loading = false;
    });
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ApiClient.post('/creators/me/livestream-apply');
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _dashboard;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Livestream Dashboard')),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : d == null
              ? const Center(child: Text('Failed to load.', style: TextStyle(color: AppColors.textFaint)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _statCard('💰 Wallet', formatNumber(d['coinBalance']))),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('🎁 Coins collected', formatNumber(d['totalCoinsCollected']))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _statCard('📡 Total streams', '${d['totalStreamCount']}')),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('✅ Status', _statusLabel(d['livestreamStatus'] as String? ?? 'none'))),
                      ],
                    ),
                    if (d['livestreamStatus'] != 'approved' && d['livestreamStatus'] != 'pending') ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _applying ? null : _apply,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: _applying ? null : const LinearGradient(colors: AppGradients.brand),
                            color: _applying ? AppColors.surface2 : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _applying ? 'Applying…' : (d['livestreamStatus'] == 'rejected' ? 'Re-apply for livestream' : 'Apply for livestream'),
                            style: TextStyle(color: _applying ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Text(
                        'A stream counts toward payout eligibility once it has at least ${d['payoutEligibility']['minViewers']} concurrent viewers for at least ${d['payoutEligibility']['minMinutes']} minutes.',
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Redeem requests', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    if (_cashouts.isEmpty)
                      const Text('No redeem requests yet.', style: TextStyle(color: AppColors.textFaint))
                    else
                      ..._cashouts.map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${c['coins']} coins', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                                Text(
                                  c['type'] == 'cashout_paid' ? 'Paid' : 'Pending',
                                  style: TextStyle(color: c['type'] == 'cashout_paid' ? AppColors.success : AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 20),
                    const Text('Stream history', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    if ((d['history'] as List).isEmpty)
                      const Text('No streams yet.', style: TextStyle(color: AppColors.textFaint))
                    else
                      ...(d['history'] as List).map((h) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                            child: Text(h['title'] as String? ?? 'Live stream', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                          )),
                  ],
                ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'approved' => 'Approved',
        'pending' => 'Pending',
        'rejected' => 'Rejected',
        _ => 'Not applied',
      };

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
