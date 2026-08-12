import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/avatar_frame_cache.dart';
import '../../models/avatar_frame.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// VIP cosmetic store — purchasable avatar frames (see AvatarFrameCache,
/// GET/POST /store/avatar-frames).
class VipStoreScreen extends StatefulWidget {
  const VipStoreScreen({super.key});

  @override
  State<VipStoreScreen> createState() => _VipStoreScreenState();
}

class _VipStoreScreenState extends State<VipStoreScreen> {
  List<AvatarFrame>? _frames;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/store/avatar-frames');
      if (!mounted) return;
      setState(() => _frames = (data as List).map((e) => AvatarFrame.fromJson(e as Map<String, dynamic>)).toList());
      await AvatarFrameCache.refresh();
    } catch (_) {
      if (mounted) setState(() => _frames = []);
    }
  }

  Future<void> _handleTap(AvatarFrame frame) async {
    if (_busyId != null) return;
    setState(() => _busyId = frame.id);
    try {
      if (!frame.owned) {
        await ApiClient.post('/store/avatar-frames/${frame.id}/purchase');
      } else if (frame.equipped) {
        await ApiClient.post('/store/avatar-frames/unequip');
      } else {
        await ApiClient.post('/store/avatar-frames/${frame.id}/equip');
      }
      if (!mounted) return;
      await Future.wait([_load(), context.read<AuthProvider>().refreshUser()]);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = context.watch<AuthProvider>().user?.coinBalance ?? 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('VIP Store'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('🪙 ${coinBalance.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600))),
          ),
        ],
      ),
      body: _frames == null
          ? const Center(child: Spinner(size: 28))
          : _frames!.isEmpty
              ? const Center(child: Text('No frames available yet.', style: TextStyle(color: AppColors.textFaint)))
              : GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                  children: _frames!.map((frame) {
                    final busy = _busyId == frame.id;
                    return GestureDetector(
                      onTap: busy ? null : () => _handleTap(frame),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: frame.equipped ? AppColors.primary : AppColors.border, width: frame.equipped ? 2 : 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: busy ? const Center(child: Spinner(size: 20)) : Image.network(frame.imageUrl, fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 8),
                            Text(frame.name, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              frame.equipped ? 'Equipped' : (frame.owned ? 'Tap to equip' : '🪙 ${frame.coinCost}'),
                              style: TextStyle(color: frame.equipped ? AppColors.primary : AppColors.textFaint, fontSize: 10, fontWeight: frame.equipped ? FontWeight.w700 : FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
