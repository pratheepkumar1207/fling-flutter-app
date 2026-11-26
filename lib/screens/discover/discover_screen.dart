import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../models/user.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
import '../events/events_screen.dart';
import '../experience/experience_hub.dart' show VibeMatchScreen;
import '../messages/message_thread_screen.dart';
import '../party/party_screen.dart';
import 'discover_filters.dart';
import 'discover_matches_screen.dart';
import 'discover_sheets.dart';
import 'discover_ui.dart';
import 'liked_me_screen.dart';
import 'map_explore_screen.dart';
import 'peek_card.dart';
import 'profile_sheet.dart';
import 'random_match_screen.dart';
import 'swipe_card.dart';

/// Discover: the swipe deck (black / white / red redesign, Nov 2026).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<DiscoverProfile>? _deck;
  bool _loading = true;
  DiscoverProfile? _matched;
  DiscoverProfile? _lastSwiped;
  bool _undoing = false;
  DateTime? _boostedUntil;
  DiscoverFilters _filters = DiscoverFilters();
  int _likedYou = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSide();
  }

  Future<void> _loadSide() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/swipe/likes-count'),
        ApiClient.get('/discover/boost'),
      ]);
      if (!mounted) return;
      final until =
          DateTime.tryParse('${(results[1] as Map)['boostedUntil'] ?? ''}');
      setState(() {
        _likedYou = ((results[0] as Map)['count'] as num?)?.toInt() ?? 0;
        _boostedUntil =
            until != null && until.isAfter(DateTime.now()) ? until : null;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = _filters.queryString;
    try {
      final data = await ApiClient.get('/discover${q.isNotEmpty ? '?$q' : ''}');
      if (!mounted) return;
      setState(() {
        // The deck shows its last item on top, so the best match goes last.
        _deck = (data as List)
            .map((e) => DiscoverProfile.fromJson(e as Map<String, dynamic>))
            .toList()
            .reversed
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _handleSwipe(String action) async {
    final deck = _deck;
    if (deck == null || deck.isEmpty) return;
    final top = deck.last;
    final previousLastSwiped = _lastSwiped;
    setState(() {
      _deck = deck.sublist(0, deck.length - 1);
      _lastSwiped = top;
    });
    void putBack() => setState(() {
          _deck = deck;
          _lastSwiped = previousLastSwiped;
        });
    try {
      final res = await ApiClient.post('/swipe',
          body: {'toUserId': top.id, 'action': action}) as Map<String, dynamic>;
      if (!mounted) return;
      if (res['matched'] == true) {
        setState(() {
          _matched = top;
          _lastSwiped = null; // matched swipes can't be undone
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Not swiped after all: the card goes back on top.
      putBack();
      if (e.status == 429 && e.data is Map) {
        await showOutOfLikesSheet(context, e.data as Map,
            superLike: (e.data as Map)['code'] == 'superlike_limit');
      } else {
        _snack(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      putBack();
      _snack('Something went wrong');
    }
  }

  Future<void> _boost() async {
    final until = await showBoostSheet(context);
    if (until != null && mounted) {
      setState(() => _boostedUntil = until);
      _snack('Boosted. You’re shown first in Discover.');
    }
  }

  Future<void> _undoLastSwipe() async {
    final lastSwiped = _lastSwiped;
    if (lastSwiped == null || _undoing) return;
    setState(() => _undoing = true);
    try {
      await ApiClient.post('/swipe/undo');
      if (!mounted) return;
      setState(() {
        _deck = [...(_deck ?? []), lastSwiped];
        _lastSwiped = null;
      });
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  Future<void> _openFilters() async {
    final next = await showDiscoverFilters(context, _filters);
    if (next == null || !mounted) return;
    setState(() => _filters = next);
    _load();
  }

  Future<void> _openProfile(DiscoverProfile p) async {
    final action = await showDiscoverProfile(context, p);
    if (action != null &&
        mounted &&
        _deck?.isNotEmpty == true &&
        _deck!.last.id == p.id) {
      _handleSwipe(action);
    }
  }

  void _joinLobby(DiscoverProfile p) {
    final roomId = p.activeRoom?['roomId'] as String?;
    if (roomId == null) {
      showPeekCard(context, p.id);
      return;
    }
    _push(PartyScreen(roomId: roomId));
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _inviteMatch(DiscoverProfile m) async {
    final roomId = ActiveRoomHolder.roomId;
    setState(() => _matched = null);
    if (roomId == null) return;
    try {
      await ApiClient.post('/rooms/$roomId/invite', body: {
        'userIds': [m.id]
      });
      if (mounted) _snack('Invite sent to ${m.name}');
    } catch (_) {
      if (mounted) _snack('Couldn’t send the invite.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
          child: Row(children: [
            const Expanded(
                child: Text('Discover',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
            InIconButton(InIcons.map,
                tooltip: 'People map',
                border: true,
                iconSize: 20,
                onPressed: () => _push(const MapExploreScreen())),
            const SizedBox(width: 6),
            InIconButton(InIcons.dice,
                tooltip: 'Random match',
                border: true,
                iconSize: 20,
                onPressed: () => _push(const RandomMatchScreen())),
            const SizedBox(width: 6),
            InIconButton(InIcons.tune,
                tooltip: 'Filters',
                border: true,
                iconSize: 20,
                badge: _filters.activeCount,
                onPressed: _openFilters),
          ]),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              DChip(_likedYou > 0 ? 'Liked you $_likedYou' : 'Liked you',
                  icon: InIcons.heart,
                  tone: DTone.red,
                  fontSize: 13,
                  onTap: () => _push(const LikedMeScreen())),
              const SizedBox(width: 6),
              DChip('Matches',
                  icon: InIcons.chat,
                  fontSize: 13,
                  onTap: () => _push(const DiscoverMatchesScreen())),
              const SizedBox(width: 6),
              DChip('Vibe Match',
                  icon: InIcons.spark,
                  fontSize: 13,
                  onTap: () => _push(const VibeMatchScreen())),
              const SizedBox(width: 6),
              DChip('Events',
                  icon: InIcons.calendar,
                  fontSize: 13,
                  onTap: () => _push(const EventsScreen())),
            ],
          ),
        ),
        if (_boostedUntil != null)
          BoostBanner(
              until: _boostedUntil!,
              onEnded: () => setState(() => _boostedUntil = null)),
        Expanded(
          child: _loading
              ? const _LoadingDeck()
              : (deck == null || deck.isEmpty)
                  ? _EmptyDeck(
                      onFilters: _openFilters,
                      onLobbies: () =>
                          _push(const MapExploreScreen(startOnRooms: true)),
                      onMap: () => _push(const MapExploreScreen()),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Stack(children: [
                        if (deck.length > 1)
                          Positioned.fill(
                            top: 10,
                            left: 14,
                            right: 14,
                            bottom: -6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: DColors.line),
                              ),
                            ),
                          ),
                        ...deck
                            .asMap()
                            .entries
                            .where((e) => e.key >= deck.length - 3)
                            .map((e) => Positioned.fill(
                                  child: SwipeCard(
                                    key: ValueKey(e.value.id),
                                    profile: e.value,
                                    active: e.key == deck.length - 1,
                                    onSwipe: _handleSwipe,
                                    onOpen: () => _openProfile(e.value),
                                    onLongPress: () =>
                                        showPeekCard(context, e.value.id),
                                    onJoinLobby: () => _joinLobby(e.value),
                                  ),
                                )),
                      ]),
                    ),
        ),
        if (deck != null && deck.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            // Five buttons need 316 px; narrow phones shrink them a little.
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _roundAction(InIcons.undo, 'Rewind',
                      _lastSwiped != null && !_undoing ? _undoLastSwipe : null,
                      size: 48),
                  const SizedBox(width: 12),
                  _roundAction(
                      InIcons.close, 'Nope', () => _handleSwipe('pass'),
                      size: 62, iconSize: 28),
                  const SizedBox(width: 12),
                  _roundAction(InIcons.star, 'Super like',
                      () => _handleSwipe('superlike'),
                      size: 48),
                  const SizedBox(width: 12),
                  _roundAction(
                      InIcons.heart, 'Like', () => _handleSwipe('like'),
                      size: 62, iconSize: 28, red: true),
                  const SizedBox(width: 12),
                  _roundAction(InIcons.bolt,
                      _boostedUntil != null ? 'Boosted' : 'Boost', _boost,
                      size: 48, lit: _boostedUntil != null),
                ])),
          ),
      ]),
      if (_matched != null)
        _MatchOverlay(
          me: context.watch<AuthProvider>().user,
          them: _matched!,
          onClose: () => setState(() => _matched = null),
          onMessage: () {
            final m = _matched!;
            setState(() => _matched = null);
            _push(MessageThreadScreen(
                userId: m.id, name: m.name, avatarUrl: m.avatarUrl));
          },
          onInvite: ActiveRoomHolder.roomId == null
              ? null
              : () => _inviteMatch(_matched!),
        ),
    ]);
  }

  Widget _roundAction(InIconData icon, String label, VoidCallback? onTap,
      {required double size,
      double iconSize = 22,
      bool red = false,
      bool lit = false}) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: red ? DColors.red : const Color(0xFF111111),
            border: red
                ? null
                : Border.all(
                    color: lit ? DColors.red : const Color(0xFF333333)),
          ),
          alignment: Alignment.center,
          child: InIcon(icon,
              size: iconSize,
              filled: red || lit,
              color: disabled
                  ? Colors.white.withValues(alpha: 0.3)
                  : lit
                      ? DColors.red
                      : Colors.white),
        ),
      ),
    );
  }
}

