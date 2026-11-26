import 'package:flutter/material.dart';

/// Creator subscription levels, lowest first. Each includes the ones below.
const kSubTiers = ['silver', 'gold', 'platinum'];

String subTierName(String t) => switch (t) {
      'gold' => 'Gold',
      'platinum' => 'Platinum',
      _ => 'Silver',
    };

/// (accent, card background, text on the accent)
(Color, Color, Color) subTierColors(String t) => switch (t) {
      'gold' => (
          const Color(0xFFF7B21A),
          const Color(0xFF1E1A10),
          const Color(0xFF3A2300)
        ),
      'platinum' => (
          const Color(0xFFFFCCD2),
          const Color(0xFF1F1F1F),
          const Color(0xFF8B8B8B)
        ),
      _ => (
          const Color(0xFFD3D3D3),
          const Color(0xFF191919),
          const Color(0xFF2C2C2A)
        ),
    };

List<String> subTierPerks(String t) => switch (t) {
      'gold' => const [
          'Everything in Silver',
          'Subscriber-only lives and rooms',
          'First in line for the stage',
          'Gold badge',
        ],
      'platinum' => const [
          'Everything in Gold',
          'Message the creator directly',
          'Entry banner when you join a live',
          'Platinum badge and name glow',
        ],
      _ => const [
          'Subscriber stories',
          'Silver badge in chat and lives',
        ],
    };

/// The small "◆ GOLD" badge before a subscriber's name.
class SubTierBadge extends StatelessWidget {
  final String tier;
  final double fontSize;
  const SubTierBadge(this.tier, {super.key, this.fontSize = 8.5});

  @override
  Widget build(BuildContext context) {
    final (accent, _, onAccent) = subTierColors(tier);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
          color: accent, borderRadius: BorderRadius.circular(4)),
      child: Text('◆ ${subTierName(tier).toUpperCase()}',
          style: TextStyle(
              color: onAccent,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.2)),
    );
  }
}
