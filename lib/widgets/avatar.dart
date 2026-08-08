import 'package:flutter/material.dart';
import '../core/format.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

enum AvatarSize { sm, md, lg }

class Avatar extends StatelessWidget {
  final String? src;
  final String? name;
  final AvatarSize size;

  const Avatar({super.key, this.src, this.name, this.size = AvatarSize.md});

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: d,
        height: d,
        child: (src != null && src!.isNotEmpty)
            ? AppImage(source: src, fit: BoxFit.cover, placeholder: (_) => _fallback(d))
            : _fallback(d),
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
