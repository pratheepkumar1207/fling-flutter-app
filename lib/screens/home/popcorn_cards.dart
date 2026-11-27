import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';

// Room cards for the Popcorn tab, one look per room type, built from the
// /rooms/browse payload (see routes/room.js): a wide list card, a grid
// tile and the tall Boosted card. The whole card is the tap target.

const _kCard = Color(0xFF000000);
const _kLine = Color(0xFFFFFFFF);
const _kDim = Color(0xFFFFFFFF);
const _kGreen = Color(0xFFFFFFFF);
const _kLive = Color(0xFFE8112D);

String _type(Map r) => r['roomType'] as String? ?? 'watch';
int _count(Map r) => asNum(r['memberCount']).toInt();

List<Map<String, dynamic>> _people(Map r) => ((r['members'] as List?) ?? [])
    .whereType<Map>()
    .map((m) => Map<String, dynamic>.from(m))
    .toList();

String? _friendHere(Map r) {
  final f = _people(r).where((m) => m['isFriend'] == true).firstOrNull;
  final name = (f?['name'] as String?)?.split(' ').first;
  return name == null || name.isEmpty ? null : '$name is here';
}

(Color, Color, InIconData, String) _gameLook(String? g) => switch (g) {
      'chess' => (const Color(0xFF000000), const Color(0xFFE8C48A),
          InIcons.game, 'Chess'),
      'ludo' => (const Color(0xFF000000), const Color(0xFFFFFFFF),
          InIcons.dice, 'Ludo'),
      'uno' => (const Color(0xFF000000), const Color(0xFFE8112D),
          InIcons.ticket, 'UNO'),
      'tictactoe' => (const Color(0xFF000000), const Color(0xFFFFFFFF),
          InIcons.hash, 'Tic Tac Toe'),
      'truth_or_dare' => (const Color(0xFF000000), const Color(0xFFFFFFFF),
          InIcons.flame, 'Truth or Dare'),
      _ => (const Color(0xFF000000), const Color(0xFFFFFFFF), InIcons.game,
          'Game'),
    };

String _sourceLabel(String? s) => switch (s) {
      'youtube' || 'youtube_surf' => 'YouTube',
      'drive' => 'Drive',
      'netflix' => 'Netflix',
      'amazon' => 'Prime',
      'hotstar' => 'Hotstar',
      'sonyliv' => 'SonyLIV',
      'sunnxt' => 'Sun NXT',
      'aha' => 'Aha',
      'airtel' || 'airtelxstream' => 'Airtel',
      _ => 'Watch',
    };

bool _isOtt(String? s) => const {
      'netflix',
      'amazon',
      'hotstar',
      'sonyliv',
      'sunnxt',
      'aha',
      'airtel',
      'airtelxstream'
    }.contains(s);

String _clock(num secs) {
  final s = secs.toInt();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(x)}' : '$m:${two(x)}';
}

String _liveFor(Map r) {
  final t = DateTime.tryParse(r['createdAt'] as String? ?? '');
  if (t == null) return '';
  final m = DateTime.now().difference(t.toLocal()).inMinutes;
  return m < 60 ? '${m.clamp(1, 59)} min' : '${m ~/ 60} h';
}

