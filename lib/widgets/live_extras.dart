import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/room_models.dart';
import '../core/auth_provider.dart';
import '../screens/live/live_rankings_screen.dart';
import '../screens/party/live_broadcast_controller.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';
import 'avatar.dart';
import 'spinner.dart';

/// Live extras on top of the broadcast: diamonds (gift coins this stream),
/// top fans, the host's fan club, PK battles and the video guest stage.
/// Server side: src/routes/live.js and src/lib/pk.js.
class LiveExtrasController extends ChangeNotifier {
  final String roomId;
  final io.Socket? socket;
  LiveExtrasController({required this.roomId, required this.socket});

  int diamonds = 0;
  List<Map<String, dynamic>> topFans = [];
  Map<String, dynamic> fanClub = const {};
  Map<String, dynamic>? pk;

  /// A PK invite this room received (only the host acts on it).
  Map<String, dynamic>? incomingInvite;

  /// A PK invite this room sent that hasn't been answered yet.
  Map<String, dynamic>? pendingInvite;

  final _handlers = <String, void Function(dynamic)>{};
  Timer? _refresh;
  Timer? _clearResult;
  bool _disposed = false;

  Set<String> get fanIds =>
      ((fanClub['memberIds'] as List?) ?? const []).cast<String>().toSet();
  bool get pkActive => pk?['status'] == 'active';
  bool get pkEnded => pk?['status'] == 'ended';

  /// The other room in a running or just-finished battle.
  String? get opponentRoomId {
    final b = pk;
    if (b == null) return null;
    return b['roomA'] == roomId ? b['roomB'] as String? : b['roomA'] as String?;
  }

  void start() {
    _on('gift:received', (_) => _scheduleLoad());
    _on('live:fanJoined', (_) => _scheduleLoad());
    _on('pk:invite', (d) {
      incomingInvite = _map(d);
      _notify();
    });
    _on('pk:pending', (d) {
      pendingInvite = _map(d);
      _notify();
    });
    _on('pk:start', (d) {
      pk = _map(d);
      incomingInvite = null;
      pendingInvite = null;
      _notify();
    });
    _on('pk:score', (d) {
      pk = _map(d);
      _notify();
    });
    _on('pk:end', (d) {
      pk = _map(d);
      _notify();
      // The result banner stays up for a few seconds, then the stage
      // goes back to the normal single-host view.
      _clearResult?.cancel();
      _clearResult = Timer(const Duration(seconds: 15), () {
        if (pkEnded) {
          pk = null;
          _notify();
        }
      });
    });
    _on('pk:declined', (_) {
      incomingInvite = null;
      pendingInvite = null;
      _notify();
    });
    load();
  }

  Map<String, dynamic>? _map(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : null;

  void _on(String event, void Function(dynamic) handler) {
    _handlers[event] = handler;
    socket?.on(event, handler);
  }

  void _scheduleLoad() {
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 700), load);
  }

  Future<void> load() async {
    try {
      final d =
          await ApiClient.get('/live/$roomId/stats') as Map<String, dynamic>;
      if (_disposed) return;
      diamonds = (d['diamonds'] as num?)?.toInt() ?? 0;
      topFans =
          ((d['topFans'] as List?) ?? const []).cast<Map<String, dynamic>>();
      fanClub = (d['fanClub'] as Map?)?.cast<String, dynamic>() ?? const {};
      final battle = (d['pk'] as Map?)?.cast<String, dynamic>();
      if (battle == null) {
        if (!pkEnded) pk = null;
      } else if (battle['status'] == 'active') {
        pk = battle;
      } else if (battle['status'] == 'pending') {
        if (battle['roomA'] == roomId) {
          pendingInvite = battle;
        } else {
          incomingInvite = battle;
        }
      }
      _notify();
    } catch (_) {
      // Extras are decoration on top of the stream — keep what we had.
    }
  }

  Future<String?> joinFanClub(BuildContext context, String hostId) async {
    try {
      final r = await ApiClient.post('/live/fan-club/$hostId/join',
          body: {'roomId': roomId}) as Map<String, dynamic>;
      fanClub = r;
      _notify();
      if (context.mounted) await context.read<AuthProvider>().refreshUser();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Couldn’t join right now.';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Battle over: back to the normal single-host view now.
  void closeResult() {
    _clearResult?.cancel();
    if (pkEnded) {
      pk = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    _clearResult?.cancel();
    _handlers.forEach((event, handler) => socket?.off(event, handler));
    super.dispose();
  }
}

String compactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).round()}K';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Diamonds collected this stream; tap for top fans and the fan club.
class LiveDiamondsPill extends StatelessWidget {
  final int diamonds;
  final VoidCallback onTap;
  const LiveDiamondsPill(
      {super.key, required this.diamonds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$diamonds diamonds, see top fans',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.black38, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const InIcon(InIcons.diamond,
                size: 14, color: AppColors.diamond, filled: true),
            const SizedBox(width: 5),
            Text(compactCount(diamonds),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const InIcon(InIcons.trophy, size: 13, color: AppColors.gold),
          ]),
        ),
      ),
    );
  }
}

