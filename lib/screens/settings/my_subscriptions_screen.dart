import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../../widgets/sub_tiers.dart';

/// Creators you subscribe to, with your level and when it renews.
class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/creators/me/subscriptions') as List;
      if (mounted) {
        setState(() =>
            _rows = [for (final r in d) Map<String, dynamic>.from(r as Map)]);
      }
    } catch (_) {
      if (mounted) setState(() => _rows = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My subscriptions')),
      body: rows == null
          ? const Center(child: Spinner())
          : rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'You don’t subscribe to anyone yet. Look for ◆ Subscribe on a creator’s profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textDim)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final until = DateTime.tryParse('${r['expiresAt']}')
                          ?.toLocal();
                      final when =
                          until == null ? '' : DateFormat.MMMd().format(until);
                      return ListTile(
                        leading: Avatar(
                            src: r['avatarUrl'] as String?,
                            name: r['name'] as String?,
                            size: AvatarSize.md),
                        title: Row(children: [
                          SubTierBadge(r['tier'] as String? ?? 'silver',
                              fontSize: 9),
                          Flexible(
                              child: Text('${r['name']}',
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                        subtitle: Text(
                            '${r['priceCoins']} coins/mo · '
                            '${r['renews'] == true ? 'renews' : 'ends'} $when',
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                        onTap: () => openProfile(context, r['id'] as String),
                      );
                    },
                  ),
                ),
    );
  }
}
