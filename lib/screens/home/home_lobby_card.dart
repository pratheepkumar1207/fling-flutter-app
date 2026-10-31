import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_tick.dart';
import '../messages/message_thread_screen.dart';
import '../party/room_person_sheets.dart';

const _cardColor = Color(0xFF17141F);
const _voiceColor = Color(0xFF1A2740);
const _hostGold = Color(0xFFE6B94A);
const _coHostPurple = Color(0xFFC4A8FF);
const _progress = Color(0xFFC4A8FF);

/// Each game's name, icon and colour, on its card and around its room.
({String name, InIconData icon, Color color}) gameLook(String? type) =>
    switch (type) {
      'chess' => (name: 'Chess', icon: InIcons.game, color: Color(0xFF172C27)),
      'tictactoe' => (
          name: 'Tic Tac Toe',
          icon: InIcons.game,
          color: Color(0xFF221C38)
        ),
      'ludo' => (name: 'Ludo', icon: InIcons.game, color: Color(0xFF33261A)),
      'uno' => (name: 'UNO', icon: InIcons.game, color: Color(0xFF351C1C)),
      'truth_or_dare' => (
          name: 'Truth or Dare',
          icon: InIcons.game,
          color: Color(0xFF27143A)
        ),
      'would_you_rather' => (
          name: 'Would You Rather',
          icon: InIcons.game,
          color: Color(0xFF10283A)
        ),
      _ => (name: 'Game', icon: InIcons.game, color: Color(0xFF221C38)),
    };

