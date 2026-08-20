import 'package:flutter/material.dart';
import 'avatar.dart';

/// Host identity row shown just above the chat — avatar (crown badge +
/// green online dot, since being host implies being in the roster right
/// now), name, and a "Host" label underneath.
class RoomHostCard extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final Color textColor;
  final Color goldColor;
  final VoidCallback? onTap;

  const RoomHostCard({super.key, this.avatarUrl, required this.name, required this.textColor, required this.goldColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(src: avatarUrl, name: name, size: AvatarSize.md, ring: true),
                const Positioned(top: -8, left: 6, child: Text('👑', style: TextStyle(fontSize: 16))),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(color: Colors.greenAccent.shade400, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Host', style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