String _short(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

class _Chip extends StatelessWidget {
  final String text;
  final InIconData? icon;
  final Color color;
  final Color? bg;
  const _Chip(this.text, {this.icon, this.color = Colors.white, this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg ?? const Color(0xC0000000),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            InIcon(icon!, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  color: bg != null ? Colors.white : color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Face extends StatelessWidget {
  final Map m;
  final double size;
  final bool talking;
  const _Face(this.m, {this.size = 18, this.talking = false});

  @override
  Widget build(BuildContext context) {
    final url = m['avatarUrl'] as String?;
    final name = (m['name'] as String? ?? '?').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF000000),
        border: Border.all(
            color: talking ? _kGreen : _kCard, width: talking ? 2 : 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? AppImage(source: url, fit: BoxFit.cover)
          : Center(
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w700))),
    );
  }
}

Widget _faces(List<Map<String, dynamic>> people, {int max = 3}) {
  final shown = people.take(max).toList();
  if (shown.isEmpty) return const SizedBox.shrink();
  return SizedBox(
    width: 18 + (shown.length - 1) * 13.0,
    height: 18,
    child: Stack(children: [
      for (var i = 0; i < shown.length; i++)
        Positioned(left: i * 13.0, child: _Face(shown[i])),
    ]),
  );
}

/// The picture side of a card: poster for watch rooms, the host for talk
/// and live rooms, the game's art for game rooms.
class _Cover extends StatelessWidget {
  final Map<String, dynamic> room;
  final bool tall;
  const _Cover(this.room, {this.tall = false});

  @override
  Widget build(BuildContext context) {
    final r = room;
    final type = _type(r);
    switch (type) {
      case 'game':
        final (bg, fg, icon, label) = _gameLook(r['gameType'] as String?);
        return Container(
          color: bg,
          child: Stack(children: [
            Center(child: InIcon(icon, size: tall ? 44 : 34, color: fg)),
            Positioned(
                left: 7, top: 7, child: _Chip(label, color: fg)),
          ]),
        );
      case 'voice':
        final talking = r['speakingName'] != null;
        return Container(
          color: const Color(0xFF000000),
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _Face({
                  'avatarUrl': r['hostAvatarUrl'],
                  'name': r['hostName'],
                }, size: tall ? 64 : 44, talking: talking),
                if (talking) ...[
                  const SizedBox(height: 5),
                  const _Bars(),
                ],
              ]),
            ),
            const Positioned(
                left: 7,
                top: 7,
                child: _Chip('Talk',
                    icon: InIcons.mic, color: Color(0xFFFFFFFF))),
          ]),
        );
      case 'live':
        return Container(
          color: const Color(0xFF000000),
          child: Stack(children: [
            Center(
                child: _Face({
              'avatarUrl': r['hostAvatarUrl'],
              'name': r['hostName'],
            }, size: tall ? 64 : 46)),
            const Positioned(
                left: 7, top: 7, child: _Chip('● LIVE', bg: _kLive)),
            if (_liveFor(r).isNotEmpty)
              Positioned(right: 6, top: 7, child: _Chip(_liveFor(r))),
            Positioned(
                left: 7,
                bottom: 7,
                child:
                    _Chip(_short(_count(r)), icon: InIcons.eye)),
          ]),
        );
      default:
        final thumb = r['nowPlayingThumbnail'] as String?;
        final dur = asNum(r['duration']);
        final pos = asNum(r['playbackPosition']);
        final song = r['nowPlayingMediaMode'] == 'audio';
        return Container(
          color: const Color(0xFF000000),
          child: Stack(fit: StackFit.expand, children: [
            if (thumb != null && thumb.isNotEmpty)
              AppImage(source: thumb, fit: BoxFit.cover),
            Positioned(
                left: 7,
                top: 7,
                child: _Chip(
                    song ? 'Music' : _sourceLabel(r['sourceType'] as String?),
                    icon: song ? InIcons.music : InIcons.film,
                    color: const Color(0xFFE8112D))),
            Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: Color(0x99000000), shape: BoxShape.circle),
                child: Center(
                    child: InIcon(
                        r['isPlaying'] == true ? InIcons.play : InIcons.pause,
                        size: 12,
                        color: Colors.white)),
              ),
            ),
            if (dur > 0 && pos >= 0 && pos <= dur)
              Positioned(
                  right: 6,
                  bottom: 8,
                  child: _Chip(_clock(dur - pos))),
            if (dur > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: (pos / dur).clamp(0, 1).toDouble(),
                  minHeight: 3,
                  backgroundColor: const Color(0x2EFFFFFF),
                  valueColor: const AlwaysStoppedAnimation(_kLive),
                ),
              ),
          ]),
        );
    }
  }
}

