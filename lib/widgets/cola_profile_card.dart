import 'package:flutter/material.dart';
import '../core/format.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

class ColaStat {
  final String label;
  final dynamic value;
  final VoidCallback? onTap;
  const ColaStat(this.label, this.value, {this.onTap});
}

/// Bold "product card" style profile header — Dart port of the web app's
/// gradient ProfilePage/CreatorProfilePage header (Axis Cola reference
/// design: diagonal color-block background, glowing centered avatar, big
/// display name, and a divided "nutrition facts" stat strip).
class ColaProfileCard extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final String? username;
  final String? bio;
  final List<Widget> badges;
  final List<ColaStat> stats;
  final Widget? insideAction;
  final Gradient gradient;

  const ColaProfileCard({
    super.key,
    this.avatarUrl,
    this.name,
    this.username,
    this.bio,
    this.badges = const [],
    this.stats = const [],
    this.insideAction,
    this.gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.accent, AppColors.accent2, AppColors.primaryDim],
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.only(top: 44, bottom: 20, left: 16, right: 16),
        decoration: BoxDecoration(gradient: gradient, boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))]),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -56,
              child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1))),
            ),
            Positioned(
              left: -32,
              bottom: -64,
              child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.1))),
            ),
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 0, spreadRadius: 1),
                      BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: Avatar(src: avatarUrl, name: name, size: AvatarSize.lg),
                ),
                const SizedBox(height: 10),
                Text(
                  name ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
                if (username != null && username!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                      child: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                    ),
                  ),
                if (bio != null && bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(bio!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  ),
                if (badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: badges),
                  ),
                if (insideAction != null) Padding(padding: const EdgeInsets.only(top: 12), child: insideAction!),
                if (stats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.2)))),
                      child: Row(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                            Expanded(
                              child: GestureDetector(
                                onTap: stats[i].onTap,
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  children: [
                                    Text(formatNumber(stats[i].value), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                                    Text(stats[i].label.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
