import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Marks a person's photo on screen, so a gift for them can land on it.
class GiftTarget extends StatefulWidget {
  final String? userId;
  final Widget child;
  const GiftTarget({super.key, required this.userId, required this.child});

  @override
  State<GiftTarget> createState() => _GiftTargetState();
}

class _GiftTargetState extends State<GiftTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    _register(widget.userId);
  }

  @override
  void didUpdateWidget(GiftTarget old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _unregister(old.userId);
      _register(widget.userId);
    }
  }

  void _register(String? id) {
    if (id != null) GiftFx._targets[id] = this;
  }

  void _unregister(String? id) {
    if (id != null && GiftFx._targets[id] == this) GiftFx._targets.remove(id);
  }

  @override
  void dispose() {
    _unregister(widget.userId);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scale: 1 + sin(_pulse.value * pi) * 0.25,
          child: child,
        ),
        child: widget.child,
      );
}

/// One gift as it arrives in a room.
class GiftEvent {
  final String emoji;
  final String name;
  final String type;
  final int coins;
  final num diamonds;
  final int quantity;
  final String fromName;
  final String? toName;
  final String? toUserId;
  const GiftEvent({
    required this.emoji,
    required this.name,
    required this.type,
    required this.coins,
    required this.diamonds,
    this.quantity = 1,
    required this.fromName,
    this.toName,
    this.toUserId,
  });

  factory GiftEvent.fromMap(Map<String, dynamic> g) {
    final quantity = (g['quantity'] as num?)?.toInt() ?? 1;
    return GiftEvent(
      emoji: g['emoji'] as String? ?? '🎁',
      name: g['name'] as String? ?? 'a gift',
      type: g['giftType'] as String? ?? '',
      coins: ((g['coins'] as num?)?.toInt() ?? 0) ~/ max(1, quantity),
      diamonds: (g['diamonds'] as num?) ?? 0,
      quantity: quantity,
      fromName: g['fromName'] as String? ?? 'Someone',
      toName: g['toName'] as String?,
      toUserId: g['toUserId'] as String?,
    );
  }
}

/// Plays gifts over the screen. Small ones overlap; bigger ones wait their
/// turn, so a busy room doesn't turn into chaos.
class GiftFx {
  static final Map<String, _GiftTargetState> _targets = {};
  static final List<_Play> _queue = [];
  static OverlayEntry? _bigEntry;
  static final Set<OverlayEntry> _entries = {};

  /// Stops everything, when leaving a room.
  static void clear() {
    _queue.clear();
    for (final e in _entries) {
      e.remove();
    }
    _entries.clear();
    _bigEntry = null;
  }

  /// [keepTop] is how far down the screen must stay clear, such as a video.
  /// With [bannerOnly], only the name shows, for full-screen video.
  static void play(BuildContext context, GiftEvent gift,
      {double keepTop = 0, bool bannerOnly = false}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final media = MediaQuery.of(context);
    final play = _Play(overlay, gift, media.size, media.padding.top, keepTop,
        bannerOnly || media.disableAnimations);
    if (gift.coins < 200 || play.bannerOnly) {
      _start(play, big: false);
    } else if (_bigEntry == null) {
      _start(play, big: true);
    } else {
      _queue.add(play);
    }
  }

  static void _start(_Play play, {required bool big}) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _GiftAnimation(
          play: play,
          onDone: () {
            if (_entries.remove(entry)) entry.remove();
            if (big) {
              _bigEntry = null;
              if (_queue.isNotEmpty) _start(_queue.removeAt(0), big: true);
            }
          },
        ),
      ),
    );
    if (big) _bigEntry = entry;
    _entries.add(entry);
    play.overlay.insert(entry);
  }
}

class _Play {
  final OverlayState overlay;
  final GiftEvent gift;
  final Size size;
  final double topInset;
  final double keepTop;
  final bool bannerOnly;
  _Play(this.overlay, this.gift, this.size, this.topInset, this.keepTop,
      this.bannerOnly);
}

class _Key {
  final double t;
  final Offset at;
  final double scale;
  final double opacity;
  final double turn;
  const _Key(this.t, this.at,
      {this.scale = 1, this.opacity = 1, this.turn = 0});
}

