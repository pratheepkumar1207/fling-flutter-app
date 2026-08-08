import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

const _kRotateMs = 5000;

/// Auto-rotating promo banner strip — Dart port of BannerCarousel.jsx.
/// Renders nothing when there are no banners (pure decoration, not
/// content); a single banner renders statically; 2+ crossfade on a timer
/// with dot indicators.
class BannerCarousel extends StatefulWidget {
  final String placement;
  const BannerCarousel({super.key, required this.placement});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  List<Map<String, dynamic>> _banners = [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/banners?placement=${widget.placement}');
      if (!mounted) return;
      setState(() => _banners = ((data as List?) ?? []).cast<Map<String, dynamic>>());
      if (_banners.length > 1) {
        _timer = Timer.periodic(const Duration(milliseconds: _kRotateMs), (_) {
          if (mounted) setState(() => _index = (_index + 1) % _banners.length);
        });
      }
    } catch (_) {
      // Pure decoration — silently skip on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    if (_banners.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 21 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
            child: AppImage(source: _banners[0]['imageUrl'] as String?, fit: BoxFit.cover),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 21 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < _banners.length; i++)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 700),
                  opacity: i == _index ? 1 : 0,
                  child: AppImage(source: _banners[i]['imageUrl'] as String?, fit: BoxFit.cover),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _banners.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: i == _index ? 1 : 0.4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
