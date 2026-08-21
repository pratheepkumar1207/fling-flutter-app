import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';

/// Matches LivestreamDashboardDark.dc.html: an approval-status banner, a
/// 2x2 stat grid (wallet / lifetime gifts / total streams / avg. length),
/// the payout-eligibility note, a "Recent streams" list with per-stream
/// gift income, and a pinned "Go live" CTA. Stream history/avg-length now
/// come from GET /creators/me/livestream-dashboard's LivestreamSession-
/// backed response (added alongside this rewrite) rather than Room rows,
/// which get deleted the moment a live room empties out and never held a
/// duration in the first place.
class LivestreamDashboardScreen extends StatefulWidget {
  const LivestreamDashboardScreen({super.key});

  @override
  State<LivestreamDashboardScreen> createState() =>
      _LivestreamDashboardScreenState();
}

class _LivestreamDashboardScreenState extends State<LivestreamDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  bool _applying = false;
  bool _goingLive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/creators/me/livestream-dashboard')
          as Map<String, dynamic>;
      if (mounted) setState(() => _dashboard = data);
    } catch (_) {
      if (mounted) setState(() => _dashboard = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ApiClient.post('/creators/me/livestream-apply');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _goLive() async {
    setState(() => _goingLive = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'title': 'Live now',
        'roomType': 'live',
        'visibility': 'public'
      }) as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to start a live broadcast')));
      }
    } finally {
      if (mounted) setState(() => _goingLive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _dashboard;
    final status = d?['livestreamStatus'] as String? ?? 'none';
    final history = (d?['history'] as List?) ?? const [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Livestream')),
      body: _loading
          ? const Center(child: Spinner())
          : d == null
              ? const Center(
                  child: Text('Failed to load.',
                      style: TextStyle(color: AppColors.textFaint)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        children: [
                          _statusBanner(status),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                  child: _stat(
                                      Icons.monetization_on_rounded,
                                      AppColors.gold,
                                      'Wallet',
                                      formatNumber(d['coinBalance']),
                                      AppColors.text)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _stat(
                                      Icons.card_giftcard_rounded,
                                      AppColors.gold,
                                      'Lifetime gifts',
                                      formatNumber(d['totalCoinsCollected']),
                                      AppColors.gold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: _stat(
                                      Icons.videocam_outlined,
                                      AppColors.textFaint,
                                      'Total streams',
                                      '${d['totalStreamCount']}',
                                      AppColors.text)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _stat(
                                      Icons.schedule_rounded,
                                      AppColors.textFaint,
                                      'Avg. length',
                                      '${d['avgLengthMinutes']}m',
                                      AppColors.text)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border)),
                            child: Text(
                              'A stream counts toward payout eligibility once it has at least ${d['payoutEligibility']['minViewers']} concurrent viewers for at least ${d['payoutEligibility']['minMinutes']} minutes.',
                              style: const TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('RECENT STREAMS',
                              style: TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6)),
                          const SizedBox(height: 8),
                          if (history.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No streams yet.',
                                  style: TextStyle(
                                      color: AppColors.textFaint,
                                      fontSize: 12.5)),
                            )
                          else
                            ...List.generate(history.length, (i) {
                              final h = history[i] as Map<String, dynamic>;
                              final duration = h['durationMinutes'] as int?;
                              final started = DateTime.tryParse(
                                  h['startedAt'] as String? ?? '');
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: i == history.length - 1
                                                ? Colors.transparent
                                                : AppColors.border))),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          gradient: LinearGradient(
                                              colors: _thumbGradients[
                                                  i % _thumbGradients.length])),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              h['title'] as String? ??
                                                  'Live stream',
                                              style: const TextStyle(
                                                  color: AppColors.text,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5)),
                                          Text(
                                            '${started != null ? formatRelativeTime(started) : ''}${duration != null ? ' · ${duration}m' : ' · in progress'}',
                                            style: const TextStyle(
                                                color: AppColors.textFaint,
                                                fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('+${h['coinsCollected']}',
                                        style: const TextStyle(
                                            color: AppColors.gold,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _bottomCta(status),
                    ),
                  ],
                ),
    );
  }

  static const _thumbGradients = [
    [Color(0xFFE0B58A), Color(0xFFC44A2E)],
    [Color(0xFFCADCE8), Color(0xFF5A87B8)],
    [Color(0xFFD8C6E8), Color(0xFF8A5AB8)],
  ];

  Widget _bottomCta(String status) {
    if (status == 'approved') {
      return GestureDetector(
        onTap: _goingLive ? null : _goLive,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: _goingLive
                  ? null
                  : const LinearGradient(colors: AppGradients.brand),
              color: _goingLive ? AppColors.surface2 : null),
          alignment: Alignment.center,
          child: Text(_goingLive ? 'Starting…' : 'Go live',
              style: TextStyle(
                  color: _goingLive ? AppColors.textFaint : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
      );
    }
    if (status == 'pending') return const SizedBox.shrink();
    return GestureDetector(
      onTap: _applying ? null : _apply,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _applying
              ? null
              : const LinearGradient(colors: AppGradients.brand),
          color: _applying ? AppColors.surface2 : null,
        ),
        alignment: Alignment.center,
        child: Text(
          _applying
              ? 'Applying…'
              : (status == 'rejected'
                  ? 'Re-apply for livestream'
                  : 'Apply for livestream'),
          style: TextStyle(
              color: _applying ? AppColors.textFaint : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
    );
  }

  Widget _statusBanner(String status) {
    final (bg, iconColor, title, subtitle) = switch (status) {
      'approved' => (
          const LinearGradient(colors: [Color(0xFF2D4A38), Color(0xFF1B2E24)]),
          AppColors.success,
          'Approved to go live',
          'You can start a Live room anytime',
        ),
      'pending' => (
          const LinearGradient(colors: [Color(0xFF3D3620), Color(0xFF241F14)]),
          AppColors.gold,
          'Application pending',
          'We review requests within a few days',
        ),
      'rejected' => (
          const LinearGradient(colors: [Color(0xFF3D2320), Color(0xFF241614)]),
          AppColors.danger,
          'Application rejected',
          'You can re-apply from below',
        ),
      _ => (
          const LinearGradient(
              colors: [AppColors.surface2, AppColors.surface2]),
          AppColors.textFaint,
          'Not applied yet',
          'Apply below to unlock livestreaming',
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(gradient: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.22)),
            alignment: Alignment.center,
            child:
                Icon(Icons.wifi_tethering_rounded, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color iconColor, String label, String value,
      Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 12),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 10.5),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
        ],
      ),
    );
  }
}
