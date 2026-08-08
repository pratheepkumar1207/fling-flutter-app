import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Live-ticking countdown pill for scheduled rooms/events — Dart port of
/// CountdownBadge.jsx. Ticks on its own every 30s (plenty granular for an
/// hours/days-away countdown) rather than depending on the parent re-fetching.
class CountdownBadge extends StatefulWidget {
  final DateTime scheduledAt;
  const CountdownBadge({super.key, required this.scheduledAt});

  @override
  State<CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<CountdownBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.scheduledAt.difference(DateTime.now());
    if (diff.inMilliseconds <= 0) {
      return _pill('Starting now', AppColors.success);
    }

    final totalMinutes = (diff.inMilliseconds / 60000).ceil();
    final days = totalMinutes ~/ (60 * 24);
    final hours = (totalMinutes % (60 * 24)) ~/ 60;
    final minutes = totalMinutes % 60;

    final label = days > 0 ? '${days}d ${hours}h' : hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    return _pill('⏱ $label', AppColors.accent);
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
