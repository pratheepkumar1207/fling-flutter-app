import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import 'tournament_live.dart';
import 'tournament_screen.dart';

/// Tournaments in Popcorn: a horizontal strip on All, full cards on Game.
/// Loads itself; shows nothing when there are none.
class TournamentPopcornSection extends StatefulWidget {
  final bool vertical;
  const TournamentPopcornSection({super.key, this.vertical = false});

  @override
  State<TournamentPopcornSection> createState() => _TournamentPopcornSectionState();
}

class _TournamentPopcornSectionState extends State<TournamentPopcornSection> {
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/tournaments') as List;
      if (!mounted) return;
      setState(() => _items = d
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((t) => t['status'] == 'open' || t['status'] == 'running')
          .toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (widget.vertical) {
      return Column(children: [
        for (final t in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TournamentCard(t: t, onReturn: _load),
          ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🏆 Tournaments', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(width: 260, child: TournamentCard(t: _items[i], onReturn: _load)),
          ),
        ),
      ]),
    );
  }
}

class TournamentCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final VoidCallback? onReturn;
  const TournamentCard({super.key, required this.t, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final running = t['status'] == 'running';
    final players = ((t['players'] as List?) ?? []).whereType<Map>().toList();
    final startsAt = DateTime.tryParse(t['startsAt'] as String? ?? '')?.toLocal();
    final round = ((t['rounds'] as List?) ?? []).isEmpty ? null : (t['rounds'] as List).last as Map;
    final prizes = (t['prizes'] as List?) ?? const [300, 150, 50, 50];
    final joined = t['joined'] == true;
    void open() => openTournament(context, t['id'] as String).then((_) => onReturn?.call());
    return Material(
      color: running ? const Color(0xFF000000) : const Color(0xFF000000),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: running ? AppColors.border : const Color(0xFFFFFFFF))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: running ? const Color(0xFF4F141B) : const Color(0xFF412402),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: running ? const Color(0xFFBB1528) : const Color(0xFFBA7517)),
                ),
                child: Text(running ? '● Live · Round ${round?['n'] ?? 1}' : '🏆 Free entry',
                    style: TextStyle(
                        fontSize: 11, color: running ? const Color(0xFFFABEC5) : const Color(0xFFFAC775))),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(!running && startsAt != null ? 'in ${tourCountdown(startsAt)}' : '',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${kTourGames[t['gameType']]?.$1 ?? '🏆'} ${t['title']}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
                running
                    ? '${players.length} players · watch every table'
                    : '${players.length} of ${t['size']} joined · tables at random',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(
                width: 22.0 * (players.length.clamp(1, 4) - 1) + 32,
                height: 32,
                child: Stack(children: [
                  for (var i = 0; i < players.length && i < 4; i++)
                    Positioned(
                      left: 22.0 * i,
                      child: Avatar(
                          src: players[i]['avatarUrl'] as String?,
                          name: players[i]['name'] as String?,
                          size: AvatarSize.sm),
                    ),
                ]),
              ),
              if (players.length > 4)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text('+${players.length - 4}', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 6),
            Text('🥇 ${prizes[0]} · 🥈 ${prizes[1]} · 🥉 ${prizes[2]} · 4th ${prizes[3]}',
                style: const TextStyle(fontSize: 11.5)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: running ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact),
                onPressed: open,
                child: Text(running ? 'Watch' : (joined ? 'You’re in · View' : 'Join · free')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