class _Bars extends StatelessWidget {
  const _Bars();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in const [4.0, 9.0, 6.0, 10.0, 5.0])
            Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                  color: _kGreen, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      );
}

/// The lines on the right of a card, per room type.
List<Widget> _details(Map<String, dynamic> r) {
  const dim = TextStyle(color: _kDim, fontSize: 10.5);
  final people = _people(r);
  final count = _count(r);
  final friend = _friendHere(r);
  Widget line(String text, {Color color = _kDim}) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 10.5));
  Widget facesLine(String text, {List<Map<String, dynamic>>? who}) =>
      Row(children: [
        _faces(who ?? people),
        if ((who ?? people).isNotEmpty) const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: dim)),
      ]);
  switch (_type(r)) {
    case 'game':
      final game = r['game'] as Map?;
      final players = ((game?['playerIds'] as List?) ?? const []).length;
      final seats = game?['seats'] as int?;
      final status = game?['status'] as String?;
      final open = seats != null ? seats - players : null;
      final playingIds =
          ((game?['playerIds'] as List?) ?? const []).toSet();
      final seated =
          people.where((m) => playingIds.contains(m['userId'])).toList();
      final watching = (count - players).clamp(0, count);
      return [
        facesLine(seats != null ? '$players of $seats seats' : '$players playing',
            who: seated),
        if (status == 'playing')
          line(
              'Playing${watching > 0 ? ' · $watching watching' : ''}',
              color: const Color(0xFFFFD60A))
        else if (open != null && open > 0)
          line('$open seat${open == 1 ? '' : 's'} open', color: _kGreen)
        else if (open == 0)
          line('Full · watch the game')
        else
          line('Open to join', color: _kGreen),
      ];
    case 'voice':
      final onMic = people.where((m) => m['onStage'] == true).toList();
      final song = r['nowPlayingSongTitle'] as String?;
      final topic = r['topic'] as String?;
      return [
        if (topic != null && topic.isNotEmpty && topic != r['title'])
          line(topic),
        facesLine(
            onMic.isEmpty
                ? '$count listening'
                : '${onMic.length} on mic · ${(count - onMic.length).clamp(0, count)} listening',
            who: onMic.isEmpty ? people : onMic),
        if (friend != null)
          line(friend, color: _kGreen)
        else if (song != null && song.isNotEmpty)
          line('🎵 $song', color: const Color(0xFFFFFFFF)),
      ];
    case 'live':
      final gifts = asNum(r['giftsToday']).toInt();
      return [
        Row(children: [
          _Face({'avatarUrl': r['hostAvatarUrl'], 'name': r['hostName']}),
          const SizedBox(width: 6),
          Flexible(
              child: Text(r['hostName'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF), fontSize: 10.5))),
        ]),
        if (r['hostFollowed'] == true)
          line('Your friend · ${_liveFor(r)} live', color: _kGreen)
        else if (gifts > 0)
          line('🎁 $gifts coins in gifts today')
        else
          line('${_short(count)} watching'),
      ];
    default:
      final song = r['nowPlayingMediaMode'] == 'audio';
      final playing = r['nowPlayingSongTitle'] as String? ??
          r['nowPlayingTitle'] as String?;
      final ott = _isOtt(r['sourceType'] as String?);
      return [
        if (playing != null && playing.isNotEmpty && playing != r['title'])
          line('${song ? '🎵' : '🎬'} $playing',
              color: const Color(0xFFFFFFFF)),
        facesLine(
            '$count ${song ? 'listening' : 'watching'}${ott ? ' · sign in to watch' : ''}'),
        if (friend != null) line(friend, color: _kGreen),
      ];
  }
}

