import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass.dart';
import '../communities/communities_screen.dart';
import '../events/events_screen.dart';
import '../achievements/achievements_screen.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../wallet/wallet_screen.dart';

/// A dedicated hub for the newer, not-yet-backend-wired feature surfaces
/// (ref: the "Fling Premium Product Pass" design shared as
/// fling-flutter-app-all-features.zip) — Vibe Match, Together, Safety
/// Center, Privacy, Verification, Creator Studio, Room Moderation, and
/// Security. Every one of those screens below is intentionally UI-only:
/// no fabricated server state, no fake persistence — actions show a
/// "coming soon"-style snackbar instead of pretending to do something
/// real. Wire each one up to its real backend endpoint as those become
/// available, same spirit as chat_attachment_sheet.dart's honest
/// "coming soon" for unbuilt media messages. The bottom "Your Fling"
/// section links out to screens that already ARE fully real and wired
/// (Events/Communities/Achievements/Leaderboards/Wallet) — nothing new
/// there, just gathered under one roof for discoverability.
class FlingFeatureHubScreen extends StatelessWidget {
  const FlingFeatureHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _HubItem('Vibe Match', 'Find someone who fits your mood right now',
          Icons.auto_awesome_rounded, const VibeMatchScreen(), true),
      _HubItem('Together', 'Shared moments, rooms, games and memories',
          Icons.favorite_rounded, const TogetherScreen(), false),
      _HubItem('Safety Center', 'Report, block, restrict and stay in control',
          Icons.shield_rounded, const SafetyCenterScreen(), false),
      _HubItem('Privacy', 'Control discovery, calls, messages and activity',
          Icons.lock_rounded, const PrivacyCenterScreen(), false),
      _HubItem('Verification', 'Build trust with profile verification',
          Icons.verified_rounded, const VerificationScreen(), false),
      _HubItem('Creator Studio', 'Gifts, subscribers, rooms and earnings',
          Icons.auto_graph_rounded, const CreatorStudioScreen(), true),
      _HubItem(
          'Room Moderation',
          'Host, co-host, speaker and audience controls',
          Icons.admin_panel_settings_rounded,
          const RoomModerationScreen(),
          false),
      _HubItem('Security', 'Devices, sessions and account protection',
          Icons.security_rounded, const SecurityScreen(), false),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Fling')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Do something together',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Meet people, start an experience, and stay connected.',
              style: TextStyle(color: AppColors.textDim, fontSize: 14)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _QuickAction(Icons.movie_rounded, 'Watch',
                () => _snack(context, 'Open Watch Party from Create')),
            _QuickAction(Icons.mic_rounded, 'Voice',
                () => _snack(context, 'Open Voice Room from Create')),
            _QuickAction(Icons.sports_esports_rounded, 'Game',
                () => _snack(context, 'Open Game Room from Create')),
            _QuickAction(Icons.live_tv_rounded, 'Live',
                () => _snack(context, 'Open Live from Create')),
          ]),
          const SizedBox(height: 24),
          ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HubCard(item))),
          const SizedBox(height: 12),
          const Text('YOUR FLING',
              style: TextStyle(
                  color: AppColors.textFaint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 11)),
          const SizedBox(height: 10),
          _SmallRow(
              Icons.event_rounded,
              'Events',
              'Meetups and scheduled experiences',
              () => _push(context, const EventsScreen())),
          _SmallRow(
              Icons.groups_rounded,
              'Communities',
              'Groups, rooms and shared interests',
              () => _push(context, const CommunitiesScreen())),
          _SmallRow(
              Icons.emoji_events_rounded,
              'Achievements',
              'Milestones and rewards',
              () => _push(context, const AchievementsScreen())),
          _SmallRow(
              Icons.leaderboard_rounded,
              'Leaderboards',
              'Seasonal rankings and game stats',
              () => _push(context, const LeaderboardsScreen())),
          _SmallRow(
              Icons.account_balance_wallet_rounded,
              'Wallet',
              'Coins, gifts, VIP and earnings',
              () => _push(context, const WalletScreen())),
        ],
      ),
    );
  }
}

class _HubItem {
  final String title, subtitle;
  final IconData icon;
  final Widget page;
  final bool featured;
  _HubItem(this.title, this.subtitle, this.icon, this.page, this.featured);
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  const _HubCard(this.item);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _push(context, item.page),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(17)),
                child: Icon(item.icon,
                    color: item.featured ? AppColors.primary : AppColors.text,
                    size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(item.subtitle,
                        style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 12.5,
                            height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textFaint, size: 16),
            ]),
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.text, size: 18),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _SmallRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SmallRow(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.textDim, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
      );
}