/// One person's video in the live room: my own camera, someone in this
/// room's channel, or (with [channelId]) the other host during a PK.
class LiveUserVideo extends StatelessWidget {
  final LiveBroadcastController live;
  final String userId;
  final bool isMe;
  final String? channelId;
  final String name;
  final String? avatarUrl;
  const LiveUserVideo(
      {super.key,
      required this.live,
      required this.userId,
      required this.isMe,
      required this.name,
      this.avatarUrl,
      this.channelId});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: live,
      builder: (context, _) {
        final engine = live.engine;
        Widget? surface;
        final myUid = liveUidFor(userId);
        final cameraOff = isMe ? !live.cameraOn : live.isCameraOff(myUid);
        final micOff = isMe ? !live.micOn : live.isMicOff(myUid);
        if (engine != null && live.joined && !cameraOff) {
          if (isMe) {
            surface = AgoraVideoView(
                controller: VideoViewController(
                    rtcEngine: engine, canvas: const VideoCanvas(uid: 0)));
          } else if (channelId != null) {
            final uid = live.opponentUid;
            if (uid != null) {
              surface = AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: uid),
                  connection:
                      RtcConnection(channelId: channelId, localUid: live.myUid),
                ),
              );
            }
          } else {
            final uid = liveUidFor(userId);
            if (live.remoteUids.contains(uid)) {
              surface = AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: uid),
                  connection: RtcConnection(channelId: live.roomId),
                ),
              );
            }
          }
        }
        return Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Color(0xFF15121D)),
          surface ??
              Center(
                  child:
                      Avatar(src: avatarUrl, name: name, size: AvatarSize.lg)),
          if (micOff)
            const Positioned(
              left: 5,
              bottom: 5,
              child: InIcon(InIcons.micoff, color: Colors.white, size: 15),
            ),
        ]);
      },
    );
  }
}

