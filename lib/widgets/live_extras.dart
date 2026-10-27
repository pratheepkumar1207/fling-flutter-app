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
      _clearResult = Timer(const Duration(seconds: 8), () {
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
        if (engine != null && live.joined) {
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
    ]);
  }
}

/// PK score bar with the countdown — or the result once it ends.
class PkBattleBar extends StatefulWidget {
  final Map<String, dynamic> pk;
  final String roomId;
  const PkBattleBar({super.key, required this.pk, required this.roomId});

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

  @override
  Widget build(BuildContext context) {
    final pk = widget.pk;
    final weAreA = pk['roomA'] == widget.roomId;
    final ours = ((weAreA ? pk['scoreA'] : pk['scoreB']) as num?)?.toInt() ?? 0;
    final theirs =
        ((weAreA ? pk['scoreB'] : pk['scoreA']) as num?)?.toInt() ?? 0;
    final total = ours + theirs;
    final share = total == 0 ? 0.5 : (ours / total).clamp(0.08, 0.92);
    final ended = pk['status'] == 'ended';
    final endsAt = DateTime.tryParse('${pk['endsAt'] ?? ''}');
    final left = endsAt == null
        ? Duration.zero
        : endsAt.difference(DateTime.now()).isNegative
            ? Duration.zero
            : endsAt.difference(DateTime.now());
    final clock =
        '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    String status;
    if (!ended) {
      status = 'PK · $clock';
    } else if (pk['winnerRoomId'] == null) {
      status = 'It’s a draw';
    } else {
      status = pk['winnerRoomId'] == widget.roomId ? 'We won!' : 'They won';
    }
    return Semantics(
      label: 'PK battle, us $ours, them $theirs, $status',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 22,
            child: LayoutBuilder(builder: (context, c) {
              return Stack(children: [
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: c.maxWidth * share,
                    color: AppColors.pink,
                  ),
                  const Expanded(child: ColoredBox(color: AppColors.blue)),
                ]),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      Text(compactCount(ours),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text(compactCount(theirs),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            InIcon(ended ? InIcons.crown : InIcons.swords,
                size: 14,
                color: ended ? AppColors.gold : Colors.white,
                filled: ended),
            const SizedBox(width: 6),
            Text(status,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
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
                if (extras.topFans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('No gifts yet — the first one tops the list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textFaint)),
                  )
                else
                  for (final (i, f) in extras.topFans.indexed)
                    LiveRankRow(
                      rank: i + 1,
                      name: f['name'] as String? ?? '',
                      avatarUrl: f['avatarUrl'] as String?,
                      isFan: extras.fanIds.contains(f['id']),
                      value: (f['coins'] as num?)?.toInt() ?? 0,
                      icon: InIcons.gift,
                      iconColor: AppColors.gold,
                    ),
              ],
              scroll: true),
        );
      },
    ),
  );
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
      this.trailing});

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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _invite(Map<String, dynamic> r) async {
    setState(() => _sending = r['roomId'] as String?);
    try {
      final view = await ApiClient.post(
          '/live/${widget.extras.roomId}/pk/invite',
          body: {'targetRoomId': r['roomId']}) as Map<String, dynamic>;
      widget.extras.pendingInvite = view;
      widget.extras.load();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t send the challenge.')));
      }
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: _sheetFrame(context, [
        Row(children: [
          const InIcon(InIcons.swords, size: 22, color: AppColors.pink),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Start a PK battle',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
            'Five minutes. Every gift in your live counts for you — the most coins wins.',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 12),
        if (_error != null || rooms == null || rooms.isEmpty)
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: rooms == null && _error == null
                    ? const Center(child: Spinner(size: 24))
                    : Text(_error ?? 'No one else is live right now.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textFaint)),
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final r = rooms[i];
                final host = (r['host'] as Map?) ?? const {};
                final busy = r['inBattle'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(r['title'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textDim, fontSize: 12.5)),
                          ]),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          busy || _sending != null ? null : () => _invite(r),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14)),
                      child: _sending == r['roomId']
                          ? const Spinner(size: 16)
                          : Text(busy ? 'In a PK' : 'Challenge'),
                    ),
                  ]),
                );
              },
            ),
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
      title: const Text('PK challenge'),
      content: Row(children: [
        Avatar(
            src: from['avatarUrl'] as String?,
            name: from['name'] as String? ?? '',
            size: AvatarSize.md),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              '${from['name'] ?? 'Someone'} wants a 5-minute PK battle with you.'),
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
