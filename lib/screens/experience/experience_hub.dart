import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/live_extras.dart' show compactCount;
import '../../widgets/spinner.dart';
import '../../widgets/studio_stats.dart';
import '../achievements/achievements_screen.dart';
import '../communities/communities_screen.dart';
import '../events/events_screen.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../messages/message_thread_screen.dart';
import '../settings/account_centers.dart';
import '../settings/room_moderation_screen.dart';
import '../wallet/livestream_dashboard_screen.dart';
import '../wallet/wallet_cashout_screen.dart';
import '../wallet/wallet_screen.dart';

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// The four moods Vibe match understands.
const _vibes = [
  ('movie', '🍿', 'Movie'),
  ('talk', '🎤', 'Talk'),
  ('play', '🎮', 'Play'),
  ('music', '🎶', 'Music'),
];

AppBar _bar(BuildContext context, String title, {List<Widget>? actions}) =>
    AppBar(
      backgroundColor: AppColors.bg,
      leading: InIconButton(InIcons.back,
          tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
      title: Text(title),
      actions: actions,
    );

class _VibeChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _VibeChips({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (id, emoji, label) in _vibes)
          ChoiceChip(
            label: Text('$emoji $label'),
            selected: selected == id,
            showCheckmark: false,
            onSelected: (_) => onPick(id),
          ),
      ]);
}

// ------------------------------------------------------------------- Hub

/// "Together": pick a vibe to find people in the same mood, start
/// something, and get to the creator and safety tools.
class FlingFeatureHubScreen extends StatefulWidget {
  const FlingFeatureHubScreen({super.key});

  @override
  State<FlingFeatureHubScreen> createState() => _FlingFeatureHubScreenState();
}

class _FlingFeatureHubScreenState extends State<FlingFeatureHubScreen> {
  String _vibe = 'movie';

  @override
  Widget build(BuildContext context) {
    Widget tile(
            InIconData icon, String title, String sub, VoidCallback onTap) =>
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFF1F1A2C),
                borderRadius: BorderRadius.circular(12)),
            child:
                Center(child: InIcon(icon, size: 20, color: AppColors.lilac)),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          trailing:
              const InIcon(InIcons.right, size: 16, color: AppColors.textDim),
        );
    Widget card(List<Widget> children) => Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(t,
              style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(context, 'Together'),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1326),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF3B2A55))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VIBE MATCH',
                        style: TextStyle(
                            color: AppColors.lilac,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 6),
                    const Text('What are you feeling?',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    _VibeChips(
                        selected: _vibe,
                        onPick: (v) => setState(() => _vibe = v)),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () =>
                          _push(context, VibeMatchScreen(vibe: _vibe)),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('Find my vibe'),
                    ),
                  ]),
            ),
            label('DO SOMETHING TOGETHER'),
            card([
              tile(
                  InIcons.film,
                  'Watch party',
                  'Movies and shows',
                  () => _push(context,
                      const LobbyCreateScreen(initialRoomType: 'watch'))),
              tile(
                  InIcons.game,
                  'Games',
                  'Ludo, UNO, Chess',
                  () => _push(context,
                      const LobbyCreateScreen(initialRoomType: 'game'))),
              tile(InIcons.community, 'Communities', 'Groups and interests',
                  () => _push(context, const CommunitiesScreen())),
              tile(InIcons.calendar, 'Events', 'Plan ahead',
                  () => _push(context, const EventsScreen())),
            ]),
            label('FOR CREATORS'),
            card([
              tile(InIcons.chart, 'Creator Studio', 'Analytics, earnings',
                  () => _push(context, const CreatorStudioScreen())),
              tile(InIcons.live, 'Live dashboard', 'Your streams and gifts',
                  () => _push(context, const LivestreamDashboardScreen())),
            ]),
            label('SAFETY AND ACCOUNT'),
            card([
              tile(
                  InIcons.shield,
                  'Safety Center',
                  'Report, block, hidden words',
                  () => _push(context, const SafetyCenterScreen())),
              tile(
                  InIcons.mute,
                  'Room moderation',
                  'Slow mode, filters, co-hosts',
                  () => _push(context, const RoomModerationScreen())),
              tile(InIcons.lock, 'Security', 'Devices',
                  () => _push(context, const SecurityScreen())),
              tile(InIcons.verified, 'Verification', 'Phone, photo, ID',
                  () => _push(context, const VerificationScreen())),
              tile(
                  InIcons.eyeoff,
                  'Privacy centre',
                  'Who sees you and your data',
                  () => _push(context, const PrivacyCenterScreen())),
            ]),
            label('MORE'),
            card([
              tile(InIcons.trophy, 'Achievements', 'Milestones and rewards',
                  () => _push(context, const AchievementsScreen())),
              tile(InIcons.crown, 'Leaderboards', 'Top hosts and gifters',
                  () => _push(context, const LeaderboardsScreen())),
              tile(InIcons.wallet, 'Wallet', 'Coins, gifts and cash out',
                  () => _push(context, const WalletScreen())),
            ]),
          ]),
    );
  }
}

