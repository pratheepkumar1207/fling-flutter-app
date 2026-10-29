import 'package:flutter/material.dart';

import '../theme/insync_icons.dart';

/// Blue verified tick shown next to a verified person's name.
class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 14});

  static const color = Color(0xFF3897F0);

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Verified',
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            InIcon(InIcons.verified, size: size, color: color, filled: true),
            InIcon(InIcons.check, size: size * 0.6, color: Colors.white),
          ]),
        ),
      );
}