/// Multi-guest live: the people the host brought on stage, as small video
/// tiles down the right edge.
class LiveGuestTiles extends StatelessWidget {
  final LiveBroadcastController live;
  final List<RosterEntry> guests;
  final String? myUserId;
  final bool isHost;
  final void Function(String userId) onRemove;
  const LiveGuestTiles(
      {super.key,
      required this.live,
      required this.guests,
      required this.myUserId,
      required this.isHost,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final g in guests)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            container: true,
            label: '${g.name} is on stage',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 118,
                child: Stack(fit: StackFit.expand, children: [
                  LiveUserVideo(
                      live: live,
                      userId: g.userId,
                      isMe: g.userId == myUserId,
                      name: g.name,
                      avatarUrl: g.avatarUrl),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 5,
                    child: Text(g.userId == myUserId ? 'You' : g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(blurRadius: 4)])),
                  ),
                  if (isHost || g.userId == myUserId)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemove(g.userId),
                        child: Semantics(
                          container: true,
                          button: true,
                          label: g.userId == myUserId
                              ? 'Leave the stage'
                              : 'Remove ${g.name} from the stage',
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Center(
                                child: InIcon(InIcons.close,
                                    size: 12, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// PK: both hosts side by side.
class PkSplitView extends StatelessWidget {
  final LiveBroadcastController live;
  final Map<String, dynamic> pk;
  final String roomId;
  final bool isHost;
  const PkSplitView(
      {super.key,
      required this.live,
      required this.pk,
      required this.roomId,
      required this.isHost});

  @override
  Widget build(BuildContext context) {
    final weAreA = pk['roomA'] == roomId;
    final us = ((weAreA ? pk['hostA'] : pk['hostB']) as Map?) ?? const {};
    final them = ((weAreA ? pk['hostB'] : pk['hostA']) as Map?) ?? const {};
    final otherRoom = (weAreA ? pk['roomB'] : pk['roomA']) as String?;
    Widget side(Map host, Widget video) => Expanded(
          child: Stack(fit: StackFit.expand, children: [
            video,
            Positioned(
              left: 8,
              bottom: 6,
              right: 8,
              child: Text(host['name'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 4)])),
            ),
          ]),
        );
    final ours = ((weAreA ? pk['scoreA'] : pk['scoreB']) as num?)?.toInt() ?? 0;
    final theirs =
        ((weAreA ? pk['scoreB'] : pk['scoreA']) as num?)?.toInt() ?? 0;
    final active = pk['status'] == 'active';
    Widget winning(bool left) => Positioned(
          top: 8,
          left: left ? 8 : null,
          right: left ? null : 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: left ? AppColors.pink : AppColors.blue,
                borderRadius: BorderRadius.circular(6)),
            child: const Text('WINNING',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4)),
          ),
        );
    return Stack(children: [
      Row(children: [
        side(
            us,
            LiveUserVideo(
                live: live,
                userId: us['id'] as String? ?? '',
                isMe: isHost,
                name: us['name'] as String? ?? '',
                avatarUrl: us['avatarUrl'] as String?)),
        const SizedBox(width: 2),
        side(
            them,
            LiveUserVideo(
                live: live,
                userId: them['id'] as String? ?? '',
                isMe: false,
                channelId: otherRoom,
                name: them['name'] as String? ?? '',
                avatarUrl: them['avatarUrl'] as String?)),
      ]),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.pink, AppColors.purple]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('VS',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
      ),
      if (active && ours > theirs) winning(true),
      if (active && theirs > ours) winning(false),
      // Hear the other host. Off by default for everyone.
      Positioned(
        right: 8,
        bottom: 26,
        child: AnimatedBuilder(
          animation: live,
          builder: (context, _) => Semantics(
            button: true,
            label: live.hearingOpponent
                ? 'Mute the other host'
                : 'Hear the other host',
            child: GestureDetector(
              onTap: () => live.setHearOpponent(!live.hearingOpponent),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: InIcon(
                    live.hearingOpponent ? InIcons.speaker : InIcons.mute,
                    size: 15,
                    color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Battle score bar: our side pink, theirs blue, the clock in the middle,
/// the x2 finish banner and each side's top three supporters. Once the
/// battle ends it turns into the result card.
class PkBattleBar extends StatefulWidget {
  final Map<String, dynamic> pk;
  final String roomId;
  final bool isHost;
  final VoidCallback? onClose;
  const PkBattleBar(
      {super.key,
      required this.pk,
      required this.roomId,
      this.isHost = false,
      this.onClose});

  @override
  State<PkBattleBar> createState() => _PkBattleBarState();
}

class _PkBattleBarState extends State<PkBattleBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Widget _fans(List fans, bool left) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < fans.length && i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: left ? 6 : 0, left: left ? 0 : 6),
              child: Stack(clipBehavior: Clip.none, children: [
                Avatar(
                    src: (fans[i] as Map)['avatarUrl'] as String?,
                    name: (fans[i] as Map)['name'] as String? ?? '',
                    size: AvatarSize.sm),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Color(0xFF3A2300),
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final pk = widget.pk;
    if (pk['status'] == 'ended') {
      return PkResultCard(
          pk: pk,
          roomId: widget.roomId,
          isHost: widget.isHost,
          onClose: widget.onClose);
    }
    final weAreA = pk['roomA'] == widget.roomId;
    final ours = ((weAreA ? pk['scoreA'] : pk['scoreB']) as num?)?.toInt() ?? 0;
    final theirs =
        ((weAreA ? pk['scoreB'] : pk['scoreA']) as num?)?.toInt() ?? 0;
    final total = ours + theirs;
    final share = total == 0 ? 0.5 : (ours / total).clamp(0.08, 0.92);
    final now = DateTime.now();
    final endsAt = DateTime.tryParse('${pk['endsAt'] ?? ''}')?.toLocal();
    final boostFrom = DateTime.tryParse('${pk['boostFrom'] ?? ''}')?.toLocal();
    final left = endsAt == null || endsAt.isBefore(now)
        ? Duration.zero
        : endsAt.difference(now);
    final boosted = boostFrom != null && !now.isBefore(boostFrom);
    final clock =
        '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    final ourFans = (weAreA ? pk['topA'] : pk['topB']) as List? ?? const [];
    final theirFans = (weAreA ? pk['topB'] : pk['topA']) as List? ?? const [];
    const score = TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800);
    return Semantics(
      label: 'Battle, us $ours, them $theirs, $clock left',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 26,
            child: LayoutBuilder(builder: (context, c) {
              return Stack(children: [
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: c.maxWidth * share,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFFC41E45), AppColors.pink])),
                  ),
                  Expanded(
                    child: Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [AppColors.blue, Color(0xFF2A4FD6)]))),
                  ),
                ]),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      Text(compactCount(ours), style: score),
                      const Spacer(),
                      Text(compactCount(theirs), style: score),
                    ]),
                  ),
                ),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const InIcon(InIcons.hourglass,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(clock, style: score),
                    ]),
                  ),
                ),
              ]);
            }),
          ),
        ),
        if (boosted) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.gold, Color(0xFFFF8A3C)]),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('x2 · Last 30 seconds count double',
                style: TextStyle(
                    color: Color(0xFF3A2300),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800)),
          ),
        ],
        if (ourFans.isNotEmpty || theirFans.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            _fans(ourFans, true),
            const Spacer(),
            _fans(theirFans.reversed.toList(), false),
          ]),
        ],
      ]),
    );
  }
}

