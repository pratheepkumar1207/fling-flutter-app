import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';
import 'app_image.dart';

/// Opens a view-once photo: asks the server for it (which only works once)
/// and shows it full screen for [seconds], then closes. Returns false if it
/// couldn't be opened (already opened, expired, not yours).
Future<bool> openViewOncePhoto(BuildContext context, String openPath,
    {String? title}) async {
  try {
    final r = await ApiClient.post(openPath) as Map;
    final url = r['mediaUrl'] as String?;
    if (url == null || !context.mounted) return false;
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => ViewOnceViewer(
          mediaUrl: url,
          title: title,
          seconds: (r['seconds'] as num?)?.toInt() ?? 10),
    ));
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// Full-screen photo with a countdown ring; closes itself when time is up.
class ViewOnceViewer extends StatefulWidget {
  final String mediaUrl;
  final String? title;
  final int seconds;
  const ViewOnceViewer(
      {super.key, required this.mediaUrl, this.title, this.seconds = 10});

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(
      vsync: this, duration: Duration(seconds: widget.seconds))
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });

  int get _left => (widget.seconds * (1 - _timer.value)).ceil();

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            child: AnimatedBuilder(
              animation: _timer,
              builder: (_, __) => Row(children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: 1 - _timer.value,
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                    Text('$_left',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title ?? 'View once photo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        Text('Closes in $_left second${_left == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12.5)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const InIcon(InIcons.close, color: Colors.white),
                ),
              ]),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              child: Center(
                  child:
                      AppImage(source: widget.mediaUrl, fit: BoxFit.contain)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              InIcon(InIcons.lock, size: 14, color: Colors.white54),
              SizedBox(width: 6),
              Flexible(
                child: Text('Can’t screenshot, save or forward',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The card for a view-once photo in a private chat.
class ViewOnceCard extends StatelessWidget {
  final bool mine;
  final VoidCallback? onOpen;
  const ViewOnceCard({super.key, required this.mine, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : AppColors.text;
    return Semantics(
      button: onOpen != null,
      label: mine
          ? 'View once photo, sent, not seen yet'
          : 'View once photo, tap to open for 10 seconds',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mine
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFF2B1640),
              ),
              child: Center(
                  child: InIcon(mine ? InIcons.send : InIcons.eye,
                      size: 18, color: mine ? Colors.white : AppColors.lilac)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Photo',
                        style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5)),
                    Text(mine ? 'Sent · not seen yet' : 'Tap to open · 10 sec',
                        style: TextStyle(
                            color: mine
                                ? const Color(0xFFE7DDF5)
                                : AppColors.textDim,
                            fontSize: 12)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// What's left after a view-once photo has been seen.
class ViewOnceGoneNote extends StatelessWidget {
  final String text;
  const ViewOnceGoneNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const InIcon(InIcons.eyeoff, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
        ]),
      );

  /// "Photo viewed · 4:12 PM" / "Divya viewed your photo · 4:12 PM".
  static String label({required bool mine, String? name, DateTime? at}) {
    final when = at == null ? '' : ' · ${_clock(at)}';
    return mine
        ? '${name ?? 'They'} viewed your photo$when'
        : 'Photo viewed and removed$when';
  }
}

/// Telegram-style disappearing: when [gone] turns true, [child] breaks into
/// dust that blows away (left edge first), then [after] takes its place.
/// If it's already gone when first shown, [after] shows straight away.
class VanishOnce extends StatefulWidget {
  final bool gone;
  final Widget child;
  final Widget after;
  final Color color;
  const VanishOnce(
      {super.key,
      required this.gone,
      required this.child,
      required this.after,
      this.color = AppColors.lilac});

  @override
  State<VanishOnce> createState() => _VanishOnceState();
}

class _VanishOnceState extends State<VanishOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dust;
  late bool _done = widget.gone;

  @override
  void initState() {
    super.initState();
    _dust = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
  }

  Size? _size;
  final _key = GlobalKey();
  final _seed = Random();
  late List<_Grain> _grains = const [];

  @override
  void didUpdateWidget(covariant VanishOnce old) {
    super.didUpdateWidget(old);
    if (!old.gone && widget.gone && !_done) _blowAway();
  }

  void _blowAway() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    _size = box?.size;
    if (_size == null) {
      setState(() => _done = true);
      return;
    }
    HapticFeedback.lightImpact();
    final w = _size!.width, h = _size!.height;
    _grains = [
      for (var i = 0; i < 260; i++)
        _Grain(
          x: _seed.nextDouble() * w,
          y: _seed.nextDouble() * h,
          vx: 40 + _seed.nextDouble() * 110,
          vy: -30 - _seed.nextDouble() * 70,
          light: _seed.nextBool(),
        ),
    ];
    setState(() {});
    _dust.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _dust.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.after;
    if (!_dust.isAnimating && _grains.isEmpty) {
      return KeyedSubtree(key: _key, child: widget.child);
    }
    return SizedBox.fromSize(
      size: _size,
      child: AnimatedBuilder(
        animation: _dust,
        builder: (_, __) => CustomPaint(
          painter: _DustPainter(
              _grains, _dust.value, widget.color, _size?.width ?? 1),
        ),
      ),
    );
  }
}

class _Grain {
  final double x, y, vx, vy;
  final bool light;
  const _Grain(
      {required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.light});
}

class _DustPainter extends CustomPainter {
  final List<_Grain> grains;
  final double t;
  final Color color;
  final double width;
  _DustPainter(this.grains, this.t, this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = color;
    final dark = Paint()..color = AppColors.primary;
    for (final g in grains) {
      // Left side goes first, like it's swept off the screen.
      final start = (g.x / width) * 0.35;
      final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
      final alpha = (1 - local).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final p = g.light ? light : dark;
      p.color = p.color.withValues(alpha: alpha);
      canvas.drawRect(
          Rect.fromLTWH(g.x + g.vx * local,
              g.y + g.vy * local + 40 * local * local, 2.2, 2.2),
          p);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => old.t != t;
}

/// Sender only: who has seen your view-once photo in a room, newest first.
Future<void> showRoomViewOnceSeen(BuildContext context,
    {required String roomId, required String photoId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _SeenBySheet(roomId: roomId, photoId: photoId),
  );
}

class _SeenBySheet extends StatefulWidget {
  final String roomId;
  final String photoId;
  const _SeenBySheet({required this.roomId, required this.photoId});

  @override
  State<_SeenBySheet> createState() => _SeenBySheetState();
}

class _SeenBySheetState extends State<_SeenBySheet> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiClient.get('/rooms/${widget.roomId}/view-once/${widget.photoId}/seen')
        .then((r) {
      if (mounted) setState(() => _data = Map<String, dynamic>.from(r as Map));
    }).catchError((e) {
      if (mounted) {
        setState(() =>
            _error = e is ApiException ? e.message : 'Couldn’t load this');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final viewers = ((d?['viewers'] as List?) ?? const []).cast<Map>();
    final expires = DateTime.tryParse('${d?['expiresAt']}');
    final minsLeft = expires?.difference(DateTime.now()).inMinutes;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Seen by ${d?['seenCount'] ?? viewers.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      if (d != null)
                        Text(
                            [
                              'of ${d['inRoom']} in the room',
                              if (minsLeft != null && minsLeft >= 0)
                                'expires in $minsLeft min',
                            ].join(' · '),
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12.5)),
                    ]),
              ),
              const InIcon(InIcons.eye, size: 20, color: AppColors.lilac),
            ]),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.textDim)))
          else if (d == null)
            const Padding(
                padding: EdgeInsets.all(24), child: CircularProgressIndicator())
          else if (viewers.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No one has opened it yet',
                    style: TextStyle(color: AppColors.textDim)))
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final v in viewers)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2B1640),
                      backgroundImage: (v['avatarUrl'] as String?) != null &&
                              (v['avatarUrl'] as String).startsWith('http')
                          ? NetworkImage(v['avatarUrl'] as String)
                          : null,
                      child: Text(
                          ((v['name'] as String?) ?? '?')
                              .characters
                              .first
                              .toUpperCase(),
                          style: const TextStyle(color: AppColors.lilac)),
                    ),
                    title: Text(v['name'] as String? ?? 'Someone'),
                    subtitle: Text(
                        [
                          if (v['username'] != null) '@${v['username']}',
                          if (DateTime.tryParse('${v['at']}') case final t?)
                            _clock(t),
                        ].join(' · '),
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12)),
                  ),
              ]),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
