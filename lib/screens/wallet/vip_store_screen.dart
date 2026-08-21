import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/avatar_frame_cache.dart';
import '../../models/admission_car.dart';
import '../../models/avatar_frame.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// VIP cosmetic store — two categories: purchasable avatar frames (GET/POST
/// /store/avatar-frames) and admission cars (GET/POST
/// /store/admission-cars). Same purchase/equip/unequip shape for both;
/// admission cars additionally carry a durationDays/expiry.
class VipStoreScreen extends StatefulWidget {
  const VipStoreScreen({super.key});

  @override
  State<VipStoreScreen> createState() => _VipStoreScreenState();
}

enum _Category { frames, cars }

class _VipStoreScreenState extends State<VipStoreScreen> {
  _Category _category = _Category.frames;
  List<AvatarFrame>? _frames;
  List<AdmissionCar>? _cars;
  String? _busyId;
  bool _buyingVip = false;

  static const _vipCostCoins = 500;

  Future<void> _buyVip() async {
    setState(() => _buyingVip = true);
    try {
      await ApiClient.post('/wallet/buy-vip');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VIP activated!')));
      if (mounted) await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _buyingVip = false);
    }
  }

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
    try {
      final data = await ApiClient.get('/store/admission-cars');
      if (!mounted) return;
      setState(() => _cars = (data as List).map((e) => AdmissionCar.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {
      if (mounted) setState(() => _cars = []);
    }
  }

  Future<void> _handleFrameTap(AvatarFrame frame) async {
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

  Future<void> _handleCarTap(AdmissionCar car) async {
    if (_busyId != null) return;
    setState(() => _busyId = car.id);
    try {
      if (!car.owned) {
        await ApiClient.post('/store/admission-cars/${car.id}/purchase');
      } else if (car.equipped) {
        await ApiClient.post('/store/admission-cars/unequip');
      } else {
        await ApiClient.post('/store/admission-cars/${car.id}/equip');
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
    final user = context.watch<AuthProvider>().user;
    final coinBalance = user?.coinBalance ?? 0;
    final isVip = user?.isVip ?? false;
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4D3319), Color(0xFF2E1F14)]),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: AppColors.gold, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isVip ? 'VIP active' : 'Not VIP yet', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(
                          isVip ? 'Enjoy priority in Discover and exclusive frames' : '$_vipCostCoins coins — priority in Discover, exclusive frames',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (!isVip)
                    GestureDetector(
                      onTap: _buyingVip ? null : _buyVip,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(colors: [Color(0xFFE0B15E), Color(0xFFC98F3A)]),
                        ),
                        alignment: Alignment.center,
                        child: Text(_buyingVip ? '…' : 'Go VIP', style: const TextStyle(color: Color(0xFF33200A), fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _categoryPill(_Category.frames, 'Avatar frames'),
                const SizedBox(width: 8),
                _categoryPill(_Category.cars, 'Admission cars'),
              ],
            ),
          ),
          Expanded(child: _category == _Category.frames ? _frameGrid() : _carGrid()),
        ],
      ),
    );
  }

  Widget _categoryPill(_Category value, String label) {
    final selected = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.bg : AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _frameGrid() {
    if (_frames == null) return const Center(child: Spinner(size: 28));
    if (_frames!.isEmpty) return const Center(child: Text('No frames available yet.', style: TextStyle(color: AppColors.textFaint)));
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: _frames!.map((frame) {
        final busy = _busyId == frame.id;
        return GestureDetector(
          onTap: busy ? null : () => _handleFrameTap(frame),
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
    );
  }

  Widget _carGrid() {
    if (_cars == null) return const Center(child: Spinner(size: 28));
    if (_cars!.isEmpty) return const Center(child: Text('No admission cars available yet.', style: TextStyle(color: AppColors.textFaint)));
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: _cars!.map((car) {
        final busy = _busyId == car.id;
        return GestureDetector(
          onTap: busy ? null : () => _handleCarTap(car),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: car.equipped ? AppColors.primary : AppColors.border, width: car.equipped ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 44,
                  child: busy ? const Center(child: Spinner(size: 20)) : Image.network(car.imageUrl, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                Text(car.name, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  car.equipped
                      ? 'Equipped'
                      : (car.owned ? 'Tap to equip' : '🪙 ${car.coinCost}/${car.durationDays}day'),
                  style: TextStyle(color: car.equipped ? AppColors.primary : AppColors.textFaint, fontSize: 10, fontWeight: car.equipped ? FontWeight.w700 : FontWeight.normal),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
