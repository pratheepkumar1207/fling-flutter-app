import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';
import '../profile/creator_profile_screen.dart';

/// Map-based Discover — real GPS, opt-in only (see User.locationSharingEnabled,
/// GET /discover/map). Uses OpenStreetMap tiles via flutter_map, no API key
/// needed (unlike Google Maps, which needs a billing-enabled key this repo
/// doesn't have).
class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  List<dynamic>? _nearby;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.get('/discover/map');
      if (!mounted) return;
      setState(() {
        _nearby = data as List;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load nearby profiles.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Map Explore')),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildMap(),
    );
  }

  Widget _buildMap() {
    final nearby = _nearby ?? [];
    final center = nearby.isNotEmpty
        ? LatLng((nearby.first['latitude'] as num).toDouble(), (nearby.first['longitude'] as num).toDouble())
        : const LatLng(20.5937, 78.9629); // India, as a reasonable fallback center

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: nearby.isNotEmpty ? 11 : 4),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.insync.app',
        ),
        MarkerLayer(
          markers: nearby.map((u) {
            final lat = (u['latitude'] as num).toDouble();
            final lng = (u['longitude'] as num).toDouble();
            return Marker(
              point: LatLng(lat, lng),
              width: 46,
              height: 46,
              child: GestureDetector(
                onTap: () => _showProfileCard(u),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    color: AppColors.surface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: u['avatarUrl'] != null
                      ? AppImage(source: u['avatarUrl'] as String?, fit: BoxFit.cover)
                      : Center(child: Text(_initial(u['name'] as String?), style: const TextStyle(color: AppColors.textDim))),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _initial(String? name) => (name != null && name.isNotEmpty) ? name.substring(0, 1).toUpperCase() : '?';

  void _showProfileCard(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: u['avatarUrl'] != null ? AppImage(source: u['avatarUrl'] as String?, fit: BoxFit.cover) : Container(color: AppColors.surface3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${u['distanceKm']} km away', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: u['id'] as String)));
                },
                child: const Text('View profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