/// The battle result: winner, final score, MVP, top supporters, the
/// winner's streak and rank, and a rematch for the hosts.
class PkResultCard extends StatefulWidget {
  final Map<String, dynamic> pk;
  final String roomId;
  final bool isHost;
  final VoidCallback? onClose;
  const PkResultCard(
      {super.key,
      required this.pk,
      required this.roomId,
      this.isHost = false,
      this.onClose});

  @override
  State<PkResultCard> createState() => _PkResultCardState();
}

class _PkResultCardState extends State<PkResultCard> {
  bool _asking = false;

  Future<void> _rematch() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _asking = true);
    try {
      await ApiClient.post('/live/pk/${widget.pk['id']}/rematch');
      messenger.showSnackBar(
          const SnackBar(content: Text('Rematch sent. Waiting for them.')));
      widget.onClose?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.pk;
    final weAreA = pk['roomA'] == widget.roomId;
    final us = (weAreA ? pk['hostA'] : pk['hostB']) as Map? ?? const {};
    final them = (weAreA ? pk['hostB'] : pk['hostA']) as Map? ?? const {};
    final ours = ((weAreA ? pk['scoreA'] : pk['scoreB']) as num?)?.toInt() ?? 0;
    final theirs =
        ((weAreA ? pk['scoreB'] : pk['scoreA']) as num?)?.toInt() ?? 0;
    final winner = pk['winnerRoomId'];
    final weWon = winner == widget.roomId;
    final title = winner == null
        ? 'It’s a draw'
        : '${(weWon ? us : them)['name'] ?? 'They'} wins';
    final mvp = pk['mvp'] as Map?;
    final winnerFans = (winner == null
            ? <dynamic>[]
            : (winner == pk['roomA'] ? pk['topA'] : pk['topB']) as List?) ??
        const [];
    final streak = (pk['winnerStreak'] as num?)?.toInt() ?? 0;
    final rank = (pk['winnerDailyRank'] as num?)?.toInt();
    Widget total(int n, String? name, Color color) => Column(children: [
          Text(compactCount(n),
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ]);
    return Semantics(
      label: '$title, $ours to $theirs',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const SizedBox(width: 30),
            const Spacer(),
            const InIcon(InIcons.trophy, size: 26, color: AppColors.gold),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                onTap: widget.onClose,
                child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                        child: InIcon(InIcons.close,
                            size: 16, color: AppColors.textDim))),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: total(ours, us['name'] as String?, AppColors.pink)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(':',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 20)),
            ),
            Flexible(
                child: total(theirs, them['name'] as String?, AppColors.blue)),
          ]),
          if (mvp != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Avatar(
                    src: mvp['avatarUrl'] as String?,
                    name: mvp['name'] as String? ?? '',
                    size: AvatarSize.md),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MVP',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                  Text(mvp['name'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${compactCount(((mvp['points'] as num?) ?? 0).toInt())} points',
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 11)),
                ]),
              ]),
            ),
          ],
          if (winnerFans.length > 1) ...[
            const SizedBox(height: 12),
            const Text('TOP SUPPORTERS',
                style: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final f in winnerFans.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Column(children: [
                    Avatar(
                        src: (f as Map)['avatarUrl'] as String?,
                        name: f['name'] as String? ?? '',
                        size: AvatarSize.sm),
                    const SizedBox(height: 3),
                    Text(f['name'] as String? ?? '',
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 11)),
                    Text(compactCount(((f['points'] as num?) ?? 0).toInt()),
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ],
          if (winner != null && (streak > 1 || rank != null)) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const InIcon(InIcons.flame, size: 14, color: AppColors.gold),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                    [
                      if (streak > 1) '$streak wins in a row',
                      if (rank != null) 'Daily rank #$rank',
                    ].join(' · '),
                    style: const TextStyle(
                        color: AppColors.inkMuted, fontSize: 11.5)),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            if (widget.isHost) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _asking ? null : _rematch,
                  icon: const InIcon(InIcons.repeat,
                      size: 16, color: Colors.white),
                  label: const Text('Rematch'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LiveRankingsScreen())),
                icon: const InIcon(InIcons.trophy, size: 16),
                label: const Text('Rankings'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

Widget _sheetFrame(BuildContext context, List<Widget> children,
    {bool scroll = false}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999))),
      ),
      const SizedBox(height: 14),
      ...children,
    ],
  );
  return Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.fromLTRB(
        18, 10, 18, 16 + MediaQuery.of(context).padding.bottom),
    child: scroll ? SingleChildScrollView(child: column) : column,
  );
}