class _LoadingDeck extends StatelessWidget {
  const _LoadingDeck();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(
                child: SkeletonBox(height: double.infinity, radius: 24)),
            Positioned(
              left: 16,
              right: 120,
              bottom: 20,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 20),
                    SizedBox(height: 8),
                    SkeletonBox(width: 100, height: 12),
                    SizedBox(height: 10),
                    Row(children: [
                      SkeletonBox(width: 60, height: 22, radius: 11),
                      SizedBox(width: 6),
                      SkeletonBox(width: 60, height: 22, radius: 11),
                    ]),
                  ]),
            ),
            Center(child: _Beat()),
          ]),
        ),
        SizedBox(height: 14),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SkeletonBox(width: 48, height: 48, radius: 24),
              SizedBox(width: 12),
              SkeletonBox(width: 62, height: 62, radius: 31),
              SizedBox(width: 12),
              SkeletonBox(width: 48, height: 48, radius: 24),
              SizedBox(width: 12),
              SkeletonBox(width: 62, height: 62, radius: 31),
              SizedBox(width: 12),
              SkeletonBox(width: 48, height: 48, radius: 24),
            ])),
        SizedBox(height: 12),
      ]),
    );
  }
}

/// The red heart beating in the middle of the loading card.
class _Beat extends StatefulWidget {
  const _Beat();
  @override
  State<_Beat> createState() => _BeatState();
}