// ------------------------------------------------------------ Vibe match

/// People in the same mood right now (GET /discover/vibe), best match
/// first. Opening it sets your own vibe so others can find you too.
class VibeMatchScreen extends StatefulWidget {
  final String vibe;
  const VibeMatchScreen({super.key, this.vibe = 'movie'});

  @override
  State<VibeMatchScreen> createState() => _VibeMatchScreenState();
}

class _VibeMatchScreenState extends State<VibeMatchScreen> {
  late String _vibe = widget.vibe;
  List<Map<String, dynamic>>? _people;

  @override
  void initState() {
    super.initState();
    _setVibe(_vibe);
  }

  Future<void> _setVibe(String v) async {
    setState(() {
      _vibe = v;
      _people = null;
    });
    try {
      await ApiClient.post('/discover/vibe', body: {'vibe': v});
      final d = await ApiClient.get('/discover/vibe?vibe=$v') as Map;
      if (!mounted || _vibe != v) return;
      setState(() => _people = (d['people'] as List)
          .cast<Map>()
          .map(Map<String, dynamic>.from)
          .toList());
    } catch (_) {
      if (mounted) setState(() => _people = []);
    }
  }

  Future<void> _stop() async {
    try {
      await ApiClient.post('/discover/vibe', body: {'vibe': null});
    } catch (_) {}
    if (mounted) Navigator.of(context).maybePop();
  }

  (String, String, String) get _copy => switch (_vibe) {
        'talk' => ('to talk', 'Say hi', 'voice'),
        'play' => ('to play a game', 'Invite to play', 'game'),
        'music' => ('music', 'Invite to listen', 'voice'),
        _ => ('a movie night', 'Invite to watch', 'watch'),
      };

  @override
  Widget build(BuildContext context) {
    final people = _people;
    final (want, invite, roomType) = _copy;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(context, 'Vibe Match', actions: [
        TextButton(onPressed: _stop, child: const Text('Stop my vibe')),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
              alignment: Alignment.centerLeft,
              child: _VibeChips(selected: _vibe, onPick: _setVibe)),
        ),
        Expanded(
          child: people == null
              ? const Center(child: Spinner())
              : people.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            'Nobody else wants $want right now. You’re on the list — people who pick the same vibe will see you.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textDim)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        Text(
                            people.length == 1
                                ? '1 person wants $want right now'
                                : '${people.length} people want $want right now',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        for (final p in people)
                          _VibePerson(
                            p: p,
                            invite: invite,
                            onInvite: () => _push(
                                context,
                                MessageThreadScreen(
                                    userId: p['id'] as String,
                                    name: p['name'] as String? ?? '',
                                    avatarUrl: p['avatarUrl'] as String?)),
                          ),
                      ],
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton(
              onPressed: () =>
                  _push(context, LobbyCreateScreen(initialRoomType: roomType)),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: Text(switch (_vibe) {
                'talk' => 'Start an open voice room',
                'play' => 'Start an open game room',
                'music' => 'Start an open music room',
                _ => 'Start an open watch party',
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

class _VibePerson extends StatelessWidget {
  final Map<String, dynamic> p;
  final String invite;
  final VoidCallback onInvite;
  const _VibePerson(
      {required this.p, required this.invite, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final details = [
      ...((p['sharedInterests'] as List?) ?? []).take(1).map((e) => '$e'),
      ...((p['languages'] as List?) ?? []).map((e) => '$e'),
      if (p['distanceKm'] != null)
        '${p['distanceKm']} km'
      else if ((p['city'] as String?)?.isNotEmpty == true)
        p['city'] as String,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Avatar(
            src: p['avatarUrl'] as String?,
            name: p['name'] as String?,
            size: AvatarSize.md),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                p['age'] == null
                    ? '${p['name']}'
                    : '${(p['name'] as String? ?? '').split(' ').first}, ${p['age']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (details.isNotEmpty)
              Text(details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text('${p['vibeScore']}% vibe',
                style: const TextStyle(
                    color: AppColors.lilac,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onInvite,
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12)),
          child: Text(invite, style: const TextStyle(fontSize: 12.5)),
        ),
      ]),
    );
  }
}

// --------------------------------------------------------- Creator studio

/// Overview, earnings, co-hosts and availability for creators (GET /studio).
class CreatorStudioScreen extends StatefulWidget {
  const CreatorStudioScreen({super.key});

  @override
  State<CreatorStudioScreen> createState() => _CreatorStudioScreenState();
}

class _CreatorStudioScreenState extends State<CreatorStudioScreen> {
  Map<String, dynamic>? _studio;
  Map<String, dynamic>? _cashout;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/studio'),
        ApiClient.get('/wallet/cashout-info')
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _studio = Map<String, dynamic>.from(results[0] as Map);
        _cashout = Map<String, dynamic>.from(results[1] as Map);
      });
    } catch (_) {
      if (mounted) setState(() => _studio = {});
    }
  }