/// Top fans of this stream plus the host's fan club.
Future<void> showLiveFansSheet(
  BuildContext context, {
  required LiveExtrasController extras,
  required String hostId,
  required String hostName,
  required bool isHost,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AnimatedBuilder(
      animation: extras,
      builder: (context, _) {
        final club = extras.fanClub;
        final joined = club['joined'] == true;
        final cost = (club['cost'] as num?)?.toInt() ?? 50;
        final days = (club['days'] as num?)?.toInt() ?? 30;
        final members = (club['memberCount'] as num?)?.toInt() ?? 0;
        final until = DateTime.tryParse('${club['expiresAt'] ?? ''}');
        return ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: _sheetFrame(
              context,
              [
                Row(children: [
                  const InIcon(InIcons.diamond,
                      size: 20, color: AppColors.diamond, filled: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${compactCount(extras.diamonds)} diamonds this live',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const LiveRankingsScreen()));
                    },
                    child: const Text('Rankings'),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3A1430), Color(0xFF22143C)]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const InIcon(InIcons.heart,
                              size: 26, color: AppColors.pink, filled: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      isHost
                                          ? 'Your fan club'
                                          : '$hostName’s fan club',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                      joined && until != null
                                          ? 'You’re a member until ${until.day}/${until.month}'
                                          : '$members ${members == 1 ? 'member' : 'members'} · heart badge in chat',
                                      style: const TextStyle(
                                          color: AppColors.textDim,
                                          fontSize: 12.5)),
                                ]),
                          ),
                        ]),
                        if (!isHost) ...[
                          const SizedBox(height: 12),
                          _JoinClubButton(
                            label: joined
                                ? 'Extend · $cost coins'
                                : 'Join · $cost coins',
                            onJoin: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (d) => AlertDialog(
                                  title: Text(joined
                                      ? 'Extend membership'
                                      : 'Join the fan club'),
                                  content: Text(
                                      '$cost coins for $days days. The coins go to $hostName.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        child: Text('Pay $cost coins')),
                                  ],
                                ),
                              );
                              if (ok != true || !context.mounted) return;
                              final err =
                                  await extras.joinFanClub(context, hostId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          err ?? 'Welcome to the fan club!')));
                            },
                          ),
                        ],
                      ]),
                ),
                const SizedBox(height: 16),
                Text('Top fans',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _FansTabs(extras: extras, hostId: hostId),
              ],
              scroll: true),
        );
      },
    ),
  );
}

