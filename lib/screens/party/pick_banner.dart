import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';

/// "Vote for what plays next · 7s" while the 10s window runs, then
/// "Pick what plays next" once it ends with no votes.
class PickBanner extends StatefulWidget {
  final DateTime? endsAt;
  final bool waiting;
  const PickBanner({super.key, required this.endsAt, required this.waiting});

  @override
  State<PickBanner> createState() => PickBannerState();
}

class PickBannerState extends State<PickBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
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
    final left = widget.endsAt == null
        ? 0
        : (widget.endsAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 10);
    final voting = !widget.waiting && left > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1640),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Stack(alignment: Alignment.center, children: [
            if (voting)
              CircularProgressIndicator(
                value: left / 10,
                strokeWidth: 2.5,
                color: AppColors.lilac,
                backgroundColor: Colors.white12,
              ),
            voting
                ? Text('$left',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13))
                : const InIcon(InIcons.music, size: 18, color: AppColors.lilac),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    voting
                        ? 'Vote for what plays next'
                        : 'Pick what plays next',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                    voting
                        ? 'Tap a suggestion · most votes plays in ${left}s'
                        : 'Tap a suggestion and it plays for everyone',
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 11.5)),
              ]),
        ),
      ]),
    );
  }
}