  /// Coins you could cash out, in rupees (same rate as the cash out screen).
  String get _rupees {
    final coins = (_studio?['coinBalance'] as num?) ?? 0;
    final perRupee = (_cashout?['coinsPerRupee'] as num?) ?? 0;
    final fraction = (_cashout?['cashoutFraction'] as num?) ?? 1;
    if (perRupee <= 0) return '₹ —';
    return '₹ ${formatNumber((coins * fraction / perRupee).floor())}';
  }

  Future<void> _editAvailability() async {
    final c =
        TextEditingController(text: _studio?['availability'] as String? ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('When do you usually go live?'),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 60,
            decoration:
                const InputDecoration(hintText: 'e.g. Fri, Sat · 9 PM')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    try {
      await ApiClient.patch('/studio', body: {'availability': v});
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _studio;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          leading: InIconButton(InIcons.back,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop()),
          title: const Text('Creator Studio'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Earnings'),
            Tab(text: 'Co-hosts'),
            Tab(text: 'Availability'),
          ]),
        ),
        body: s == null
            ? const Center(child: Spinner())
            : s.isEmpty
                ? const Center(
                    child: Text('Couldn’t load your studio',
                        style: TextStyle(color: AppColors.textDim)))
                : TabBarView(children: [
                    _overview(s),
                    _earnings(s),
                    _coHosts(s),
                    _availability(s),
                  ]),
      ),
    );
  }

  Widget _earningsCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1326),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3B2A55))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Available earnings',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 4),
          Text(_rupees,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _push(context, const WalletCashoutScreen()),
                child: const Text('Cash out'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _push(context, const WalletScreen()),
                child: const Text('History'),
              ),
            ),
          ]),
        ]),
      );

  Widget _overview(Map<String, dynamic> s) {
    final live = Map<String, dynamic>.from(s['live'] as Map);
    final followers = Map<String, dynamic>.from(s['followers'] as Map);
    final gifts = Map<String, dynamic>.from(s['gifts'] as Map);
    String change(num? v) =>
        v == null || v == 0 ? '—' : '${v > 0 ? '+' : ''}$v%';
    Widget stat(String label, String value, num? pct) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 12)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
              ),
              Text(change(pct),
                  style: TextStyle(
                      color:
                          (pct ?? 0) >= 0 ? AppColors.success : AppColors.pink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      _earningsCard(),
      const SizedBox(height: 12),
      Row(children: [
        stat('Room visits', formatNumber(live['roomVisits']), null),
        const SizedBox(width: 8),
        stat('Followers', '+${formatNumber(followers['gained'])}',
            followers['change'] as num?),
        const SizedBox(width: 8),
        stat('Gifts', compactCount((gifts['coins'] as num?)?.toInt() ?? 0),
            gifts['change'] as num?),
      ]),
      const SizedBox(height: 18),
      const Text('Audience · last 28 days',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      StudioStats(studio: s),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const InIcon(InIcons.users, size: 20, color: AppColors.lilac),
        title: const Text('Co-host manager'),
        subtitle: Text(
            s['coHosts'] == 1 ? '1 co-host' : '${s['coHosts']} co-hosts',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        onTap: () => _push(context, const RoomModerationScreen()),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading:
            const InIcon(InIcons.calendar, size: 20, color: AppColors.lilac),
        title: const Text('Availability'),
        subtitle: Text(s['availability'] as String? ?? 'Not set',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        onTap: _editAvailability,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const InIcon(InIcons.chart, size: 20, color: AppColors.lilac),
        title: const Text('Creator analytics'),
        subtitle: const Text('Streams, gifts by day',
            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        onTap: () => _push(context, const LivestreamDashboardScreen()),
      ),
    ]);
  }

  Widget _earnings(Map<String, dynamic> s) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _earningsCard(),
        const SizedBox(height: 12),
        StudioStats(studio: s),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _push(context, const LivestreamDashboardScreen()),
          child: const Text('Gifts & earnings by stream'),
        ),
      ]);

  Widget _coHosts(Map<String, dynamic> s) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            s['coHosts'] == 0
                ? 'No co-hosts yet. Co-hosts help run your rooms: approving mics, muting and removing people.'
                : 'You have ${s['coHosts']} co-host${s['coHosts'] == 1 ? '' : 's'}.',
            style: const TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => const RoomModerationScreen()))
              .then((_) => _load()),
          child: const Text('Manage co-hosts'),
        ),
      ]);

  Widget _availability(Map<String, dynamic> s) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Let followers know when to catch you live.',
            style: TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 12),
        ListTile(
          tileColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading:
              const InIcon(InIcons.calendar, size: 20, color: AppColors.lilac),
          title: Text(s['availability'] as String? ?? 'Not set',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: TextButton(
              onPressed: _editAvailability, child: const Text('Edit')),
        ),
      ]);
}
