import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../widgets/insync_clay.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/location_service.dart';
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
  bool _needsLocation = false;
  bool _turningOn = false;

  // Asks permission, turns sharing on, saves a position, then opens the map.
  Future<void> _turnOnLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    setState(() => _turningOn = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Turn on location on your phone first.')));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) return;
      if (permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(SnackBar(
            content: const Text('Allow location for Insync in your settings.'),
            action: SnackBarAction(
                label: 'Settings', onPressed: Geolocator.openAppSettings)));
        return;
      }
      await ApiClient.patch('/auth/me', body: {'locationSharingEnabled': true});
      final saved = await LocationService.requestPermissionAndPing();
      auth.refreshUser();
      if (!saved) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Couldn’t get your location. Try again outside.')));
        return;
      }
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _turningOn = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Where the map is looking, once moved; "Search this area" uses it.
  LatLng? _center;
  bool _moved = false;

  Future<void> _load({LatLng? area}) async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLocation = false;
      _moved = false;
    });
    try {
      final data = await ApiClient.get(area == null
          ? '/discover/map'
          : '/discover/map?lat=${area.latitude}&lng=${area.longitude}');
      if (!mounted) return;
      setState(() {
        _nearby = data as List;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _needsLocation = e.status == 400;
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
      appBar: AppBar(title: const InsyncPageTitle('Map Explore')),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            _needsLocation
                                ? 'See who’s nearby on the map. People who share their location can see you too, at about 1 km, never your exact spot. You can turn it off any time.'
                                : _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textFaint)),
                        const SizedBox(height: 12),
                        if (_needsLocation)
                          ElevatedButton(
                              onPressed: _turningOn ? null : _turnOnLocation,
                              child: Text(_turningOn
                                  ? 'Turning on…'
                                  : 'Turn on location'))
                        else
                          ElevatedButton(
                              onPressed: _load, child: const Text('Retry')),
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
        ? LatLng(asNum(nearby.first['latitude']).toDouble(),
            asNum(nearby.first['longitude']).toDouble())
        : const LatLng(
            20.5937, 78.9629); // India, as a reasonable fallback center

    return Stack(children: [
      FlutterMap(
        options: MapOptions(
            initialCenter: center,
            initialZoom: nearby.isNotEmpty ? 11 : 4,
            onPositionChanged: (camera, hasGesture) {
              if (!hasGesture) return;
              _center = camera.center;
              if (!_moved) setState(() => _moved = true);
            }),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.insync.app',
          ),
          MarkerLayer(
            markers: nearby.map((u) {
              final lat = asNum(u['latitude']).toDouble();
              final lng = asNum(u['longitude']).toDouble();
              return Marker(
                point: LatLng(lat, lng),
                width: 104,
                height: 82,
                child: GestureDetector(
                  onTap: () => _showProfileCard(u),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _genderColour(u['gender'] as String?) ??
                                AppColors.primary,
                            width: 3),
                        color: AppColors.surface,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: u['avatarUrl'] != null
                          ? AppImage(
                              source: u['avatarUrl'] as String?,
                              fit: BoxFit.cover)
                          : Center(
                              child: Text(_initial(u['name'] as String?),
                                  style: const TextStyle(
                                      color: AppColors.textDim))),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xE60B0912),
                          borderRadius: BorderRadius.circular(10)),
                      child: _nameTag(u, 11),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      Positioned(
        top: 10,
        right: 10,
        child: _sharingToggle(),
      ),
      if (_moved && _center != null)
        Positioned(
          top: 66,
          left: 0,
          right: 0,
          child: Center(
            child: FilledButton.icon(
              onPressed: () => _load(area: _center),
              icon: const InIcon(InIcons.search, size: 16, color: Colors.white),
              label: const Text('Search this area'),
            ),
          ),
        ),
    ]);
  }

  // Blue for male, pink for female; no icon for anything else or unset.
  Color? _genderColour(String? gender) => switch (gender?.toLowerCase()) {
        'male' => const Color(0xFF3D8BFF),
        'female' => const Color(0xFFFF5C9E),
        _ => null,
      };

  Widget _nameTag(dynamic u, double size) {
    final gender = (u['gender'] as String?)?.toLowerCase();
    final colour = _genderColour(gender);
    final age = u['age'];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Text(u['name'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.w600)),
      ),
      if (colour != null) ...[
        const SizedBox(width: 2),
        Icon(gender == 'male' ? Icons.male_rounded : Icons.female_rounded,
            semanticLabel: gender, size: size + 3, color: colour),
      ],
      if (age != null)
        Text(colour == null ? ' $age' : '$age',
            style: TextStyle(
                color: colour ?? Colors.white,
                fontSize: size,
                fontWeight: FontWeight.w700)),
    ]);
  }

  /// Off takes you off everyone's map; the map then asks before showing it.
  Widget _sharingToggle() {
    final on =
        context.watch<AuthProvider>().user?.locationSharingEnabled ?? false;
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
          color: const Color(0xE60B0912),
          borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('Share location',
            style: TextStyle(color: Colors.white, fontSize: 12.5)),
        Switch(
          value: on,
          onChanged: _turningOn
              ? null
              : (v) => v ? _turnOnLocation() : _turnOffLocation(),
        ),
      ]),
    );
  }

  Future<void> _turnOffLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    setState(() => _turningOn = true);
    try {
      await ApiClient.patch('/auth/me',
          body: {'locationSharingEnabled': false});
      await auth.refreshUser();
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _turningOn = false);
    }
  }

  String _initial(String? name) => (name != null && name.isNotEmpty)
      ? name.substring(0, 1).toUpperCase()
      : '?';

  void _showProfileCard(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
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
                  child: u['avatarUrl'] != null
                      ? AppImage(
                          source: u['avatarUrl'] as String?, fit: BoxFit.cover)
                      : Container(color: AppColors.surface3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _nameTag(u, 16),
                    Text('${u['distanceKm']} km away',
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          CreatorProfileScreen(userId: u['id'] as String)));
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
