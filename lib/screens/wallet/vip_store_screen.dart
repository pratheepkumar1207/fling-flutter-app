import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
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
  // Plans from GET /wallet/vip-plans: [{months, coins}].
  List<Map<String, dynamic>> _plans = const [
    {'months': 1, 'coins': 500},
    {'months': 3, 'coins': 1250},
  ];
  int _months = 1;

  /// What VIP really unlocks today.
  static const _perks = [
    (InIcons.heart, 'See who likes you'),
    (InIcons.chat, 'Message anyone without matching'),
    (InIcons.undo, 'Free rewinds in Discover'),
    (InIcons.live, 'See which room anyone is in'),
    (InIcons.music, 'More than one playlist'),
    (InIcons.crown, 'VIP badge on your profile'),
  ];

  Future<void> _buyVip() async {
    setState(() => _buyingVip = true);
    try {
      await ApiClient.post('/wallet/buy-vip', body: {'months': _months});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('VIP activated!')));
      }
      if (mounted) await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
      final plans = await ApiClient.get('/wallet/vip-plans') as List;
      if (mounted && plans.isNotEmpty) {
        setState(() =>
            _plans = plans.cast<Map>().map(Map<String, dynamic>.from).toList());
      }
    } catch (_) {}
    try {
      final data = await ApiClient.get('/store/avatar-frames');
      if (!mounted) return;
      setState(() => _frames = (data as List)
          .map((e) => AvatarFrame.fromJson(e as Map<String, dynamic>))
          .toList());
      await AvatarFrameCache.refresh();
    } catch (_) {
      if (mounted) setState(() => _frames = []);
    }
    try {
      final data = await ApiClient.get('/store/admission-cars');
      if (!mounted) return;
      setState(() => _cars = (data as List)
          .map((e) => AdmissionCar.fromJson(e as Map<String, dynamic>))
          .toList());
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
        title: const InsyncPageTitle('VIP Store'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Text('🪙 ${coinBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w600))),
          ),
        ],
      ),
      body: Column(
        children: [
          // Capped and scrollable so the store below always has room.
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4D3319), Color(0xFF2E1F14)]),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const InIcon(InIcons.crown,
                            filled: true, color: AppColors.gold, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              isVip
                                  ? 'VIP active${user?.vipExpiresAt != null ? ' until ${user!.vipExpiresAt!.toLocal().day}/${user.vipExpiresAt!.toLocal().month}' : ''}'
                                  : 'Go VIP',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      for (final (icon, label) in _perks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            InIcon(icon, size: 16, color: AppColors.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(label,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      Row(children: [
                        for (final p in _plans)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Semantics(
                                selected: _months == p['months'],
                                button: true,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(
                                      () => _months = p['months'] as int),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: _months == p['months']
                                              ? AppColors.gold
                                              : Colors.white24,
                                          width:
                                              _months == p['months'] ? 2 : 1),
                                    ),
                                    child: Column(children: [
                                      Text(
                                          p['months'] == 1
                                              ? '1 month'
                                              : '${p['months']} months',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                      Text('🪙 ${p['coins']}',
                                          style: const TextStyle(
                                              color: AppColors.gold,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _buyingVip ? null : _buyVip,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF33200A),
                            minimumSize: const Size.fromHeight(46)),
                        child: Text(
                            _buyingVip
                                ? '…'
                                : isVip
                                    ? 'Extend VIP'
                                    : 'Get VIP',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _categoryPill(_Category.frames, 'Avatar frames'),
                _categoryPill(_Category.cars, 'Admission cars'),
              ],
            ),
          ),
          Expanded(
              child: _category == _Category.frames ? _frameGrid() : _carGrid()),
        ],
      ),
    );
  }

  // Deterministic per-frame ring gradient (no color field on the catalog),
  // matching VipStoreDark.dc.html's varied gold/violet/mint/blue rings.
  static const _ringGradients = [
    [Color(0xFFE8C56B), Color(0xFFC28A38)],
    [Color(0xFFF4595E), Color(0xFFB051C5)],
    [Color(0xFF9DE8B8), Color(0xFF3F9E6E)],
    [Color(0xFF9DC5E8), Color(0xFF5A8FC1)],
    [Color(0xFFE89DC5), Color(0xFFC13750)],
  ];
  List<Color> _frameRingColors(AvatarFrame frame) =>
      _ringGradients[frame.id.hashCode.abs() % _ringGradients.length];

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
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.bg : AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _frameGrid() {
    if (_frames == null) return const Center(child: Spinner(size: 28));
    if (_frames!.isEmpty) {
      return const Center(
          child: Text('No frames available yet.',
              style: TextStyle(color: AppColors.textFaint)));
    }
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: frame.equipped
                  ? AppColors.accent.withValues(alpha: 0.16)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: frame.equipped ? AppColors.accent : AppColors.border,
                  width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular gradient ring around the real frame preview,
                // matching VipStoreDark.dc.html's item icon exactly.
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _frameRingColors(frame)),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.surface2),
                    alignment: Alignment.center,
                    child: busy
                        ? const Spinner(size: 18)
                        : ClipOval(
                            child: Image.network(frame.imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink())),
                  ),
                ),
                const SizedBox(height: 8),
                Text(frame.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
                Text(
                  frame.equipped
                      ? 'Equipped'
                      : (frame.owned
                          ? 'Tap to equip'
                          : '${frame.coinCost} coins'),
                  style: TextStyle(
                      color:
                          frame.equipped ? AppColors.success : AppColors.gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700),
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
    if (_cars!.isEmpty) {
      return const Center(
          child: Text('No admission cars available yet.',
              style: TextStyle(color: AppColors.textFaint)));
    }
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: car.equipped
                  ? AppColors.accent.withValues(alpha: 0.16)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: car.equipped ? AppColors.accent : AppColors.border,
                  width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 44,
                  child: busy
                      ? const Center(child: Spinner(size: 20))
                      : Image.network(car.imageUrl, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                Text(car.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
                Text(
                  car.equipped
                      ? 'Equipped'
                      : (car.owned
                          ? 'Tap to equip'
                          : '${car.coinCost} coins / ${car.durationDays}d'),
                  style: TextStyle(
                      color: car.equipped ? AppColors.success : AppColors.gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