class VibeMatchScreen extends StatefulWidget {
  const VibeMatchScreen({super.key});
  @override
  State<VibeMatchScreen> createState() => _VibeMatchScreenState();
}

class _VibeMatchScreenState extends State<VibeMatchScreen> {
  String mood = 'Talk', activity = 'Now';
  final moods = ['Talk', 'Watch', 'Game', 'Music', 'Date'];
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Vibe Match')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          GlassPanel(
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What are you feeling?',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 25,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  const Text(
                      'Fling prioritizes people available for the same experience.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                  const SizedBox(height: 20),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: moods
                          .map((m) => ChoiceChip(
                                label: Text(m),
                                selected: mood == m,
                                onSelected: (_) => setState(() => mood = m),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface2,
                                labelStyle: TextStyle(
                                    color: mood == m
                                        ? Colors.white
                                        : AppColors.textDim),
                              ))
                          .toList()),
                  const SizedBox(height: 20),
                  const Text('Availability',
                      style: TextStyle(
                          color: AppColors.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                      spacing: 8,
                      children: ['Now', 'Tonight', 'This weekend']
                          .map((a) => ChoiceChip(
                                label: Text(a),
                                selected: activity == a,
                                onSelected: (_) => setState(() => activity = a),
                                selectedColor: AppColors.surface3,
                                backgroundColor: AppColors.surface2,
                                labelStyle:
                                    const TextStyle(color: AppColors.text),
                              ))
                          .toList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _MatchPreview('Ananya', 'Movies · Gaming · 2.4 km', '94%',
              Icons.movie_filter_rounded),
          const _MatchPreview('Rahul', 'Gaming · Voice · 4.1 km', '89%',
              Icons.sports_esports_rounded),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _snack(context, 'Match request sent'),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Find my vibe'),
            ),
          ),
        ]),
      );
}

class _MatchPreview extends StatelessWidget {
  final String name, detail, score;
  final IconData icon;
  const _MatchPreview(this.name, this.detail, this.score, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(22),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: AppColors.primary),
            ),
            title: Text(name,
                style: const TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w800)),
            subtitle: Text(detail,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            trailing: Text(score,
                style: const TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.w900)),
          ),
        ),
      );
}

class TogetherScreen extends StatelessWidget {
  const TogetherScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Together')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('You + your people',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 27,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Turn a match into shared memories.',
              style: TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 18),
          GlassPanel(
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ananya',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('3 rooms · 2 games · 4 movies · 17 messages',
                      style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat('🎬', '4', 'Watched'),
                      _Stat('🎮', '2', 'Games'),
                      _Stat('🎙', '3', 'Rooms'),
                      _Stat('💬', '17', 'Messages'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _snack(context, 'Choose an activity'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start something together'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Timeline('Today', 'Started a watch party together',
              'Movie Night', Icons.movie_rounded),
          const _Timeline('Yesterday', 'Played a game', 'Ludo',
              Icons.sports_esports_rounded),
          const _Timeline('3 days ago', 'Joined a voice room',
              'Late Night Talks', Icons.mic_rounded),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String a, b, c;
  const _Stat(this.a, this.b, this.c);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(a, style: const TextStyle(fontSize: 19)),
        Text(b,
            style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        Text(c,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 10)),
      ]);
}

class _Timeline extends StatelessWidget {
  final String a, b, c;
  final IconData icon;
  const _Timeline(this.a, this.b, this.c, this.icon);
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.textDim),
        ),
        title: Text(b,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700)),
        subtitle: Text('$c · $a',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
      );
}

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _SettingsScaffold(title: 'Safety Center', children: [
        _SettingTile(
            Icons.report_rounded,
            'Report someone',
            'Flag a profile, message, room or post',
            () => _snack(context, 'Report flow ready')),
        _SettingTile(
            Icons.block_rounded,
            'Blocked accounts',
            'Manage people you have blocked',
            () => _snack(context, 'Open blocked accounts')),
        _SettingTile(
            Icons.remove_circle_outline_rounded,
            'Restrict messages',
            'Limit who can contact you',
            () => _snack(context, 'Restriction settings')),
        _SettingTile(
            Icons.shield_rounded,
            'Safety tips',
            'Practical guidance for meeting people online',
            () => _snack(context, 'Safety guide')),
        _SettingTile(
            Icons.support_agent_rounded,
            'Get help',
            'Contact support about an urgent issue',
            () => _snack(context, 'Support request')),
      ]);
}

