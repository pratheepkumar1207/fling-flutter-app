import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../theme/room_themes.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../live/live_feed_screen.dart' show LiveTag;
import '../../widgets/live_extras.dart' show compactCount;

/// Home "Happening now" cards — one look per room type, painted with the
/// room's own lobby theme so each reads like a window into that lobby.
class HomeRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const HomeRoomCard({super.key, required this.room, required this.onTap});

  String get _type => room['roomType'] as String? ?? 'watch';

  List<Map<String, dynamic>> get _members =>
      ((room['members'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  int get _count => asNum(room['memberCount']).toInt();

  @override
  Widget build(BuildContext context) {
    final theme = RoomTheme.byId(room['theme'] as String?);
    final body = switch (_type) {
      'voice' => _voice(),
      'game' => _game(),
      'live' => _live(),
      _ => _watch(),
    };
    return Semantics(
      button: true,
      label: '${_kindLabel()} ${room['title'] ?? ''}, $_count inside',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              gradient: theme.bgGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child:
                ClipRRect(borderRadius: BorderRadius.circular(22), child: body),
          ),
        ),
      ),
    );
  }

  String _kindLabel() => switch (_type) {
        'voice' => 'Voice room',
        'game' => 'Game room',
        'live' => 'Live',
        _ => 'Watch party',
      };

  Widget _watch() {
    final thumb = room['nowPlayingThumbnail'] as String?;
    final title = room['nowPlayingTitle'] as String? ??
        room['title'] as String? ??
        'Untitled room';
    final pos = (room['playbackPosition'] as num?)?.toDouble();
    final source = (room['sourceType'] as String?)?.toUpperCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 118,
        child: Stack(fit: StackFit.expand, children: [
          if (thumb != null && thumb.isNotEmpty)
            AppImage(source: thumb, fit: BoxFit.cover)
          else
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2B1418), Color(0xFF140A0C)]))),
          const Positioned(top: 10, left: 10, child: LiveTag()),
          if (source != null && source.isNotEmpty)
            Positioned(
              left: 10,
              bottom: 10,
              child: _Tag(
                  source == 'YOUTUBE' ? 'YOUTUBE' : source,
                  source == 'NETFLIX'
                      ? const Color(0xFFE50914)
                      : Colors.black54),
            ),
          if (room['isPlaying'] == true)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: AppGradients.brand)),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _privacyKind() ??
                  const _Kind(InIcons.tv, 'WATCH PARTY', Color(0xFFFF7A9A)),
              const SizedBox(height: 3),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                AvatarStack(_members),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                      '$_count watching${pos != null ? ' · ${_clock(pos)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textDim)),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          const _JoinPill('Join'),
        ]),
      ),
    ]);
  }

  Widget _voice() {
    final speakers = _members.take(3).toList();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (room['communityName'] != null)
          _Kind(InIcons.users, 'COMMUNITY ROOM · ${room['communityName']}',
              const Color(0xFF7FD6B0))
        else
          _privacyKind() ??
              const _Kind(InIcons.mic, 'VOICE ROOM', Color(0xFFB97CF8)),
        const SizedBox(height: 3),
        Text(
            room['topic'] as String? ??
                room['title'] as String? ??
                'Voice room',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (room['speakingName'] != null) ...[
          const SizedBox(height: 3),
          Row(children: [
            const InIcon(InIcons.mic, size: 11, color: AppColors.success),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                  '${(room['speakingName'] as String).split(' ').first} is talking…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.success)),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            // Extra speakers are cut off at the edge rather than overflowing.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(children: [
                for (var i = 0; i < speakers.length; i++) ...[
                  _Speaker(member: speakers[i], host: i == 0),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(_micLine(),
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textDim)),
            ),
            const SizedBox(height: 8),
            const _JoinPill('Join'),
          ]),
        ]),
      ]),
    );
  }

  Widget _game() {
    const seats = 4;
    final filled = _members.take(_count.clamp(0, seats)).toList();
    final free = (seats - _count).clamp(0, seats);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18)),
          child: const Center(
              child: InIcon(InIcons.game, size: 30, color: Color(0xFF8FB0FF))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Kind(
                InIcons.game,
                'GAME ROOM${room['gameType'] != null ? ' · ${(room['gameType'] as String).toUpperCase()}' : ''}',
                const Color(0xFF8FB0FF)),
            const SizedBox(height: 3),
            Text(room['title'] as String? ?? 'Game room',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final m in filled) _SmallAvatar(m),
                  for (var i = 0; i < free && i < 2; i++)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white38, width: 1.5)),
                      child: const Center(
                          child: InIcon(InIcons.plus,
                              size: 12, color: Colors.white)),
                    ),
                  if (free > 0)
                    Text('$free free',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textDim)),
                ]),
          ]),
        ),
        _JoinPill(free > 0 ? 'Take seat' : 'Watch'),
      ]),
    );
  }

  Widget _live() {
    final thumb = room['nowPlayingThumbnail'] as String?;
    final host = room['hostName'] as String? ?? '';
    // At least 150 tall, taller when big text needs the room.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 120,
            child: Stack(fit: StackFit.expand, children: [
              if (thumb != null && thumb.isNotEmpty)
                AppImage(source: thumb, fit: BoxFit.cover)
              else
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3A1430), Color(0xFF0E0C14)]))),
              const Positioned(top: 8, left: 8, child: LiveTag()),
              Positioned(
                  left: 8,
                  bottom: 8,
                  child: _Tag('$_count watching', Colors.black54)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    room['inPk'] == true
                        ? _Kind(
                            InIcons.bolt,
                            room['pkOpponentHost'] != null
                                ? 'PK BATTLE · vs ${room['pkOpponentHost']}'
                                : 'PK BATTLE',
                            AppColors.gold)
                        : const _Kind(InIcons.live, 'LIVE', AppColors.pink),
                    const SizedBox(height: 6),
                    Row(children: [
                      Avatar(name: host, size: AvatarSize.sm, ring: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(host,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              Text(room['title'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textDim)),
                            ]),
                      ),
                    ]),
                    const Spacer(),
                    if (_liveLine() != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(_liveLine()!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textDim)),
                      ),
                    Align(
                        alignment: Alignment.centerRight,
                        child: _JoinPill(
                            room['inPk'] == true ? 'Pick a side' : 'Watch')),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  // "FRIENDS OF BALA" on rooms only some people can see.
  _Kind? _privacyKind() {
    final host = (room['hostName'] as String? ?? '').split(' ').first;
    return switch (room['visibility']) {
      'friends' => _Kind(InIcons.lock, 'FRIENDS OF ${host.toUpperCase()}',
          const Color(0xFFFFC56B)),
      'subscribers' => _Kind(InIcons.lock, 'FOLLOWERS OF ${host.toUpperCase()}',
          const Color(0xFFFFC56B)),
      _ => null,
    };
  }

  String _micLine() {
    final onMic = asNum(room['onMicCount']).toInt();
    if (onMic == 0) return '$_count here';
    final listening = (_count - onMic).clamp(0, _count);
    return '$onMic on mic · $listening listening';
  }

  String? _liveLine() {
    final parts = <String>[
      if (room['inPk'] == true) '$_count watching',
      if (asNum(room['giftsToday']) > 0)
        '${compactCount(asNum(room['giftsToday']).toInt())} today',
      if (room['dailyRank'] != null) 'Daily #${room['dailyRank']}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _clock(double seconds) {
    final s = seconds.round();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
  }
}

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

class _Speaker extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool host;
  const _Speaker({required this.member, required this.host});

  @override
  Widget build(BuildContext context) {
    final name = (member['name'] as String? ?? '').split(' ').first;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                host ? const LinearGradient(colors: AppGradients.brand) : null),
        child: SizedBox(
          width: 38,
          height: 38,
          child: FittedBox(
            child: Avatar(
                src: member['avatarUrl'] as String?,
                name: member['name'] as String?,
                size: AvatarSize.md),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Row(children: [
        if (host)
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: InIcon(InIcons.crown,
                size: 10, color: AppColors.gold, filled: true),
          ),
        Text(name, style: const TextStyle(fontSize: 10)),
      ]),
    ]);
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

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
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

class _SmallAvatar extends StatelessWidget {
  final Map<String, dynamic> member;
  const _SmallAvatar(this.member);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: FittedBox(
          child: Avatar(
              src: member['avatarUrl'] as String?,
              name: member['name'] as String?,
              size: AvatarSize.sm),
        ),
      );
}
