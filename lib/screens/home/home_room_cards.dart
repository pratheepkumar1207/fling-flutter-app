import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';

/// Card for an invite or a scheduled room (no one inside yet).
class HomeInviteCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool upcoming;
  final VoidCallback onTap;
  const HomeInviteCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.upcoming = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1028),
            border: Border.all(color: const Color(0xFF3A2A55)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            InIcon(upcoming ? InIcons.calendar : InIcons.mail,
                size: 20, color: AppColors.lilac),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textDim)),
                  ]),
            ),
            Text(upcoming ? 'View' : 'Join',
                style: const TextStyle(
                    color: AppColors.lilac,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// "STARTS IN 2D 4H" for a scheduled room.
String eventCountdown(DateTime at, DateTime now) {
  final d = at.difference(now);
  if (d.isNegative || d.inMinutes < 1) return 'STARTING NOW';
  if (d.inDays > 0) return 'STARTS IN ${d.inDays}D ${d.inHours % 24}H';
  if (d.inHours > 0) return 'STARTS IN ${d.inHours}H ${d.inMinutes % 60}M';
  return 'STARTS IN ${d.inMinutes}M';
}

/// A scheduled room: countdown, who's going and a Remind toggle
/// (POST /rooms/:id/remind).
class HomeEventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  final Future<bool?> Function()? onRemind;
  const HomeEventCard(
      {super.key, required this.event, required this.onTap, this.onRemind});

  @override
  State<HomeEventCard> createState() => _HomeEventCardState();
}

class _HomeEventCardState extends State<HomeEventCard> {
  late bool _remind = widget.event['remindMe'] == true;
  late int _going = asNum(widget.event['goingCount']).toInt();

  Future<void> _toggle() async {
    final r = await widget.onRemind?.call();
    if (r == null || !mounted) return;
    setState(() {
      if (r != _remind) _going += r ? 1 : -1;
      _remind = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final at = DateTime.tryParse('${ev['scheduledAt']}')?.toLocal();
    final kind = switch (ev['roomType']) {
      'voice' => 'Voice room',
      'game' => 'Game night',
      'live' => 'Live',
      _ => 'Watch party',
    };
    return Semantics(
      button: true,
      label: '${ev['title'] ?? 'Upcoming room'}, $kind',
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1028),
            border: Border.all(color: const Color(0xFF3A2A55)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const InIcon(InIcons.calendar, size: 20, color: AppColors.lilac),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (at != null)
                      Text(eventCountdown(at, DateTime.now()),
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.pink)),
                    Text(ev['title'] as String? ?? 'Upcoming room',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                        [
                          kind,
                          if (_going > 0) '$_going going',
                          if (ev['hostName'] != null) 'by ${ev['hostName']}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textDim)),
                  ]),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _toggle,
              style: TextButton.styleFrom(
                  foregroundColor:
                      _remind ? AppColors.textDim : AppColors.lilac),
              child: Text(_remind ? 'Reminded' : 'Remind'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "YOU'RE IN · Movie night" — the room you're still connected to.
class HomeInRoomBanner extends StatelessWidget {
  final String title;
  final String? speakingName;
  final VoidCallback onOpen;
  const HomeInRoomBanner(
      {super.key,
      required this.title,
      required this.onOpen,
      this.speakingName});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3A1F5C), Color(0xFF26163E)]),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const InIcon(InIcons.mic, size: 18, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("YOU'RE IN",
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppColors.success)),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (speakingName != null)
                      Text('${speakingName!.split(' ').first} is talking…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textDim)),
                  ]),
            ),
            const _JoinPill('Open'),
          ]),
        ),
      ),
    );
  }
}

/// A Reels Blend someone is watching right now: "You + Chitra · Rejoin".
class HomeBlendCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> members;
  final int watching;
  final VoidCallback onTap;
  const HomeBlendCard(
      {super.key,
      required this.title,
      required this.members,
      required this.watching,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reels Blend $title',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF2B1640), Color(0xFF1A1028)]),
            border: Border.all(color: const Color(0xFF3A2A55)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            AvatarStack(members, max: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Kind(InIcons.play, 'REELS BLEND', Color(0xFFFF7A9A)),
                    const SizedBox(height: 2),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('$watching watching now',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.success)),
                  ]),
            ),
            const _JoinPill('Rejoin'),
          ]),
        ),
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final int max;
  const AvatarStack(this.members, {super.key, this.max = 4});

  @override
  Widget build(BuildContext context) {
    final shown = members.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 24.0 + (shown.length - 1) * 18,
      height: 24,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * 18.0,
            child: Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.bg),
              padding: const EdgeInsets.all(1.5),
              child: SizedBox(
                width: 21,
                height: 21,
                child: FittedBox(
                  child: Avatar(
                      src: shown[i]['avatarUrl'] as String?,
                      name: shown[i]['name'] as String?,
                      size: AvatarSize.sm),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Kind extends StatelessWidget {
  final InIconData icon;
  final String label;
  final Color color;
  const _Kind(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      InIcon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: color)),
      ),
    ]);
  }
}

class _JoinPill extends StatelessWidget {
  final String label;
  const _JoinPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
      // Sized to its label, not stretched by a wide parent.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