class _Sprite {
  final String emoji;
  final double size;
  final int delayMs;
  final int ms;
  final List<_Key> keys;
  final bool flip;
  const _Sprite(this.emoji, this.size, this.delayMs, this.ms, this.keys,
      {this.flip = false});
}

/// The style each gift plays with; anything else goes by its price.
const _styles = <String, String>{
  'balloon': 'rise',
  'crown': 'crown',
  'cake': 'center',
  'diamond': 'shine',
  'sports_car': 'drive',
  'rocket': 'rocket',
  'yacht': 'drive',
  'jet': 'fly',
  'castle': 'castle',
  'butterfly': 'flutter',
  'ring': 'shine',
  'rainbow': 'center',
  'moon': 'moon',
  'rose_rain': 'rain',
  'dragon': 'flutter',
  'jackpot': 'center',
  'crystal_ball': 'shine',
  'unicorn': 'fly',
  'fireworks': 'fireworks',
  'mic_drop': 'center',
  'party': 'center',
  'trophy': 'shine',
  'superfan': 'fireworks',
};

class _GiftAnimation extends StatefulWidget {
  final _Play play;
  final VoidCallback onDone;
  const _GiftAnimation({required this.play, required this.onDone});

  @override
  State<_GiftAnimation> createState() => _GiftAnimationState();
}

