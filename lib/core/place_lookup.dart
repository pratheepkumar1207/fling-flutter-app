import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Why a place couldn't be found, as a line to show the person.
class PlaceLookupFailure implements Exception {
  final String message;
  const PlaceLookupFailure(this.message);
}

/// The name of where the phone is, like "Anna Nagar, Chennai". Reads GPS once;
/// only the name is used, never the coordinates, and nothing is saved here.
Future<String> currentPlaceName() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const PlaceLookupFailure('Turn on location on your phone first.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const PlaceLookupFailure('Allow location to use this.');
  }
  try {
    final at = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15)));
    final places =
        await Geocoding().placemarkFromCoordinates(at.latitude, at.longitude);
    final place = places.first;
    final parts = <String>[];
    for (final part in [
      place.subLocality,
      place.locality,
      place.administrativeArea,
    ]) {
      if (part != null && part.trim().isNotEmpty && !parts.contains(part)) {
        parts.add(part.trim());
      }
    }
    if (parts.isEmpty) throw StateError('unnamed');
    return parts.take(2).join(', ');
  } catch (_) {
    throw const PlaceLookupFailure(
        'Couldn’t find your place. You can type it instead.');
  }
}
