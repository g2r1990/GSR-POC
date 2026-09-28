import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Check and request GPS permission, returns true if granted
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // Get customer's current GPS position (one-shot)
  static Future<Position?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Stream rider's GPS position every 5 seconds while delivering
  // Uses phone hardware — no API, no cost
  static Stream<Position> riderPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update only if rider moved 10 metres
        timeLimit: Duration(seconds: 5),
      ),
    );
  }

  // Convert lat/lng to a readable address (uses device geocoder — free)
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '$lat, $lng';
      final p = placemarks.first;
      final parts = [
        p.subLocality,      // area / locality
        p.locality,         // city
        p.postalCode,
      ].where((s) => s != null && s.isNotEmpty).toList();
      return parts.join(', ');
    } catch (_) {
      return '$lat, $lng';
    }
  }
}
