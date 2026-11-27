import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../../widgets/sub_tiers.dart';

/// For creators: offer a monthly subscription at your own price, and see
/// who's subscribed. Subscribers can see your subscriber-only stories.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _saving = false;
  // A price box per level.
  final _prices = {for (final t in kSubTiers) t: TextEditingController()};
  final _on = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = Map<String, dynamic>.from(
          await ApiClient.get('/creators/me/subscribers') as Map);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        final tiers = Map<String, dynamic>.from(
            (data['tiers'] as Map?) ?? {'silver': data['priceCoins']});
        const suggested = {'silver': 49, 'gold': 149, 'platinum': 499};
        for (final t in kSubTiers) {
          _on[t] = tiers[t] != null;
          _prices[t]!.text = '${tiers[t] ?? suggested[t]}';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn’t load your subscriptions.');
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final tiers = <String, int?>{
      for (final t in kSubTiers)
        t: _on[t] == true ? int.tryParse(_prices[t]!.text.trim()) : null,
    };
    setState(() => _saving = true);
    try {
      await ApiClient.post('/creators/me/subscription', body: {'tiers': tiers});
      if (mounted) await context.read<AuthProvider>().refreshUser();
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('Levels saved')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Subscriptions')),
      body: data == null
          ? Center(
              child: _error == null
                  ? const Spinner()
                  : Text(_error!,
                      style: const TextStyle(color: AppColors.textDim)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _offer(data),
                  const SizedBox(height: 22),
                  ..._list(data)
                ],
              ),
            ),
    );
  }

  Widget _offer(Map<String, dynamic> data) {
    final min = (data['min'] as num?)?.toInt() ?? 49;
    final max = (data['max'] as num?)?.toInt() ?? 4999;
    final counts = Map<String, dynamic>.from((data['tierCounts'] as Map?) ?? {});
    final month = (data['monthCoins'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Levels',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            'Turn on the levels you want and set a monthly price for each '
            '($min–$max coins). You get diamonds, the same as gifts.',
            style: const TextStyle(
                color: AppColors.textDim, fontSize: 13, height: 1.4)),
        const SizedBox(height: 8),
        for (final t in kSubTiers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Text('◆',
                  style: TextStyle(color: subTierColors(t).$1, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subTierName(t),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          '${(counts[t] as num?)?.toInt() ?? 0} subscribers',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 11.5)),
                    ]),
              ),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _prices[t],
                  enabled: _on[t] == true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                      isDense: true, suffixText: '/mo'),
                ),
              ),
              Switch(
                value: _on[t] == true,
                activeThumbColor: subTierColors(t).$1,
                onChanged: _saving ? null : (v) => setState(() => _on[t] = v),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.surface2, border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 0.8)),
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This month',
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
            Text('$month coins from ${(data['count'] as num?)?.toInt() ?? 0} subscribers',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save levels'),
        ),
      ]),
    );
  }

  List<Widget> _list(Map<String, dynamic> data) {
    final people = ((data['subscribers'] as List?) ?? []).cast<Map>();
    return [
      Text(
          people.length == 1
              ? '1 subscriber'
              : '${(data['count'] as num?)?.toInt() ?? people.length} subscribers',
          style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
      const SizedBox(height: 8),
      if (people.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text('No subscribers yet.',
              style: TextStyle(color: AppColors.textDim)),
        ),
      for (final p in people)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Avatar(
              src: p['avatarUrl'] as String?,
              name: p['name'] as String?,
              size: AvatarSize.sm),
          title: Row(children: [
            SubTierBadge(p['tier'] as String? ?? 'silver'),
            Flexible(child: Text('${p['name']}', overflow: TextOverflow.ellipsis)),
          ]),
          subtitle: Text(
              'Since ${DateFormat.MMMd().format(DateTime.parse(p['since'] as String).toLocal())}'
              '${p['renews'] == true ? '' : ' · not renewing'}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          onTap: () => openProfile(context, p['id'] as String),
        ),
    ];
  }
}
