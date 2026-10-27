import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/live_extras.dart';
import '../../widgets/spinner.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../party/party_screen.dart';

/// Live rankings: top hosts by diamonds and the biggest gifters, today or
/// this week (GET /live/rankings).
class LiveRankingsScreen extends StatefulWidget {
  const LiveRankingsScreen({super.key});

  @override
  State<LiveRankingsScreen> createState() => _LiveRankingsScreenState();
}

class _LiveRankingsScreenState extends State<LiveRankingsScreen> {
  String _period = 'day';
  bool _hosts = true;
  Map<String, dynamic>? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _failed = false;
    });
    try {
      final d = await ApiClient.get('/live/rankings?period=$_period')
          as Map<String, dynamic>;
      if (mounted) setState(() => _data = d);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
            label: Text(label), selected: on, onSelected: (_) => onTap()),
      );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final rows = ((data?[_hosts ? 'hosts' : 'gifters'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live rankings'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardsScreen())),
            child: const Text('All boards'),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(runSpacing: 8, children: [
            _chip('Hosts', _hosts, () => setState(() => _hosts = true)),
            _chip('Gifters', !_hosts, () => setState(() => _hosts = false)),
            const SizedBox(width: 8),
            _chip('Today', _period == 'day', () {
              _period = 'day';
              _load();
            }),
            _chip('This week', _period == 'week', () {
              _period = 'week';
              _load();
            }),
          ]),
        ),
        Expanded(
          child: _failed
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Couldn’t load rankings.',
                        style: TextStyle(color: AppColors.textFaint)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: _load, child: const Text('Try again')),
                  ]),
                )
              : data == null
                  ? const Center(child: Spinner(size: 28))
                  : rows.isEmpty
                      ? Center(
                          child: Text(
                              _hosts
                                  ? 'No live gifts yet in this period.'
                                  : 'No gifters yet in this period.',
                              style:
                                  const TextStyle(color: AppColors.textFaint)),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              final liveRoom = r['liveRoomId'] as String?;
                              return LiveRankRow(
                                rank: i + 1,
                                name: r['name'] as String? ?? '',
                                avatarUrl: r['avatarUrl'] as String?,
                                value: ((_hosts ? r['diamonds'] : r['coins'])
                                            as num?)
                                        ?.toInt() ??
                                    0,
                                icon: _hosts ? InIcons.diamond : InIcons.gift,
                                iconColor:
                                    _hosts ? AppColors.diamond : AppColors.gold,
                                onTap: () =>
                                    openProfile(context, r['id'] as String?),
                                trailing: liveRoom == null
                                    ? null
                                    : TextButton(
                                        onPressed: () => Navigator.of(context)
                                            .push(MaterialPageRoute(
                                                builder: (_) => PartyScreen(
                                                    roomId: liveRoom))),
                                        child: const Text('Watch'),
                                      ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}