/// This live / Daily / Weekly / Fan club — this live comes from the
/// controller; the rest from GET /live/fans/:hostId.
class _FansTabs extends StatefulWidget {
  final LiveExtrasController extras;
  final String hostId;
  const _FansTabs({required this.extras, required this.hostId});

  @override
  State<_FansTabs> createState() => _FansTabsState();
}

class _FansTabsState extends State<_FansTabs> {
  String _tab = 'live';
  final Map<String, List<Map<String, dynamic>>> _lists = {};

  static const _tabs = [
    ('live', 'This live'),
    ('day', 'Daily'),
    ('week', 'Weekly'),
    ('club', 'Fan club'),
  ];

  Future<void> _pick(String t) async {
    setState(() => _tab = t);
    if (t == 'live' || _lists.containsKey(t)) return;
    try {
      final d = await ApiClient.get('/live/fans/${widget.hostId}?period=$t');
      if (!mounted) return;
      setState(() => _lists[t] =
          (d as List).cast<Map>().map(Map<String, dynamic>.from).toList());
    } catch (_) {
      if (mounted) setState(() => _lists[t] = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == 'live'
        ? widget.extras.topFans.cast<Map<String, dynamic>>()
        : _lists[_tab];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (id, label) in _tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _tab == id,
                showCheckmark: false,
                onSelected: (_) => _pick(id),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      if (list == null)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: Spinner(size: 20)))
      else if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
              _tab == 'club'
                  ? 'No fan club members yet.'
                  : 'No gifts yet — the first one tops the list.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textFaint)),
        )
      else
        for (final (i, f) in list.indexed)
          LiveRankRow(
            rank: i + 1,
            name: f['name'] as String? ?? '',
            avatarUrl: f['avatarUrl'] as String?,
            isFan: _tab == 'club' || widget.extras.fanIds.contains(f['id']),
            level: (f['level'] as num?)?.toInt(),
            value: (f['coins'] as num?)?.toInt() ?? 0,
            icon: _tab == 'club' ? InIcons.heart : InIcons.gift,
            iconColor: _tab == 'club' ? AppColors.pink : AppColors.gold,
          ),
    ]);
  }
}

class _JoinClubButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onJoin;
  const _JoinClubButton({required this.label, required this.onJoin});

  @override
  State<_JoinClubButton> createState() => _JoinClubButtonState();
}

