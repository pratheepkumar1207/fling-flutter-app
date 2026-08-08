import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Spinner extends StatelessWidget {
  final double size;
  const Spinner({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
    );
  }
}
