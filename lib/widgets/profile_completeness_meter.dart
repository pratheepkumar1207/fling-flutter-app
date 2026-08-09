import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Visual nudge toward a richer profile — Dart port of
/// ProfileCompletenessMeter.jsx. Percent comes pre-computed from
/// GET/PATCH /auth/me's completenessPercent.
class ProfileCompletenessMeter extends StatelessWidget {
  final int percent;
  const ProfileCompletenessMeter({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    if (percent >= 100) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile strength', style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('$percent%', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: percent / 100, minHeight: 8, backgroundColor: AppColors.surface3, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          const Text('Add a bio, height, prompts, or get verified to boost visibility.', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ],
      ),
    );
  }
}
