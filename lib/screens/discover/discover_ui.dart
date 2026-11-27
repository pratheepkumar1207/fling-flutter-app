import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../core/format.dart';

/// Black, white and red pieces shared by Discover, the people map and the
/// long-press card (designs approved 26 Nov 2026).
class DColors {
  DColors._();
  static const red = AppColors.primary; // E8112D
  static const redSoft = Color(0xFFFF5C6E);
  static const redTint = Color(0xFF140406);
  static const card = Color(0xFF0E0E0E);
  static const chip = Color(0xFF1A1A1A);
  static const line = Color(0xFF2A2A2A);
  static const dim = Color(0xFF8A8A8A);
  static const photo = Color(0xFF1F1F1F);
}

/// A small rounded label. [tone]: plain grey, red fill, red outline, white.
enum DTone { plain, red, outline, white }

class DChip extends StatelessWidget {
  final String text;
  final InIconData? icon;
  final DTone tone;
  final VoidCallback? onTap;
  final double fontSize;
  const DChip(this.text,
      {super.key,
      this.icon,
      this.tone = DTone.plain,
      this.onTap,
      this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      DTone.plain => (DColors.chip, const Color(0xFFE6E6E6), null),
      DTone.red => (DColors.red, Colors.white, null),
      DTone.outline => (Colors.transparent, DColors.redSoft, DColors.red),
      DTone.white => (Colors.white, Colors.black, null),
    };
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border, width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          InIcon(icon!, size: fontSize + 2, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: fg, fontSize: fontSize, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
    if (onTap == null) return chip;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: chip);
  }
}

/// How someone's photo ring reads: white = friend or match, red = in a
/// lobby, dashed grey = someone you don't know (area only on the map).
enum RingKind { none, close, lobby, stranger }

class PersonFace extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final RingKind ring;
  final bool online;
  const PersonFace(
      {super.key,
      required this.avatarUrl,
      required this.name,
      this.size = 44,
      this.ring = RingKind.none,
      this.online = false});

  @override
  Widget build(BuildContext context) {
    final w = size >= 50 ? 3.0 : 2.0;
    final color = switch (ring) {
      RingKind.close => Colors.white,
      RingKind.lobby => DColors.red,
      RingKind.stranger => const Color(0xFF8A8A8A),
      RingKind.none => Colors.transparent,
    };
    final face = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? AppImage(source: avatarUrl, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFF262626),
                alignment: Alignment.center,
                child: Text(initials(name),
                    style: TextStyle(
                        color: const Color(0xFF9A9A9A),
                        fontWeight: FontWeight.w700,
                        fontSize: size * 0.36)),
              ),
      ),
    );
    return SizedBox(
      width: size + w * 2,
      height: size + w * 2,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RingPainter(color, w, dashed: ring == RingKind.stranger),
          ),
        ),
        Positioned(left: w, top: w, child: face),
        if (online)
          Positioned(
            right: w * 0.5,
            bottom: w * 0.5,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double width;
  final bool dashed;
  _RingPainter(this.color, this.width, {this.dashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1.6 : width;
    final r = Rect.fromLTWH(
        width / 2, width / 2, size.width - width, size.height - width);
    if (!dashed) {
      canvas.drawOval(r, p);
      return;
    }
    const n = 18;
    for (var i = 0; i < n; i++) {
      final start = i * 2 * 3.14159 / n;
      canvas.drawArc(r, start, 3.14159 / n, false, p);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.dashed != dashed;
}

/// Full-width button: red fill, white fill, red outline, or grey outline.
enum DButtonKind { red, white, outline, ghost }

class DButton extends StatelessWidget {
  final String label;
  final InIconData? icon;
  final DButtonKind kind;
  final VoidCallback? onPressed;
  final bool busy;
  const DButton(this.label,
      {super.key,
      this.icon,
      this.kind = DButtonKind.red,
      this.onPressed,
      this.busy = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      DButtonKind.red => (DColors.red, Colors.white, null),
      DButtonKind.white => (Colors.white, Colors.black, null),
      DButtonKind.outline => (DColors.redTint, DColors.redSoft, DColors.red),
      DButtonKind.ghost => (
          Colors.transparent,
          Colors.white,
          const Color(0xFF444444)
        ),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onPressed,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: border == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.8)),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[
                    InIcon(icon!, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
        ),
      ),
    );
  }
}

/// The grab bar at the top of a bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 34,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(4)),
        ),
      );
}

/// A small caption above a group of options.
class DLabel extends StatelessWidget {
  final String text;
  const DLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: DColors.dim, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// A grey block that gently pulses while something loads.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox(
      {super.key, this.width, required this.height, this.radius = 8});
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
                const Color(0xFF151515), const Color(0xFF222222), _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

/// "Dating", "Long term"… for the lookingFor codes the profile uses.
String lookingForLabel(String? code) => switch (code) {
      'long_term' => 'Long term',
      'short_term' => 'Short term',
      'friends' => 'Friends',
      'not_sure' => 'Not sure yet',
      'explore' => 'Exploring',
      'dating' => 'Dating',
      null || '' => '',
      _ => code.replaceAll('_', ' '),
    };

/// 160 cm → 5'3".
String heightLabel(int? cm) {
  if (cm == null || cm <= 0) return '';
  final inches = (cm / 2.54).round();
  return "${inches ~/ 12}'${inches % 12}\"";
}

/// "Ask to join" requests sent this session, by the person whose lobby it
/// is, so reopening their card still shows the request.
class JoinAsks {
  JoinAsks._();
  static final _at = <String, DateTime>{};
  static const quiet = Duration(minutes: 3); // then "No reply yet"
  static const again =
      Duration(minutes: 10); // the server allows one per 10 min

  static DateTime? askedAt(String userId) => _at[userId];
  static void mark(String userId) => _at[userId] = DateTime.now();
}

/// What a sent request looks like: sent, then "no reply yet" after a few
/// minutes, then a way to ask again.
class AskedNote extends StatefulWidget {
  final String userId;
  final VoidCallback onAskAgain;
  final bool busy;
  const AskedNote(
      {super.key,
      required this.userId,
      required this.onAskAgain,
      this.busy = false});
  @override
  State<AskedNote> createState() => _AskedNoteState();
}

class _AskedNoteState extends State<AskedNote> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
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
    final at = JoinAsks.askedAt(widget.userId);
    final since = at == null ? Duration.zero : DateTime.now().difference(at);
    final quiet = since >= JoinAsks.quiet;
    final canAgain = since >= JoinAsks.again;
    final mins = since.inMinutes;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: DColors.card, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const InIcon(InIcons.hourglass, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quiet
                      ? 'No reply yet. You asked $mins min ago; the host may be busy.'
                      : 'Request sent. You\u2019ll get a notification when the host lets you in.',
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ]),
          ),
          if (canAgain) ...[
            const SizedBox(height: 8),
            DButton('Ask again',
                kind: DButtonKind.outline,
                busy: widget.busy,
                onPressed: widget.onAskAgain),
          ],
        ]);
  }
}