String _clock(num seconds) {
  final s = seconds.round();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// One Home lobby: tap to join, press and hold (or tap the count) for
/// everyone inside, drag the row of people sideways, tap a face for them.
class HomeLobbyCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const HomeLobbyCard({super.key, required this.room, required this.onTap});

  String get _type => room['roomType'] as String? ?? 'watch';
  int get _count => asNum(room['memberCount']).toInt();
  bool get _boosted => room['isBoosted'] == true;
  bool get _playing => room['isPlaying'] == true;
  bool get _song => room['nowPlayingMediaMode'] == 'audio';

  List<Map<String, dynamic>> get _people =>
      ((room['members'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  void _showPeople(BuildContext context) =>
      showRoomPeoplePopup(context, room: room, line: _countLine());

  String _countLine() {
    final game = room['game'] as Map?;
    switch (_type) {
      case 'voice':
        final onMic = _people.where((m) => m['onStage'] == true).length;
        return '$onMic on mic · ${_count - onMic} listening';
      case 'game':
        final playing = ((game?['playerIds'] as List?) ?? const []).length;
        final seats = game?['seats'] as int?;
        final watching = (_count - playing).clamp(0, _count);
        return [
          seats != null && playing < seats
              ? '$playing of $seats playing'
              : '$playing playing',
          if (watching > 0) '$watching watching',
        ].join(' · ');
      case 'live':
        return '$_count watching';
      default:
        return '$_count ${_song ? 'listening' : 'watching'}';
    }
  }

  String _gameTitle() {
    final game = room['game'] as Map?;
    final turn = game?['turn'];
    final who = _people
        .where((m) => m['userId'] == turn)
        .map((m) => (m['name'] as String? ?? '').split(' ').first)
        .firstOrNull;
    if (who != null && who.isNotEmpty) {
      return room['gameType'] == 'truth_or_dare'
          ? '$who is up'
          : '$who\'s turn';
    }
    if (game?['status'] == 'waiting') return 'Waiting for players';
    return 'In play';
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_type) {
      'voice' => _voice(context),
      'game' => _game(context),
      'live' => _live(context),
      _ => _watch(context),
    };
    return Semantics(
      button: true,
      label: '${room['title'] ?? 'Room'}, ${_countLine()}',
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showPeople(context),
          child: body,
        ),
      ),
    );
  }

  Widget _tags(List<Widget> tags) => Wrap(spacing: 6, runSpacing: 6, children: [
        if (_boosted)
          const _Pill('Boosted',
              icon: InIcons.bolt,
              color: _hostGold,
              textColor: Color(0xFF2E2100)),
        ...tags,
      ]);

  Widget _countButton(BuildContext context) => InkWell(
        onTap: () => _showPeople(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 30),
          child: Row(children: [
            Flexible(
              child: Text(_countLine(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFFC9C4D6), fontSize: 13)),
            ),
            const InIcon(InIcons.right, size: 14, color: Color(0xFFC9C4D6)),
          ]),
        ),
      );

  Widget _watch(BuildContext context) {
    final thumb = room['nowPlayingThumbnail'] as String?;
    final roomName = room['title'] as String? ?? 'Room';
    final title = room['nowPlayingTitle'] as String? ?? roomName;
    final netflix = room['nowPlayingSource'] == 'netflix';
    final hasItem = room['nowPlayingTitle'] != null &&
        (thumb != null || room['playbackPosition'] != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 128,
        child: Stack(fit: StackFit.expand, children: [
          if (_song)
            ColoredBox(
              color: const Color(0xFF211A38),
              child: Center(
                  child: _SpinningCd(
                      thumbnail: thumb, size: 88, spinning: _playing)),
            )
          else if (thumb != null && thumb.isNotEmpty)
            AppImage(source: thumb, fit: BoxFit.cover)
          else
            const ColoredBox(color: Color(0xFF2A1F4D)),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _tags([
              if (hasItem)
                _Pill(_playing ? 'Playing' : 'Paused',
                    icon: _playing ? InIcons.play : InIcons.pause),
            ]),
          ),
          if (room['playbackPosition'] != null)
            Positioned.fill(
              child: _LiveProgress(
                position: asNum(room['playbackPosition']).toDouble(),
                duration: netflix || room['duration'] == null
                    ? null
                    : asNum(room['duration']).toDouble(),
                playing: _playing,
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (title != roomName)
            Text(roomName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFC9C4D6), fontSize: 13)),
          if (netflix)
            const Text('Plays in the Netflix app',
                style: TextStyle(color: Color(0xFFC9C4D6), fontSize: 12)),
          _countButton(context),
        ]),
      ),
      _PeopleRow(
        people: _people,
        audienceLabel: _song ? 'Listening' : 'Watching',
      ),
    ]);
  }

  Widget _voice(BuildContext context) {
    final song = room['nowPlayingSongTitle'] != null;
    final talking = (room['speakingName'] as String?)?.split(' ').first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ColoredBox(
        color: _voiceColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _tags([
              _Pill(talking != null ? '$talking is talking' : 'Live',
                  icon: InIcons.mic),
              if (room['communityName'] != null)
                _Pill(room['communityName'] as String, icon: InIcons.users),
            ]),
            const SizedBox(height: 8),
            Text(
                room['topic'] as String? ??
                    room['title'] as String? ??
                    'Voice room',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            _countButton(context),
            if (song) _songLine(),
          ]),
        ),
      ),
      _PeopleRow(
        people: _people,
        audienceLabel: 'Listening',
        talkingName: room['speakingName'] as String?,
      ),
    ]);
  }

  Widget _songLine() {
    final thumb = room['nowPlayingThumbnail'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        _SpinningCd(thumbnail: thumb, size: 30, spinning: _playing),
        const SizedBox(width: 8),
        Expanded(
          child: Text(room['nowPlayingSongTitle'] as String? ?? 'Song playing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
        if (room['playbackPosition'] != null)
          _LiveClock(
            position: asNum(room['playbackPosition']).toDouble(),
            duration: room['duration'] == null
                ? null
                : asNum(room['duration']).toDouble(),
            playing: _playing,
          ),
      ]),
    );
  }

  Widget _game(BuildContext context) {
    final type = room['gameType'] as String?;
    final look = gameLook(type);
    final game = room['game'] as Map?;
    final seats = game?['seats'] as int?;
    final playing = ((game?['playerIds'] as List?) ?? const []).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ColoredBox(
        color: look.color,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _tags([_Pill(look.name, icon: look.icon)]),
            const SizedBox(height: 8),
            Text(_gameTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            _countButton(context),
          ]),
        ),
      ),
      _PeopleRow(
        people: _people,
        audienceLabel: 'Watching',
        turnId: game?['turn'] as String?,
        versusAfter: gameVersusSplit(type, playing),
        openSeats: seats == null ? 0 : (seats - playing).clamp(0, seats),
      ),
    ]);
  }

  Widget _live(BuildContext context) {
    final thumb = room['nowPlayingThumbnail'] as String?;
    final host = room['hostName'] as String? ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 128,
        child: Stack(fit: StackFit.expand, children: [
          if (thumb != null && thumb.isNotEmpty)
            AppImage(source: thumb, fit: BoxFit.cover)
          else
            const ColoredBox(color: Color(0xFF4A2036)),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _tags([
              _Pill(
                  room['inPk'] == true
                      ? (room['pkOpponentHost'] != null
                          ? 'PK battle · vs ${room['pkOpponentHost']}'
                          : 'PK battle')
                      : 'Live',
                  icon: room['inPk'] == true ? InIcons.bolt : InIcons.live,
                  color: const Color(0xFFD8344A)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Avatar(
              src: room['hostAvatarUrl'] as String?,
              name: host,
              size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${host.split(' ').first} is live',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              _countButton(context),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// Where the VS badge goes among a game's players: after the first half,
/// after the one who's up in Truth or Dare, nowhere for group votes.
int? gameVersusSplit(String? type, int players) {
  if (players < 2 || type == 'would_you_rather') return null;
  if (type == 'truth_or_dare') return 1;
  return (players + 1) ~/ 2;
}

class _Pill extends StatelessWidget {
  final String text;
  final InIconData? icon;
  final Color color;
  final Color textColor;
  const _Pill(this.text,
      {this.icon,
      this.color = const Color(0xFF0B0912),
      this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(13)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            InIcon(icon!, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 12)),
          ),
        ]),
      );
}

/// Counts the time forward between Home refreshes.
mixin _Ticking<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  bool get ticking;
  late DateTime _from = DateTime.now();

  double elapsedFrom(double position) => ticking
      ? position + DateTime.now().difference(_from).inSeconds
      : position;

  void restart() {
    _from = DateTime.now();
    _timer?.cancel();
    _timer = !ticking
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _LiveClock extends StatefulWidget {
  final double position;
  final double? duration;
  final bool playing;
  const _LiveClock(
      {required this.position, this.duration, required this.playing});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> with _Ticking {
  @override
  bool get ticking => widget.playing;

  @override
  void initState() {
    super.initState();
    restart();
  }

  @override
  void didUpdateWidget(_LiveClock old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position || old.playing != widget.playing) {
      restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.duration;
    var now = elapsedFrom(widget.position);
    if (d != null && now > d) now = d;
    return Text('${_clock(now)}${d != null ? ' / ${_clock(d)}' : ''}',
        style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()]));
  }
}

class _LiveProgress extends StatefulWidget {
  final double position;
  final double? duration;
  final bool playing;
  const _LiveProgress(
      {required this.position, this.duration, required this.playing});

  @override
  State<_LiveProgress> createState() => _LiveProgressState();
}

class _LiveProgressState extends State<_LiveProgress> with _Ticking {
  @override
  bool get ticking => widget.playing;

  @override
  void initState() {
    super.initState();
    restart();
  }

  @override
  void didUpdateWidget(_LiveProgress old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position || old.playing != widget.playing) {
      restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.duration;
    var now = elapsedFrom(widget.position);
    if (d != null && now > d) now = d;
    return Stack(children: [
      Positioned(
        right: 10,
        bottom: 11,
        child: _Pill('${_clock(now)}${d != null ? ' / ${_clock(d)}' : ''}'),
      ),
      if (d != null && d > 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LinearProgressIndicator(
            value: (now / d).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(_progress),
          ),
        ),
    ]);
  }
}

class _SpinningCd extends StatefulWidget {
  final String? thumbnail;
  final double size;
  final bool spinning;
  const _SpinningCd(
      {this.thumbnail, required this.size, required this.spinning});

  @override
  State<_SpinningCd> createState() => _SpinningCdState();
}

class _SpinningCdState extends State<_SpinningCd>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_SpinningCd old) {
    super.didUpdateWidget(old);
    _sync();
  }

  // Only moves while it's on screen, and not with reduced motion on.
  void _sync() {
    final move = widget.spinning &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (move && !_c.isAnimating) _c.repeat();
    if (!move && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final thumb = widget.thumbnail;
    return RotationTransition(
      turns: _c,
      child: Container(
        width: s,
        height: s,
        padding: const EdgeInsets.all(2),
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: _progress),
        child: ClipOval(
          child: Stack(fit: StackFit.expand, children: [
            if (thumb != null && thumb.isNotEmpty)
              AppImage(source: thumb, fit: BoxFit.cover)
            else
              const ColoredBox(color: Color(0xFF6D3FD0)),
            Center(
              child: Container(
                width: s * 0.24,
                height: s * 0.24,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.bg),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One sideways row: those performing, then a divider, then everyone else.
class _PeopleRow extends StatelessWidget {
  final List<Map<String, dynamic>> people;
  final String audienceLabel;
  final String? turnId;
  final String? talkingName;
  final int? versusAfter;
  final int openSeats;

  const _PeopleRow({
    required this.people,
    required this.audienceLabel,
    this.turnId,
    this.talkingName,
    this.versusAfter,
    this.openSeats = 0,
  });

  @override
  Widget build(BuildContext context) {
    final stage = people.where((m) => m['onStage'] == true).toList();
    final audience = people.where((m) => m['onStage'] != true).toList();
    final items = <Widget>[
      for (var i = 0; i < stage.length; i++) ...[
        if (versusAfter == i) const _VsBadge(),
        _Face(stage[i], ring: _ring(stage[i])),
      ],
      for (var i = 0; i < openSeats; i++) const _OpenSeat(),
      if (audience.isNotEmpty && (stage.isNotEmpty || openSeats > 0))
        _Divider(audienceLabel),
      for (final m in audience) _Face(m, ring: _ring(m)),
    ];
    return SizedBox(
      height: 84 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.25),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        children: items,
      ),
    );
  }

  Color? _ring(Map<String, dynamic> m) {
    if (turnId != null && m['userId'] == turnId) return AppColors.success;
    if (talkingName != null && m['name'] == talkingName) {
      return AppColors.success;
    }
    return switch (m['role']) {
      'host' => _hostGold,
      'cohost' => _coHostPurple,
      _ => null,
    };
  }
}

class _Face extends StatelessWidget {
  final Map<String, dynamic> member;
  final Color? ring;
  const _Face(this.member, {this.ring});

  void _open(BuildContext context) {
    final id = member['userId'] as String?;
    if (id == null) return;
    final name = member['name'] as String? ?? 'Someone';
    final avatar = member['avatarUrl'] as String?;
    showRoomPersonCard(
      context,
      person: RosterEntry(
          userId: id,
          name: name,
          username: member['username'] as String?,
          avatarUrl: avatar),
      isMe: false,
      status: '',
      onMessage: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              MessageThreadScreen(userId: id, name: name, avatarUrl: avatar))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (member['name'] as String? ?? '').split(' ').first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: SizedBox(
        width: 58,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: ring == null ? null : Border.all(color: ring!, width: 2),
            ),
            child: FittedBox(
              child: Avatar(
                  src: member['avatarUrl'] as String?,
                  name: member['name'] as String?,
                  size: AvatarSize.md),
            ),
          ),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

class _OpenSeat extends StatelessWidget {
  const _OpenSeat();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 58,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5)),
            alignment: Alignment.center,
            child: const InIcon(InIcons.plus, size: 16, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Text('Open',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      );
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F2FB),
                borderRadius: BorderRadius.circular(12)),
            child: const Text('VS',
                style: TextStyle(
                    color: Color(0xFF17141F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(children: [
          Container(width: 1, color: Colors.white24),
          const SizedBox(width: 4),
          RotatedBox(
            quarterTurns: 3,
            child: Text(label,
                maxLines: 1,
                style: const TextStyle(fontSize: 11, color: Color(0xFFC9C4D6))),
          ),
        ]),
      );
}

/// Press and hold: everyone inside, in order, without joining.
Future<void> showRoomPeoplePopup(BuildContext context,
    {required Map<String, dynamic> room, required String line}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1D1A29),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: _PeopleList(room: room, line: line),
    ),
  );
}

class _PeopleList extends StatefulWidget {
  final Map<String, dynamic> room;
  final String line;
  const _PeopleList({required this.room, required this.line});

  @override
  State<_PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends State<_PeopleList> {
  late List<Map<String, dynamic>> _people =
      ((widget.room['members'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/rooms/${widget.room['id']}/people');
      if (!mounted || data is! List) return;
      setState(() => _people = data
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList());
    } catch (_) {
      // The card's first 30 people still show.
    }
  }

  String _role(Map<String, dynamic> m, bool game) {
    if (m['role'] == 'host') return 'Host';
    if (m['role'] == 'cohost') return 'Co-host';
    if (game && m['onStage'] == true) return 'Playing';
    if (m['onMic'] == true) return 'On mic';
    if (m['isFriend'] == true) return 'Friend';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final game = room['roomType'] == 'game';
    final title = room['roomType'] == 'watch'
        ? room['nowPlayingTitle'] as String? ?? room['title'] as String?
        : room['topic'] as String? ?? room['title'] as String?;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 6),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (room['isBoosted'] == true)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: _Pill('Boosted',
                            icon: InIcons.bolt,
                            color: _hostGold,
                            textColor: Color(0xFF2E2100)),
                      ),
                    Text(title ?? 'Room',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(widget.line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFC9C4D6), fontSize: 13)),
                  ]),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const InIcon(InIcons.close, color: Color(0xFFC9C4D6)),
            ),
          ]),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            itemCount: _people.length,
            itemBuilder: (_, i) {
              final m = _people[i];
              final role = _role(m, game);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Avatar(
                      src: m['avatarUrl'] as String?,
                      name: m['name'] as String?,
                      size: AvatarSize.sm),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(m['name'] as String? ?? 'Someone',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (m['isVerified'] == true) const VerifiedTick(),
                  if (role.isNotEmpty)
                    Text(role,
                        style: TextStyle(
                            fontSize: 12,
                            color: role == 'Host'
                                ? _hostGold
                                : role == 'Co-host'
                                    ? _coHostPurple
                                    : const Color(0xFFC9C4D6))),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
