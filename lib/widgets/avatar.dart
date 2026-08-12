import 'package:flutter/material.dart';
import '../core/format.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

enum AvatarSize { sm, md, lg }

class Avatar extends StatelessWidget {
  final String? src;
  final String? name;
  final AvatarSize size;

  /// Wraps the avatar in the brand-gradient "story ring" — Instagram's
  /// signature avatar treatment. Off by default; opt in per call site
  /// (e.g. the top bar) rather than everywhere at once.
  final bool ring;

  const Avatar({super.key, this.src, this.name, this.size = AvatarSize.md, this.ring = false});

  double get _dimension {
    switch (size) {
      case AvatarSize.sm:
        return 32;
      case AvatarSize.lg:
        return 96;
      case AvatarSize.md:
        return 48;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _dimension;
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: d,
        height: d,
        child: (src != null && src!.isNotEmpty)
            ? AppImage(source: src, fit: BoxFit.cover, placeholder: (_) => _fallback(d))
            : _fallback(d),
      ),
    );
    if (!ring) return avatar;
    const ringWidth = 2.5;
    return Container(
      width: d + ringWidth * 2,
      height: d + ringWidth * 2,
      padding: const EdgeInsets.all(ringWidth),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppGradients.brand, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
        child: avatar,
      ),
    );
  }

  Widget _fallback(double d) {
    return Container(
      color: AppColors.surface3,
      alignment: Alignment.center,
      child: Text(
        initials(name),
        style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.bold, fontSize: d * 0.35),
      ),
    );
  }
}