class _BeatState extends State<_Beat> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.12)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: const InIcon(InIcons.heart,
            size: 46, color: DColors.red, filled: true),
      );
}

class _EmptyDeck extends StatelessWidget {
  final VoidCallback onFilters;
  final VoidCallback onLobbies;
  final VoidCallback onMap;
  const _EmptyDeck(
      {required this.onFilters, required this.onLobbies, required this.onMap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF444444))),
            alignment: Alignment.center,
            child:
                const InIcon(InIcons.users, size: 36, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 14),
          const Text('You’ve seen everyone nearby',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'New people join every day. Widen your filters, or meet people in a lobby.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DColors.dim, fontSize: 13, height: 1.45)),
          const SizedBox(height: 18),
          DButton('Edit filters',
              icon: InIcons.tune,
              kind: DButtonKind.white,
              onPressed: onFilters),
          const SizedBox(height: 8),
          DButton('Browse live lobbies',
              icon: InIcons.play,
              kind: DButtonKind.outline,
              onPressed: onLobbies),
          TextButton.icon(
            onPressed: onMap,
            icon: const InIcon(InIcons.map, size: 16, color: DColors.dim),
            label: const Text('Open the map',
                style: TextStyle(color: DColors.dim)),
          ),
        ]),
      ),
    );
  }
}

class _MatchOverlay extends StatelessWidget {
  final User? me;
  final DiscoverProfile them;
  final VoidCallback onClose;
  final VoidCallback onMessage;
  final VoidCallback? onInvite;
  const _MatchOverlay(
      {required this.me,
      required this.them,
      required this.onClose,
      required this.onMessage,
      this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.95),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('IT’S A',
                  style: TextStyle(
                      color: DColors.dim, fontSize: 13, letterSpacing: 4)),
              const Text('Match',
                  style: TextStyle(
                      color: DColors.red,
                      fontSize: 44,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PersonFace(
                    avatarUrl: me?.avatarUrl,
                    name: me?.name ?? 'You',
                    size: 96,
                    ring: RingKind.close),
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                      color: DColors.red, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const InIcon(InIcons.heart,
                      size: 20, color: Colors.white, filled: true),
                ),
                PersonFace(
                    avatarUrl: them.avatarUrl,
                    name: them.name,
                    size: 96,
                    ring: RingKind.lobby),
              ]),
              const SizedBox(height: 18),
              Text('You and ${them.name} liked each other',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
              if (them.inCommon.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final i in them.inCommon.take(3))
                        DChip(i, tone: DTone.outline),
                    ]),
              ],
              const SizedBox(height: 26),
              DButton('Send a message',
                  icon: InIcons.chat, onPressed: onMessage),
              if (onInvite != null) ...[
                const SizedBox(height: 8),
                DButton('Invite to watch',
                    icon: InIcons.play,
                    kind: DButtonKind.white,
                    onPressed: onInvite),
              ],
              TextButton(
                  onPressed: onClose,
                  child: const Text('Keep swiping',
                      style: TextStyle(color: DColors.dim))),
            ]),
          ),
        ),
      ),
    );
  }
}
