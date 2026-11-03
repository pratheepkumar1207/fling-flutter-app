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
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _price.dispose();
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
        final price = data['priceCoins'];
        _price.text = price == null ? '${data['min'] ?? 99}' : '$price';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn’t load your subscriptions.');
    }
  }

  Future<void> _save(int? price) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ApiClient.post('/creators/me/subscription',
          body: {'priceCoins': price});
      if (mounted) await context.read<AuthProvider>().refreshUser();
      await _load();
      messenger.showSnackBar(SnackBar(
          content: Text(price == null
              ? 'Subscriptions turned off'
              : 'Subscriptions on at $price coins a month')));
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
    final on = data['priceCoins'] != null;
    final min = (data['min'] as num?)?.toInt() ?? 49;
    final max = (data['max'] as num?)?.toInt() ?? 4999;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Offer subscriptions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Switch(
            value: on,
            activeThumbColor: AppColors.primary,
            onChanged: _saving
                ? null
                : (v) => _save(v ? int.tryParse(_price.text) ?? min : null),
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
            'Fans pay coins every month. You get diamonds, the same as gifts. '
            'Post stories for subscribers only from the story share menu.',
            style:
                TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Coins a month',
                  helperText: 'From $min to $max coins'),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _saving
                ? null
                : () {
                    final price = int.tryParse(_price.text.trim());
                    if (price == null || price < min || price > max) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Pick a price from $min to $max coins')));
                      return;
                    }
                    _save(price);
                  },
            child: Text(on ? 'Update' : 'Turn on'),
          ),
        ]),
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
          title: Text('${p['name']}'),
          subtitle: Text(
              'Since ${DateFormat.MMMd().format(DateTime.parse(p['since'] as String).toLocal())}'
              '${p['renews'] == true ? '' : ' · not renewing'}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          onTap: () => openProfile(context, p['id'] as String),
        ),
    ];
  }
}
