import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

class _GiftDef {
  final String type;
  final String label;
  final String name;
  final int coins;
  const _GiftDef(this.type, this.label, this.name, this.coins);
}

const _kGifts = [
  _GiftDef('rose', '🌹', 'Rose', 10),
  _GiftDef('heart', '💖', 'Heart', 25),
  _GiftDef('star', '🌟', 'Star', 50),
  _GiftDef('crown', '👑', 'Crown', 100),
  _GiftDef('diamond', '💎', 'Diamond', 500),
  _GiftDef('rocket', '🚀', 'Rocket', 1000),
];

/// Bottom sheet for sending a gift — Dart port of GiftModal.jsx, presented
/// as a sheet (`showGiftBottomSheet`) rather than a centered dialog to match
/// the app's "spatial UI" bottom-sheet convention.
Future<void> showGiftBottomSheet(BuildContext context, {required String toUserId, String? roomId, VoidCallback? onSent}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GiftSheet(toUserId: toUserId, roomId: roomId, onSent: onSent),
  );
}

class _GiftSheet extends StatefulWidget {
  final String toUserId;
  final String? roomId;
  final VoidCallback? onSent;
  const _GiftSheet({required this.toUserId, this.roomId, this.onSent});

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  String? _sending;

  Future<void> _send(_GiftDef gift) async {
    setState(() => _sending = gift.type);
    try {
      await ApiClient.post('/wallet/gift', body: {'roomId': widget.roomId, 'toUserId': widget.toUserId, 'coins': gift.coins, 'giftType': gift.type});
      widget.onSent?.call();
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent a ${gift.name}!')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassSurface(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
            ),
            const Text('Send a gift', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: _kGifts.map((gift) {
                final disabled = _sending != null;
                return GestureDetector(
                  onTap: disabled ? null : () => _send(gift),
                  child: Opacity(
                    opacity: disabled ? 0.5 : 1,
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.label, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 2),
                          Text(gift.name, style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text('${gift.coins} coins', style: const TextStyle(color: AppColors.gold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