class _GiftAnimationState extends State<_GiftAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rand = Random();
  final List<_Sprite> _sprites = [];
  bool _dim = false;
  late Offset _target;
  late bool _hasTarget;
  int _landMs = 1000;
  int _totalMs = 2000;
  Timer? _landTimer;

  _Play get p => widget.play;
  double get _w => p.size.width;
  double get _h => p.size.height;
  double get _top => max(p.keepTop, p.topInset);
  Offset get _middle => Offset(_w / 2, _top + (_h - _top) * 0.42);

  @override
  void initState() {
    super.initState();
    final state = GiftFx._targets[p.gift.toUserId];
    final box = state?.context.findRenderObject() as RenderBox?;
    _hasTarget = box != null && box.attached;
    _target = _hasTarget
        ? box!.localToGlobal(box.size.center(Offset.zero))
        : Offset(_w / 2, _top + 30);
    if (!p.bannerOnly) _build();
    _c = AnimationController(
        vsync: this, duration: Duration(milliseconds: _totalMs))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
    if (!p.bannerOnly) {
      _landTimer = Timer(Duration(milliseconds: _landMs),
          () => GiftFx._targets[p.gift.toUserId]?._pulse.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _landTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _build() {
    final g = p.gift;
    final style = _styles[g.type] ??
        (g.coins >= 1000
            ? 'shine'
            : g.coins >= 200
                ? 'center'
                : 'float');
    switch (style) {
      case 'rise':
        _rise();
      case 'crown':
        _hero(from: Offset(_w / 2, _top - 80), size: 84, ms: 1900);
        _burst(_middle, const ['✨', '⭐'], 14, 110, 700);
      case 'center':
        _hero(from: _middle, grow: true, size: 110, ms: 2000);
        _burst(_middle, const ['🎉', '✨', '🎊'], 20, 140, 500);
      case 'shine':
        _dim = g.coins >= 1000;
        _hero(from: _middle, grow: true, size: 116, ms: 2300);
        for (final t in const [600, 1050, 1500]) {
          _burst(_middle, const ['✨', '💫'], 12, 125, t);
        }
      case 'drive':
        _hero(
            from: Offset(_w + 90, _middle.dy), size: 92, ms: 2200, flip: true);
      case 'fly':
        _hero(from: Offset(-90, _h * 0.6), size: 84, ms: 2100);
        _burst(_middle, const ['☁️', '✨'], 10, 100, 800);
      case 'flutter':
        _flutter();
      case 'rocket':
        _dim = true;
        _hero(from: Offset(_w * 0.25, _h + 60), size: 104, ms: 2400);
        _burst(Offset(_w / 2, _h * 0.7), const ['🔥', '💨'], 16, 90, 500);
        _burst(_middle, const ['✨', '⭐', '🎉'], 26, 165, 1300);
      case 'castle':
        _dim = true;
        _hero(from: Offset(_w / 2, _h + 90), size: 150, ms: 3000);
        for (var i = 0; i < 4; i++) {
          _burst(Offset(_w * (0.18 + i * 0.22), _top + 60 + (i % 2) * 40),
              const ['🎆', '✨', '🎇'], 12, 100, 1100 + i * 420);
        }
      case 'moon':
        _dim = true;
        _hero(from: Offset(_w / 2, _h + 70), size: 120, ms: 2700);
        for (var i = 0; i < 22; i++) {
          final at = Offset(_rand.nextDouble() * _w,
              _top + _rand.nextDouble() * (_h - _top) * 0.6);
          _sprites.add(_Sprite('✨', 10 + _rand.nextDouble() * 12,
              500 + _rand.nextInt(1500), 1000, [
            _Key(0, at, opacity: 0),
            _Key(.5, at),
            _Key(1, at, opacity: 0),
          ]));
        }
      case 'rain':
        _dim = true;
        _rain();
      case 'fireworks':
        _dim = true;
        _fireworks();
      default:
        _float();
    }
    _totalMs = max(_totalMs, _landMs + 900);
  }

  /// The gift appears, holds, then shrinks and flies to the person.
  void _hero(
      {required Offset from,
      required double size,
      required int ms,
      bool grow = false,
      bool flip = false}) {
    _sprites.add(_Sprite(
        p.gift.emoji,
        size,
        0,
        ms,
        [
          _Key(0, from, scale: grow ? 0 : .8, opacity: grow ? 0 : 1),
          _Key(.3, _middle, scale: grow ? 1.15 : 1.05),
          _Key(.68, _middle),
          _Key(.97, _target, scale: .28),
          _Key(1, _target, scale: .28, opacity: 0),
        ],
        flip: flip));
    _landMs = (ms * .97).round();
    _totalMs = ms;
  }

  void _float() {
    final n = min(6, 4 + p.gift.quantity);
    for (var i = 0; i < n; i++) {
      final from = Offset(_w / 2 - 40 + _rand.nextDouble() * 80, _h - 150);
      _sprites.add(_Sprite(p.gift.emoji, 28, i * 90, 1000, [
        _Key(0, from, scale: .6, opacity: 0),
        _Key(.25, from.translate(0, -60)),
        _Key(.92, _target, scale: .7),
        _Key(1, _target, scale: 1.1, opacity: 0),
      ]));
    }
    _landMs = 1000 + (n - 1) * 90;
    _totalMs = _landMs + 900;
  }

  void _rise() {
    for (var i = 0; i < 8; i++) {
      final from = Offset(_rand.nextDouble() * _w, _h + 30);
      _sprites.add(
          _Sprite(p.gift.emoji, 30 + _rand.nextDouble() * 14, i * 70, 1800, [
        _Key(0, from),
        _Key(.65, from.translate(i.isOdd ? 18 : -18, -(_h - _top) * .6)),
        _Key(1, _target, scale: .4, opacity: .2),
      ]));
    }
    _landMs = 1800 + 7 * 70;
    _totalMs = _landMs + 900;
  }

  void _flutter() {
    final keys = <_Key>[];
    for (var i = 0; i <= 6; i++) {
      keys.add(_Key(i / 6 * .75,
          Offset(-60 + i * (_w + 40) / 6, _middle.dy + sin(i * 1.5) * 60),
          scale: i.isOdd ? 1 : .92));
    }
    keys.add(_Key(.98, _target, scale: .3));
    keys.add(_Key(1, _target, scale: .3, opacity: 0));
    _sprites.add(_Sprite(p.gift.emoji, 78, 0, 2600, keys));
    _landMs = 2550;
    _totalMs = 2600;
  }

  void _rain() {
    for (var i = 0; i < 40; i++) {
      final x = _rand.nextDouble() * _w;
      _sprites.add(_Sprite(p.gift.emoji, 18 + _rand.nextDouble() * 18,
          _rand.nextInt(1300), 1400 + _rand.nextInt(800), [
        _Key(0, Offset(x, _top - 30)),
        _Key(1, Offset(x + _rand.nextDouble() * 50 - 25, _h + 30), turn: 4),
      ]));
    }
    _sprites.add(_Sprite(p.gift.emoji, 44, 2300, 700, [
      _Key(0, _middle, opacity: 0),
      _Key(.2, _middle),
      _Key(1, _target, scale: .5),
    ]));
    _landMs = 3000;
    _totalMs = 3000;
  }

  void _fireworks() {
    for (var i = 0; i < 6; i++) {
      final at = Offset(_w * (.2 + _rand.nextDouble() * .6),
          _top + 50 + _rand.nextDouble() * (_h - _top) * .4);
      _sprites.add(_Sprite('✨', 16, i * 420, 360, [
        _Key(0, Offset(at.dx, _h)),
        _Key(1, at, opacity: .8),
      ]));
      _burst(at, const ['🎆', '🎇', '✨', '💥'], 20, 115, i * 420 + 360);
    }
    _sprites.add(_Sprite(p.gift.emoji, 44, 2500, 700, [
      _Key(0, _middle, opacity: 0),
      _Key(.2, _middle),
      _Key(1, _target, scale: .5),
    ]));
    _landMs = 3200;
    _totalMs = 3200;
  }

  void _burst(Offset at, List<String> items, int n, double radius, int delay) {
    for (var i = 0; i < n; i++) {
      final a = _rand.nextDouble() * 2 * pi;
      final d = radius * (.5 + _rand.nextDouble() * .6);
      _sprites.add(_Sprite(items[i % items.length],
          14 + _rand.nextDouble() * 12, delay, 900 + _rand.nextInt(400), [
        _Key(0, at, scale: .4),
        _Key(1, at + Offset(cos(a) * d, sin(a) * d), opacity: 0),
      ]));
    }
  }

  Widget _sprite(_Sprite s, double nowMs) {
    final t = (nowMs - s.delayMs) / s.ms;
    if (t < 0 || t > 1) return const SizedBox.shrink();
    var i = 0;
    while (i < s.keys.length - 2 && t > s.keys[i + 1].t) {
      i++;
    }
    final a = s.keys[i], b = s.keys[i + 1];
    final span = b.t - a.t;
    final u = Curves.easeInOut
        .transform(span <= 0 ? 1.0 : ((t - a.t) / span).clamp(0.0, 1.0));
    final at = Offset.lerp(a.at, b.at, u)!;
    final scale = a.scale + (b.scale - a.scale) * u;
    final opacity = (a.opacity + (b.opacity - a.opacity) * u).clamp(0.0, 1.0);
    final turn = a.turn + (b.turn - a.turn) * u;
    Widget child = Text(s.emoji,
        style: TextStyle(
            fontSize: s.size,
            height: 1,
            decoration: TextDecoration.none,
            fontFamilyFallback: const ['Noto Color Emoji']));
    if (s.flip) child = Transform.flip(flipX: true, child: child);
    return Positioned(
      left: at.dx - s.size * .6,
      top: at.dy - s.size * .6,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
            angle: turn, child: Transform.scale(scale: scale, child: child)),
      ),
    );
  }

  double _fade(double ms, int total) {
    if (ms < 200) return ms / 200;
    if (ms > total - 300) return ((total - ms) / 300).clamp(0.0, 1.0);
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final g = p.gift;
    final who = g.toName == null ? '' : ' to ${g.toName}';
    final count = g.quantity > 1 ? ' ×${g.quantity}' : '';
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _c.value * _totalMs;
          final plusT = (ms - _landMs) / 800;
          return Stack(children: [
            if (_dim)
              Positioned.fill(
                top: p.keepTop,
                child: ColoredBox(
                    color: Colors.black
                        .withValues(alpha: .5 * _fade(ms, _totalMs))),
              ),
            for (final s in _sprites) _sprite(s, ms),
            if (!p.bannerOnly &&
                _hasTarget &&
                g.diamonds > 0 &&
                plusT > 0 &&
                plusT < 1)
              Positioned(
                left: min(_target.dx + 20, _w - 90),
                top: _target.dy - 12 - plusT * 18,
                child: Opacity(
                  opacity: plusT < .25 ? plusT * 4 : 1 - (plusT - .25) / .75,
                  child: Text('+${g.diamonds.round()} 💎',
                      style: const TextStyle(
                          color: Color(0xFF7FD0FF),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none)),
                ),
              ),
            Positioned(
              left: 8,
              right: 60,
              bottom: p.size.height * .3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: _fade(ms, _totalMs),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xCC0B0912),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                        '${g.fromName} sent ${g.emoji} ${g.name}$count$who',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            decoration: TextDecoration.none)),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