String _semantic(Map<String, dynamic> r) {
  final t = r['title'] as String? ?? 'Room';
  return switch (_type(r)) {
    'voice' => '$t, talk room, ${_count(r)} in',
    'game' => '$t, ${_gameLook(r['gameType'] as String?).$4} room',
    'live' => '$t, live, ${_count(r)} watching',
    _ => '$t, watch room, ${_count(r)} in',
  };
}

/// A wide list card: picture on the left, details on the right.
class PopcornRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const PopcornRoomCard(
      {super.key, required this.room, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final live = _type(room) == 'live';
    return Semantics(
      button: true,
      label: _semantic(room),
      excludeSemantics: true,
      child: Material(
        color: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: live ? const Color(0xFFFFFFFF) : _kLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: 104,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 128, child: _Cover(room)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(room['title'] as String? ?? 'Room',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      for (final w in _details(room)) ...[
                        const SizedBox(height: 4),
                        w,
                      ],
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A grid tile (two per row): picture on top, details below.
class PopcornRoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const PopcornRoomTile(
      {super.key, required this.room, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final details = _details(room);
    return Semantics(
      button: true,
      label: _semantic(room),
      excludeSemantics: true,
      child: Material(
        color: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: _type(room) == 'live'
                    ? const Color(0xFFFFFFFF)
                    : _kLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 4 / 3, child: _Cover(room)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room['title'] as String? ?? 'Room',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  details.last,
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A tall card for the Boosted row.
class PopcornBoostedCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const PopcornBoostedCard(
      {super.key, required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = _type(room);
    final (icon, color) = switch (type) {
      'voice' => (InIcons.mic, const Color(0xFFFFFFFF)),
      'game' => (InIcons.game, const Color(0xFFFFFFFF)),
      'live' => (InIcons.live, _kLive),
      _ => (InIcons.film, const Color(0xFFE8112D)),
    };
    final game = room['game'] as Map?;
    final seats = game?['seats'] as int?;
    final players = ((game?['playerIds'] as List?) ?? const []).length;
    final sub = type == 'game' && seats != null && seats > players
        ? '${seats - players} seats open'
        : '${_count(room)} in';
    return Semantics(
      button: true,
      label: 'Boosted. ${_semantic(room)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 118,
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFFFFF)),
          ),
          child: Stack(fit: StackFit.expand, children: [
            _Cover(room, tall: true),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0xE6000000), Color(0x00000000)],
                ),
              ),
            ),
            Positioned(
              left: 7,
              top: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD60A),
                    borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  InIcon(InIcons.bolt, size: 10, color: Color(0xFF000000)),
                  SizedBox(width: 2),
                  Text('Boosted',
                      style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    color: const Color(0xC0000000),
                    borderRadius: BorderRadius.circular(7)),
                child: Center(child: InIcon(icon, size: 12, color: color)),
              ),
            ),
            Positioned(
              left: 9,
              right: 9,
              bottom: 9,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(room['title'] as String? ?? 'Room',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _faces(_people(room), max: 2),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFFFFFFF), fontSize: 10)),
                      ),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-style room cards: the Popcorn list and boosted rooms in the feed.
// Picture (or banner) on top, the people playing or speaking inside it,
// then a sideways row of only the people watching or listening with the
// button on the right. [header] adds the host line used in the feed.

const _ludoColors = [
  Color(0xFFE8112D),
  Color(0xFFFFFFFF),
  Color(0xFFF6B21A),
  Color(0xFFFFFFFF),
];

class PopcornPostCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? header;
  const PopcornPostCard(
      {super.key,
      required this.room,
      required this.onTap,
      this.onLongPress,
      this.header});

  List<String> get _playerIds =>
      ((room['game'] as Map?)?['playerIds'] as List? ?? const [])
          .whereType<String>()
          .toList();

  // Only watchers / listeners: not the players, speakers or host.
  List<Map<String, dynamic>> _audience() {
    final players = _playerIds.toSet();
    return _people(room)
        .where((m) =>
            !players.contains(m['userId']) &&
            m['onStage'] != true &&
            m['userId'] != room['hostId'])
        .toList()
      ..sort((a, b) =>
          (b['isFriend'] == true ? 1 : 0) - (a['isFriend'] == true ? 1 : 0));
  }

  (String, Color) _button() {
    switch (_type(room)) {
      case 'game':
        final seats = (room['game'] as Map?)?['seats'] as int?;
        final open = seats == null || _playerIds.length < seats;
        return open
            ? ('Play', const Color(0xFFE8112D))
            : ('Watch', const Color(0xFFE8112D));
      case 'voice':
        return ('Join', const Color(0xFFE8112D));
      case 'live':
        return ('Watch', const Color(0xFFE8112D));
      default:
        return ('Join', const Color(0xFFE8112D));
    }
  }

  Widget _tag(String text, Color bg, {InIconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            InIcon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _titleOnPicture(String title, String? line) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xE6000000)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (line != null && line.isNotEmpty)
              Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFFFFFFFF), fontSize: 11)),
          ]),
        ),
      );

  Widget _watch() {
    final thumb = room['nowPlayingThumbnail'] as String?;
    final playing = room['nowPlayingSongTitle'] as String? ??
        room['nowPlayingTitle'] as String?;
    final dur = asNum(room['duration']);
    final pos = asNum(room['playbackPosition']);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF000000)),
        if (thumb != null && thumb.isNotEmpty)
          AppImage(source: thumb, fit: BoxFit.cover),
        Positioned(
            left: 8,
            top: 8,
            child: _tag('Watch party', const Color(0xFFFFFFFF),
                icon: InIcons.play)),
        Positioned(
            right: 8,
            top: 8,
            child: _tag('${_count(room)}', const Color(0xB3000000),
                icon: InIcons.users)),
        _titleOnPicture(room['title'] as String? ?? 'Watch party',
            playing == null || playing.isEmpty ? null : 'Now: $playing'),
        if (dur > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 2,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (pos / dur).clamp(0, 1).toDouble(),
              child: const ColoredBox(color: Color(0xFFE8112D)),
            ),
          ),
      ]),
    );
  }

  Widget _talk() {
    final speakers =
        _people(room).where((m) => m['onStage'] == true).toList();
    final topic = (room['topic'] as String?)?.trim();
    final speaking = room['speakingName'] as String?;
    final listening = (_count(room) - speakers.length).clamp(0, 99999);
    Widget tile(Map<String, dynamic> m) {
      final first = ((m['name'] as String?) ?? '').split(' ').first;
      final talking =
          speaking != null && first == speaking.split(' ').first;
      final host = m['userId'] == room['hostId'];
      final url = m['avatarUrl'] as String?;
      return Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(16),
              border: talking
                  ? Border.all(color: const Color(0xFFFFFFFF), width: 2.5)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null && url.isNotEmpty
                ? AppImage(source: url, fit: BoxFit.cover)
                : Center(
                    child: Text(first.isEmpty ? '?' : first[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700))),
          ),
        ),
        const SizedBox(height: 4),
        Text('$first${host ? ' ★' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10.5)),
      ]);
    }

    final shown = speakers.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const InIcon(InIcons.mic, size: 12, color: Color(0xFFFFFFFF)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
                topic == null || topic.isEmpty || topic == room['title']
                    ? 'TALK'
                    : 'TALK · ${topic.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _kDim, fontSize: 10.5, letterSpacing: 0.3)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(room['title'] as String? ?? 'Talk',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3)),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                  child: i < shown.length
                      ? tile(shown[i])
                      : const SizedBox.shrink()),
              if (i < 3) const SizedBox(width: 8),
            ],
          ]),
        ],
        const SizedBox(height: 10),
        Text(
            '$listening listening · ${speakers.length} speaker${speakers.length == 1 ? '' : 's'}',
            style: const TextStyle(color: _kDim, fontSize: 11)),
      ]),
    );
  }

  Widget _game() {
    final (bg, fg, icon, label) = _gameLook(room['gameType'] as String?);
    final game = room['game'] as Map?;
    final seats = game?['seats'] as int? ?? 4;
    final status = game?['status'] as String?;
    final players = _playerIds;
    final byId = {for (final m in _people(room)) m['userId']: m};
    final open = (seats - players.length).clamp(0, seats);
    final watching = (_count(room) - players.length).clamp(0, 99999);
    final statusText = status == 'playing'
        ? 'Playing'
        : open > 0
            ? 'Waiting for $open more'
            : 'Ready';
    String seatName(int i) {
      final n = ((byId[players[i]]?['name'] as String?) ?? 'Player')
          .split(' ')
          .first;
      return players[i] == room['hostId'] ? '$n ★' : n;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 84,
        color: bg,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(children: [
                    InIcon(icon, size: 12, color: fg),
                    const SizedBox(width: 4),
                    Text(label.toUpperCase(),
                        style: TextStyle(
                            color: fg, fontSize: 10.5, letterSpacing: 0.3)),
                  ]),
                  Text(room['title'] as String? ?? label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  _tag(statusText, const Color(0x73000000)),
                ]),
          ),
          InIcon(icon, size: 46, color: fg.withValues(alpha: 0.85)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(children: [
          for (var i = 0; i < seats.clamp(1, 4); i++)
            Expanded(
              child: Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: i < players.length
                        ? Border.all(
                            color: _ludoColors[i % _ludoColors.length],
                            width: 3)
                        : Border.all(color: const Color(0xFFFFFFFF)),
                  ),
                  child: i < players.length
                      ? ClipOval(
                          child: _Face(byId[players[i]] ?? const {}, size: 38))
                      : const Center(
                          child: InIcon(InIcons.plus,
                              size: 16, color: Color(0xFFFFFFFF))),
                ),
                const SizedBox(height: 4),
                Text(i < players.length ? seatName(i) : 'Open',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: i < players.length
                            ? Colors.white
                            : const Color(0xFFFFFFFF),
                        fontSize: 10.5)),
              ]),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Text(
            '${players.length} of $seats seats · $watching watching',
            style: const TextStyle(color: _kDim, fontSize: 11)),
      ),
    ]);
  }

  Widget _live() {
    final url = room['hostAvatarUrl'] as String?;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF000000)),
        if (url != null && url.isNotEmpty)
          AppImage(source: url, fit: BoxFit.cover),
        Positioned(
            left: 8,
            top: 8,
            child: Row(children: [
              _tag('LIVE', _kLive, icon: InIcons.live),
              const SizedBox(width: 5),
              _tag(_short(_count(room)), const Color(0x99000000),
                  icon: InIcons.eye),
            ])),
        _titleOnPicture(room['title'] as String? ?? 'Live',
            _liveFor(room).isEmpty ? null : 'Started ${_liveFor(room)} ago'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _type(room);
    final (label, color) = _button();
    final audience = _audience();
    final picture = switch (type) {
      'voice' => _talk(),
      'game' => _game(),
      'live' => _live(),
      _ => _watch(),
    };
    return Semantics(
      button: true,
      label: _semantic(room),
      child: Material(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (header != null) header!,
            picture,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: audience.isEmpty
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                type == 'voice'
                                    ? 'Be the first to listen'
                                    : 'Be the first to watch',
                                style: const TextStyle(
                                    color: _kDim, fontSize: 11.5)),
                          )
                        : ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                  Color(0x00FFFFFF)
                                ],
                                stops: [0, 0.85, 1]).createShader(r),
                            blendMode: BlendMode.dstIn,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: audience.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 5),
                              itemBuilder: (_, i) =>
                                  _Face(audience[i], size: 28),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 18)),
                  onPressed: onTap,
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
