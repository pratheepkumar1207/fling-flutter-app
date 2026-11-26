import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../messages/message_thread_screen.dart';
import 'discover_sheets.dart';
import 'discover_ui.dart';
import 'peek_card.dart';
import 'swipe_card.dart';

/// Random match: one random person at a time (GET /discover/random).
class RandomMatchScreen extends StatefulWidget {
  const RandomMatchScreen({super.key});

  @override
  State<RandomMatchScreen> createState() => _RandomMatchScreenState();
}

class _RandomMatchScreenState extends State<RandomMatchScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  DiscoverProfile? _current;
  bool _searching = true;
  bool _none = false;
  String? _gender;
  bool _onlineOnly = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _next();
  }

  Timer? _wait;

  @override
  void dispose() {
    _wait?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final mine = ++_seq;
    setState(() {
      _searching = true;
      _none = false;
      _current = null;
    });
    final started = DateTime.now();
    DiscoverProfile? found;
    try {
      final q = [
        if (_gender != null) 'gender=$_gender',
        if (_onlineOnly) 'onlineOnly=true'
      ].join('&');
      final data =
          await ApiClient.get('/discover/random${q.isEmpty ? '' : '?$q'}');
      if (data != null) {
        found = DiscoverProfile.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {}
    // A short search feels like looking, not a flash.
    final wait =
        const Duration(milliseconds: 1100) - DateTime.now().difference(started);
    if (wait > Duration.zero) {
      final done = Completer<void>();
      _wait = Timer(wait, done.complete);
      await done.future;
    }
    if (!mounted || mine != _seq) return;
    setState(() {
      _current = found;
      _searching = false;
      _none = found == null;
    });
  }

  Future<void> _swipe(String action) async {
    final current = _current;
    if (current == null) return;
    try {
      final res = await ApiClient.post('/swipe',
              body: {'toUserId': current.id, 'action': action})
          as Map<String, dynamic>;
      if (!mounted) return;
      if (res['matched'] == true) {
        await _matched(current);
        return;
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 429 && e.data is Map) {
        await showOutOfLikesSheet(context, e.data as Map,
            superLike: (e.data as Map)['code'] == 'superlike_limit');
        return;
      }
    } catch (_) {}
    _next();
  }

  Future<void> _matched(DiscoverProfile p) async {
    final chat = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: DColors.card,
        title: const Text('It’s a match',
            style: TextStyle(color: DColors.red, fontWeight: FontWeight.w900)),
        content: Text('You and ${p.name} liked each other.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Keep going')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Send a message')),
        ],
      ),
    );
    if (!mounted) return;
    if (chat == true) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MessageThreadScreen(
              userId: p.id, name: p.name, avatarUrl: p.avatarUrl)));
    }
    _next();
  }

  Widget _filters() {
    return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final g in const [
            ('female', 'Women'),
            ('male', 'Men'),
            (null, 'Everyone')
          ])
            DChip(g.$2, tone: _gender == g.$1 ? DTone.white : DTone.plain,
                onTap: () {
              setState(() => _gender = g.$1);
              _next();
            }),
          DChip('Online now', tone: _onlineOnly ? DTone.outline : DTone.plain,
              onTap: () {
            setState(() => _onlineOnly = !_onlineOnly);
            _next();
          }),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const InIcon(InIcons.close, color: Colors.white)),
        title: const Text('Random match'),
      ),
      body: SafeArea(
        top: false,
        child: current != null && !_searching
            ? Column(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _filters()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SwipeCard(
                      key: ValueKey(current.id),
                      profile: current,
                      active: true,
                      onSwipe: _swipe,
                      onLongPress: () => showPeekCard(context, current.id),
                      onOpen: () => showPeekCard(context, current.id),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _btn(InIcons.close, 'Nope', () => _swipe('pass'), 60),
                        const SizedBox(width: 14),
                        _btn(InIcons.dice, 'Someone else', _next, 48),
                        const SizedBox(width: 14),
                        _btn(InIcons.heart, 'Like', () => _swipe('like'), 60,
                            red: true),
                      ]),
                ),
              ])
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const Spacer(),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => CustomPaint(
                        painter: _Rings(_searching ? _pulse.value : 0),
                        child: Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              shape: BoxShape.circle,
                              border: Border.all(color: DColors.red, width: 3),
                            ),
                            alignment: Alignment.center,
                            child: Transform.rotate(
                              angle:
                                  _searching ? _pulse.value * math.pi * 2 : 0,
                              child: const InIcon(InIcons.dice,
                                  size: 32, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(_none ? 'No one right now' : 'Finding someone…',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      _none
                          ? 'Try again in a bit, or change who you’re looking for.'
                          : [
                              if (_onlineOnly) 'Online now',
                              _gender == 'female'
                                  ? 'Women'
                                  : _gender == 'male'
                                      ? 'Men'
                                      : 'Everyone'
                            ].join(' · '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: DColors.dim, fontSize: 13)),
                  const SizedBox(height: 16),
                  _filters(),
                  const Spacer(),
                  if (_none)
                    DButton('Try again', icon: InIcons.dice, onPressed: _next)
                  else
                    DButton('Cancel',
                        kind: DButtonKind.ghost,
                        onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 16),
                ]),
              ),
      ),
    );
  }

  Widget _btn(InIconData icon, String label, VoidCallback onTap, double size,
      {bool red = false}) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: red ? DColors.red : const Color(0xFF111111),
            border: red ? null : Border.all(color: const Color(0xFF333333)),
          ),
          alignment: Alignment.center,
          child:
              InIcon(icon, size: size * 0.42, color: Colors.white, filled: red),
        ),
      ),
    );
  }
}

class _Rings extends CustomPainter {
  final double t;
  _Rings(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1.0;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = DColors.red.withValues(alpha: (1 - f) * 0.6);
      canvas.drawCircle(c, 40 + f * 50, p);
    }
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t;
}
