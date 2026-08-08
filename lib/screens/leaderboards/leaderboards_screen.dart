import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

const _tabs = [
  {'key': 'gifters', 'label': 'Top Gifters', 'endpoint': '/leaderboards/gifters'},
  {'key': 'creators', 'label': 'Top Creators', 'endpoint': '/leaderboards/creators'},
  {'key': 'communities', 'label': 'Top Communities', 'endpoint': '/leaderboards/communities'},
];

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  String _tab = 'gifters';
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final endpoint = _tabs.firstWhere((t) => t['key'] == _tab)['endpoint'] as String;
    try {
      final data = await ApiClient.get(endpoint);
      if (!mounted) return;
      setState(() {
        _entries = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Leaderboards')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: _tabs
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t['label'] as String),
                          selected: _tab == t['key'],
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(color: _tab == t['key'] ? AppColors.primary : AppColors.textDim, fontSize: 12),
                          backgroundColor: AppColors.surface,
                          onSelected: (_) {
                            setState(() => _tab = t['key'] as String);
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final isCommunity = _tab == 'communities';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            isCommunity
                                ? Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.surface3, shape: BoxShape.circle), alignment: Alignment.center, child: const Text('🏘️'))
                                : Avatar(src: e['avatarUrl'] as String?, name: e['name'] as String?, size: AvatarSize.sm),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(
                              isCommunity ? '${formatNumber(e['memberCount'])} members' : formatNumber(e['totalCoins']),
                              style: TextStyle(color: isCommunity ? AppColors.textDim : AppColors.gold, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