class _JoinClubButtonState extends State<_JoinClubButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              await widget.onJoin();
              if (mounted) setState(() => _busy = false);
            },
      style: FilledButton.styleFrom(
          backgroundColor: AppColors.pink,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14)),
      child: _busy ? const Spinner(size: 16) : Text(widget.label),
    );
  }
}

/// A ranked person: position, avatar, name and a score. Shared with the
/// rankings screen so both lists look the same.
class LiveRankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String? avatarUrl;
  final bool isFan;
  final int value;
  final InIconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  const LiveRankRow(
      {super.key,
      required this.rank,
      required this.name,
      this.avatarUrl,
      this.isFan = false,
      required this.value,
      required this.icon,
      required this.iconColor,
      this.onTap,
      this.trailing,
      this.level});

  /// Shown as "Lv 12" next to the name when known.
  final int? level;

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? AppColors.gold
        : rank == 2
            ? const Color(0xFFC9CCD6)
            : rank == 3
                ? const Color(0xFFD08A4E)
                : AppColors.textFaint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: medal, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(width: 8),
          Avatar(src: avatarUrl, name: name, size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (isFan) ...[
                const SizedBox(width: 4),
                const InIcon(InIcons.heart,
                    size: 12, color: AppColors.pink, filled: true),
              ],
              if (level != null && level! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2B1640),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Lv $level',
                      style: const TextStyle(
                          color: AppColors.lilac,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          InIcon(icon, size: 14, color: iconColor, filled: true),
          const SizedBox(width: 4),
          Text(compactCount(value),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

/// Host: pick another live to challenge to a PK.
Future<void> showPkInviteSheet(BuildContext context,
    {required LiveExtrasController extras}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PkInviteSheet(extras: extras),
  );
}

class _PkInviteSheet extends StatefulWidget {
  final LiveExtrasController extras;
  const _PkInviteSheet({required this.extras});

  @override
  State<_PkInviteSheet> createState() => _PkInviteSheetState();
}

class _PkInviteSheetState extends State<_PkInviteSheet> {
  List<Map<String, dynamic>>? _rooms;
  String? _error;
  String? _sending;
  int _minutes = 5;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    widget.extras.addListener(_closeWhenStarted);
    _load();
  }

  @override
  void dispose() {
    widget.extras.removeListener(_closeWhenStarted);
    if (_searching) {
      ApiClient.delete('/live/${widget.extras.roomId}/pk/random')
          .catchError((_) => null);
    }
    super.dispose();
  }

  // A random match starts for both hosts at once, through the socket.
  void _closeWhenStarted() {
    if (widget.extras.pkActive && mounted) {
      _searching = false;
      Navigator.of(context).pop();
    }
  }

  Future<void> _load() async {
    try {
      final d =
          await ApiClient.get('/live/${widget.extras.roomId}/pk/candidates')
              as List;
      if (mounted) setState(() => _rooms = d.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load lives right now.');
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _random() async {
    if (_searching) {
      setState(() => _searching = false);
      await ApiClient.delete('/live/${widget.extras.roomId}/pk/random')
          .catchError((_) => null);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await ApiClient.post(
          '/live/${widget.extras.roomId}/pk/random',
          body: {'minutes': _minutes}) as Map<String, dynamic>;
      if (res['battle'] != null) {
        widget.extras.load();
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // Waiting: give up after a minute, the same as the server.
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _searching) {
          setState(() => _searching = false);
          _snack('Nobody free right now. Try again in a bit.');
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _searching = false);
      _snack(e.message);
    } catch (_) {
      if (mounted) setState(() => _searching = false);
      _snack('Couldn’t look for a match.');
    }
  }

  Future<void> _invite(Map<String, dynamic> r) async {
    setState(() => _sending = r['roomId'] as String?);
    try {
      final view = await ApiClient.post(
              '/live/${widget.extras.roomId}/pk/invite',
              body: {'targetRoomId': r['roomId'], 'minutes': _minutes})
          as Map<String, dynamic>;
      widget.extras.pendingInvite = view;
      widget.extras.load();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Couldn’t send the invite.');
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  Widget _randomCard() => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _random,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [
                AppColors.pink.withValues(alpha: 0.25),
                AppColors.blue.withValues(alpha: 0.25),
              ]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                        colors: [AppColors.pink, AppColors.blue])),
                alignment: Alignment.center,
                child: _searching
                    ? const Spinner(size: 20)
                    : const InIcon(InIcons.shuffle,
                        size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_searching ? 'Finding a match…' : 'Random match',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                          _searching
                              ? 'Tap to stop looking'
                              : 'Battle a live host near your level',
                          style: const TextStyle(
                              color: AppColors.inkMuted, fontSize: 11.5)),
                    ]),
              ),
              if (!_searching)
                const InIcon(InIcons.right,
                    size: 18, color: AppColors.textFaint),
            ]),
          ),
        ),
      );

  Widget _length() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          for (final m in const [3, 5, 10])
            Expanded(
              child: GestureDetector(
                onTap: _searching ? null : () => setState(() => _minutes = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: m == _minutes
                          ? AppColors.surface3
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Text('$m min',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: m == _minutes
                              ? AppColors.text
                              : AppColors.textDim)),
                ),
              ),
            ),
        ]),
      );

  static const _label = TextStyle(
      color: AppColors.textFaint,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6);

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: _sheetFrame(context, scroll: true, [
        Row(children: [
          const InIcon(InIcons.swords, size: 22, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Battle',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Gifts in the battle count as points. Highest score wins.',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 14),
        _randomCard(),
        const SizedBox(height: 16),
        const Text('LENGTH', style: _label),
        const SizedBox(height: 8),
        _length(),
        const SizedBox(height: 16),
        const Text('INVITE A HOST', style: _label),
        const SizedBox(height: 4),
        if (_error != null || rooms == null || rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: rooms == null && _error == null
                ? const Center(child: Spinner(size: 24))
                : Text(_error ?? 'No one else is live right now.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textFaint)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rooms.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final r = rooms[i];
              final host = (r['host'] as Map?) ?? const {};
              final busy = r['inBattle'] == true;
              final level = (host['level'] as num?)?.toInt() ?? 1;
              final watching = (r['watching'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Avatar(
                      src: host['avatarUrl'] as String?,
                      name: host['name'] as String? ?? '',
                      size: AvatarSize.md,
                      ring: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(host['name'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Lv $level · ${compactCount(watching)} watching',
                              style: const TextStyle(
                                  color: AppColors.textDim, fontSize: 12)),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  if (busy)
                    const Text('In a battle',
                        style:
                            TextStyle(color: AppColors.textFaint, fontSize: 12))
                  else
                    FilledButton(
                      onPressed: _sending != null || _searching
                          ? null
                          : () => _invite(r),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.pink,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 16)),
                      child: _sending == r['roomId']
                          ? const Spinner(size: 16)
                          : const Text('Invite'),
                    ),
                ]),
              );
            },
          ),
      ]),
    );
  }
}

/// Host: answer a PK challenge from another live.
Future<void> showIncomingPkDialog(BuildContext context,
    {required Map<String, dynamic> invite,
    required LiveExtrasController extras}) {
  final from = (invite['hostA'] as Map?) ?? const {};
  final id = invite['id'] as String?;
  Future<void> answer(BuildContext d, bool accept) async {
    Navigator.of(d).pop();
    try {
      await ApiClient.post('/live/pk/$id/${accept ? 'accept' : 'decline'}');
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
    extras.incomingInvite = null;
    extras.load();
  }

  return showDialog(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Battle invite'),
      content: Row(children: [
        Avatar(
            src: from['avatarUrl'] as String?,
            name: from['name'] as String? ?? '',
            size: AvatarSize.md),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              '${from['name'] ?? 'Someone'} wants a ${invite['minutes'] ?? 5}-minute battle with you.'),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => answer(d, false), child: const Text('Not now')),
        FilledButton(
            onPressed: () => answer(d, true), child: const Text('Accept')),
      ],
    ),
  );
}
