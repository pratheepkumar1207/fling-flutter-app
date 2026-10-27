import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/spinner.dart';
import 'live_rankings_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../party/party_screen.dart';
import '../search/search_screen.dart';

/// Live tab (bottom bar): everyone who is live right now, Tango-style —
/// a row of hosts, then a two-column grid of live covers.
class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

enum _LiveSort { forYou, newest }

class _LiveFeedScreenState extends State<LiveFeedScreen> {
  bool _loading = true;
  _LiveSort _sort = _LiveSort.forYou;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/rooms/browse') as List;
      if (!mounted) return;
      setState(() {
        _rooms = data
            .cast<Map<String, dynamic>>()
            .where((r) =>
                r['roomType'] == 'live' && (r['memberCount'] as int? ?? 0) > 0)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _sorted {
    final list = [..._rooms];
    if (_sort == _LiveSort.newest) {
      list.sort((a, b) => (b['createdAt'] as String? ?? '')
          .compareTo(a['createdAt'] as String? ?? ''));
    } else {
      list.sort((a, b) => ((b['memberCount'] as int?) ?? 0)
          .compareTo((a['memberCount'] as int?) ?? 0));
    }
    return list;
  }

  void _open(Map<String, dynamic> room) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => PartyScreen(roomId: room['id'] as String)))
        .then((_) => _load());
  }

  Future<void> _goLive() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LobbyCreateScreen(initialRoomType: 'live')));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _sorted;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.purple,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
            child: Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    const Text('Live',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    LiveTag(label: '${_rooms.length}'),
                  ]),
                ),
              ),
              InIconButton(InIcons.search,
                  tooltip: 'Search',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()))),
              InIconButton(InIcons.trophy,
                  tooltip: 'Rankings',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LiveRankingsScreen()))),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _GoLiveButton(busy: false, onTap: _goLive),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(children: [
              _SortChip('For you', _sort == _LiveSort.forYou,
                  () => setState(() => _sort = _LiveSort.forYou)),
              _SortChip('New', _sort == _LiveSort.newest,
                  () => setState(() => _sort = _LiveSort.newest)),
            ]),
          ),
        ),
        if (rooms.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _HostBubble(room: rooms[i], onTap: () => _open(rooms[i])),
              ),
            ),
          ),
        if (_loading)
          const SliverFillRemaining(
              hasScrollBody: false, child: Center(child: Spinner()))
        else if (rooms.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyLive(onGoLive: _goLive),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78),
              delegate: SliverChildBuilderDelegate(
                (_, i) =>
                    LiveCover(room: rooms[i], onTap: () => _open(rooms[i])),
                childCount: rooms.length,
              ),
            ),
          ),
      ]),
    );
  }
}

/// Pink "• LIVE" tag.
class LiveTag extends StatelessWidget {
  final String label;
  const LiveTag({super.key, this.label = 'LIVE'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.pink, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

class _GoLiveButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _GoLiveButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Go live',
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppGradients.brand),
              borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const InIcon(InIcons.live, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(busy ? 'Starting…' : 'Go live',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _HostBubble extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const _HostBubble({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = room['hostName'] as String? ?? '';
    final members = (room['members'] as List?)?.cast<Map>() ?? const [];
    final avatar =
        members.isNotEmpty ? members.first['avatarUrl'] as String? : null;
    return Semantics(
      button: true,
      label: '$name is live',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(children: [
            Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.pink, shape: BoxShape.circle),
                    child: Avatar(src: avatar, name: name, size: AvatarSize.md),
                  ),
                  const Positioned(bottom: -6, child: LiveTag()),
                ]),
            const SizedBox(height: 10),
            Text(name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

/// Live cover card used in the Live grid (and on Home).
class LiveCover extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const LiveCover({super.key, required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final host = room['hostName'] as String? ?? '';
    final title = room['title'] as String? ?? '';
    final thumb = room['nowPlayingThumbnail'] as String?;
    final count = room['memberCount'] as int? ?? 0;
    return Semantics(
      button: true,
      label: '$host live, $count watching',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            if (thumb != null && thumb.isNotEmpty)
              AppImage(source: thumb, fit: BoxFit.cover)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A1430), Color(0xFF0E0C14)]),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(children: [
                const LiveTag(),
                const Spacer(),
                _GlassPill(children: [
                  const InIcon(InIcons.user, size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('$count',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ]),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)]),
                ),
                child: Row(children: [
                  Avatar(name: host, size: AvatarSize.sm),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title.isEmpty ? host : '$host · $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final List<Widget> children;
  const _GlassPill({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _EmptyLive extends StatelessWidget {
  final VoidCallback onGoLive;
  const _EmptyLive({required this.onGoLive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: const Color(0xFF2A1028),
              borderRadius: BorderRadius.circular(24)),
          child: const Center(
              child: InIcon(InIcons.live, size: 34, color: AppColors.pink)),
        ),
        const SizedBox(height: 14),
        const Text('No one is live right now',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Be the first — go live and your followers get a ping.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onGoLive, child: const Text('Go live')),
      ]),
    );
  }
}
