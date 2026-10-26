import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../theme/room_themes.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../live/live_feed_screen.dart' show LiveTag;

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
        const _Kind(InIcons.mic, 'VOICE ROOM', Color(0xFFB97CF8)),
        const SizedBox(height: 3),
        Text(
            room['topic'] as String? ??
                room['title'] as String? ??
                'Voice room',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ClipRect(
              child: Row(children: [
                for (var i = 0; i < speakers.length; i++) ...[
                  _Speaker(member: speakers[i], host: i == 0),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$_count here',
                style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
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
    return SizedBox(
      height: 150,
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Kind(InIcons.live, 'LIVE', AppColors.pink),
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
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(room['title'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textDim)),
                      ]),
                ),
              ]),
              const Spacer(),
              const Align(
                  alignment: Alignment.centerRight, child: _JoinPill('Watch')),
            ]),
          ),
        ),
      ]),
    );
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
