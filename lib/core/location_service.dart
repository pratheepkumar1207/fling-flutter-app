import 'package:geolocator/geolocator.dart';
import 'api_client.dart';

/// Requests device location permission and pings the backend with the
/// current position — only called when the user has turned on
/// locationSharingEnabled (see profile_screen.dart's edit sheet and
/// POST /auth/location, which silently no-ops server-side for anyone who
/// hasn't). Every call here is opt-in-triggered, never automatic on app
/// launch for a user who hasn't turned this on.
class LocationService {
  LocationService._();

  static Future<bool> requestPermissionAndPing() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return false;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      final position = await Geolocator.getCurrentPosition();
      await ApiClient.post('/auth/location', body: {'latitude': position.latitude, 'longitude': position.longitude});
      return true;
    } catch (_) {
      return false;
    }
  }
}