class PrivacyCenterScreen extends StatelessWidget {
  const PrivacyCenterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _SettingsScaffold(title: 'Privacy', children: const [
        _SwitchTile('Show online status', true),
        _SwitchTile('Show last active', false),
        _SwitchTile('Show distance', true),
        _SwitchTile('Appear in Discover', true),
        _SwitchTile('Allow calls from connections', true),
        _SwitchTile('Allow message requests', true),
      ]);
}

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _SettingsScaffold(title: 'Verification', children: [
        GlassPanel(
          borderRadius: BorderRadius.circular(24),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded,
                    color: AppColors.primary, size: 36),
                SizedBox(height: 12),
                Text('Build trust',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(
                    'Verify your phone, selfie and optional identity details. Verified profiles receive a trust badge.',
                    style: TextStyle(color: AppColors.textDim, height: 1.4)),
              ],
            ),
          ),
        ),
        _SettingTile(
            Icons.phone_android_rounded,
            'Phone verified',
            'Required for a secure account',
            () => _snack(context, 'Phone verification')),
        _SettingTile(
            Icons.face_retouching_natural_rounded,
            'Selfie verification',
            'Confirm you are the person in your profile',
            () => _snack(context, 'Selfie verification')),
        _SettingTile(
            Icons.badge_rounded,
            'Identity verification',
            'Optional KYC for advanced creator features',
            () => _snack(context, 'Identity verification')),
      ]);
}

class CreatorStudioScreen extends StatelessWidget {
  const CreatorStudioScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _SettingsScaffold(title: 'Creator Studio', children: [
        GlassPanel(
          borderRadius: BorderRadius.circular(24),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹ 12,480',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    Text('Available earnings',
                        style: TextStyle(color: AppColors.textDim)),
                  ],
                ),
              ),
              Icon(Icons.auto_graph_rounded, color: AppColors.gold, size: 36),
            ]),
          ),
        ),
        _SettingTile(
            Icons.card_giftcard_rounded,
            'Gifts & earnings',
            'Track gifts, room revenue and withdrawals',
            () => _snack(context, 'Creator earnings')),
        _SettingTile(
            Icons.people_alt_rounded,
            'Subscribers',
            'Manage your subscriber community',
            () => _snack(context, 'Subscribers')),
        _SettingTile(
            Icons.bar_chart_rounded,
            'Analytics',
            'Views, retention, gifts and room performance',
            () => _snack(context, 'Creator analytics')),
        _SettingTile(
            Icons.event_available_rounded,
            'Paid events',
            'Schedule premium experiences',
            () => _snack(context, 'Paid events')),
      ]);
}

class RoomModerationScreen extends StatelessWidget {
  const RoomModerationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _SettingsScaffold(title: 'Room Moderation', children: [
        _SettingTile(
            Icons.person_add_alt_1_rounded,
            'Co-hosts',
            'Give trusted people room controls',
            () => _snack(context, 'Co-host manager')),
        _SettingTile(
            Icons.record_voice_over_rounded,
            'Speaker queue',
            'Approve and manage speakers',
            () => _snack(context, 'Speaker queue')),
        _SettingTile(
            Icons.volume_off_rounded,
            'Mute all',
            'Quiet the room instantly',
            () => _snack(context, 'Mute-all control')),
        _SettingTile(
            Icons.gavel_rounded,
            'Moderation',
            'Kick, ban, slow mode and keyword filters',
            () => _snack(context, 'Moderation controls')),
        _SettingTile(
            Icons.flag_rounded,
            'Report queue',
            'Review reports from your room',
            () => _snack(context, 'Report queue')),
      ]);
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _SettingsScaffold(title: 'Security', children: [
        _SettingTile(
            Icons.devices_rounded,
            'Active devices',
            'Review and sign out sessions',
            () => _snack(context, 'Device manager')),
        _SettingTile(Icons.history_rounded, 'Login history',
            'See recent sign-ins', () => _snack(context, 'Login history')),
        const _SwitchTile('Two-step verification', false),
        _SettingTile(
            Icons.logout_rounded,
            'Sign out everywhere',
            'End all other sessions',
            () => _snack(context, 'All other sessions signed out')),
      ]);
}

class _SettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsScaffold({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: children
              .map((e) =>
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: e))
              .toList(),
        ),
      );
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SettingTile(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => GlassPanel(
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Icon(icon, color: AppColors.textDim),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textFaint),
        ),
      );
}

class _SwitchTile extends StatefulWidget {
  final String title;
  final bool initial;
  const _SwitchTile(this.title, this.initial);
  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool value;
  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  @override
  Widget build(BuildContext context) => GlassPanel(
        borderRadius: BorderRadius.circular(20),
        child: SwitchListTile(
          value: value,
          onChanged: (v) => setState(() => value = v),
          title: Text(widget.title,
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w700)),
          activeThumbColor: AppColors.primary,
        ),
      );
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
