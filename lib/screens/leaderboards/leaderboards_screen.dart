import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

const _tabs = [
  {'key': 'gifters', 'label': 'Top Gifters', 'endpoint': '/leaderboards/gifters', 'scoped': true},
  {'key': 'creators', 'label': 'Top Creators', 'endpoint': '/leaderboards/creators', 'scoped': true},
  {'key': 'users', 'label': 'Top User', 'endpoint': '/leaderboards/users', 'scoped': false},
  {'key': 'communities', 'label': 'Top Communities', 'endpoint': '/leaderboards/communities', 'scoped': false},
];

const _scopes = [
  {'key': null, 'label': 'All-time'},
  {'key': 'daily', 'label': 'Daily'},
  {'key': 'weekly', 'label': 'Weekly'},
  {'key': 'monthly', 'label': 'Monthly'},
];

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  String _tab = 'gifters';
  String? _scope;
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];

  Map<String, dynamic> get _activeTab => _tabs.firstWhere((t) => t['key'] == _tab);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final endpoint = _activeTab['endpoint'] as String;
    final scoped = _activeTab['scoped'] as bool;
    final query = (scoped && _scope != null) ? '?scope=$_scope' : '';
    try {
      final data = await ApiClient.get('$endpoint$query');
      if (!mounted) return;
      setState(() {
        _entries = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _metric(Map<String, dynamic> e) {
    switch (_tab) {
      case 'communities':
        return '${formatNumber(e['memberCount'])} members';
      case 'users':
        return 'Lv.${e['level'] ?? 1}';
      default:
        return '🪙 ${formatNumber(e['totalCoins'])}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoped = _activeTab['scoped'] as bool;
    final top3 = _entries.take(3).toList();
    final rest = _entries.skip(3).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Leaderboards')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = _tabs[i];
                  final selected = _tab == t['key'];
                  return ChoiceChip(
                    label: Text(t['label'] as String),
                    selected: selected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 12),
                    backgroundColor: AppColors.surface,
                    onSelected: (_) {
                      setState(() => _tab = t['key'] as String);
                      _load();
                    },
                  );
                },
              ),
            ),
          ),
          if (scoped)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _scopes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = _scopes[i];
                    final selected = _scope == s['key'];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _scope = s['key']);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: selected ? AppGradients.volaCtaDiagonal : null,
                          color: selected ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
                        ),
                        child: Text(s['label'] as String, style: TextStyle(color: selected ? Colors.white : AppColors.textDim, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : _entries.isEmpty
                    ? const Center(child: Text('No entries yet.', style: TextStyle(color: AppColors.textFaint)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (top3.isNotEmpty) _podium(top3),
                          const SizedBox(height: 16),
                          ...rest.asMap().entries.map((entry) => _row(entry.key + 4, entry.value)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _podium(List<Map<String, dynamic>> top3) {
    final isCommunity = _tab == 'communities';
    Widget slot(int rank, Map<String, dynamic>? e, double avatarSize, double height) {
      if (e == null) return const SizedBox(width: 84);
      final crown = rank == 1 ? '👑' : (rank == 2 ? '🥈' : '🥉');
      return SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(crown, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: isCommunity ? null : () => openProfile(context, e['id'] as String?),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rank == 1 ? AppColors.gold : AppColors.border, width: 2)),
                child: isCommunity
                    ? CircleAvatar(radius: avatarSize / 2, backgroundColor: AppColors.surface3, child: const Text('🏘️'))
                    : Avatar(src: e['avatarUrl'] as String?, name: e['name'] as String?, size: avatarSize > 50 ? AvatarSize.lg : AvatarSize.md),
              ),
            ),
            const SizedBox(height: 6),
            Text(e['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(_metric(e), style: const TextStyle(color: AppColors.gold, fontSize: 11)),
            const SizedBox(height: 8),
            // Height-tiered podium block — 1st tallest, matches
            // LeaderboardsDark.dc.html's numbered platform.
            Container(
              width: 64,
              height: rank == 1 ? 52 : (rank == 2 ? 34 : 24),
              decoration: BoxDecoration(
                gradient: rank == 1 ? const LinearGradient(colors: [AppColors.gold, Color(0xFFC98F3A)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
                color: rank == 1 ? null : AppColors.surface2,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              alignment: Alignment.center,
              child: Text('$rank', style: TextStyle(color: rank == 1 ? const Color(0xFF3A2408) : AppColors.textDim, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        slot(2, top3.length > 1 ? top3[1] : null, 48, 90),
        slot(1, top3.isNotEmpty ? top3[0] : null, 64, 110),
        slot(3, top3.length > 2 ? top3[2] : null, 48, 90),
      ],
    );
  }

  Widget _row(int rank, Map<String, dynamic> e) {
    final isCommunity = _tab == 'communities';
    final myId = context.read<AuthProvider>().user?.id;
    final isMe = !isCommunity && myId != null && e['id'] == myId;
    return GestureDetector(
      onTap: isCommunity ? null : () => openProfile(context, e['id'] as String?),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$rank', textAlign: TextAlign.center, style: TextStyle(color: isMe ? AppColors.accent : AppColors.textFaint, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          isCommunity
              ? Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.surface3, shape: BoxShape.circle), alignment: Alignment.center, child: const Text('🏘️'))
              : Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: isMe ? Border.all(color: AppColors.accent, width: 2) : null),
                  padding: isMe ? const EdgeInsets.all(1) : EdgeInsets.zero,
                  child: Avatar(src: e['avatarUrl'] as String?, name: e['name'] as String?, size: AvatarSize.sm),
                ),
          const SizedBox(width: 10),
          Expanded(child: Text('${e['name'] ?? ''}${isMe ? ' (you)' : ''}', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: isMe ? FontWeight.w700 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(_metric(e), style: TextStyle(color: isMe ? AppColors.accent : AppColors.gold, fontSize: 12, fontWeight: isMe ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
      ),
    );
  }
}
