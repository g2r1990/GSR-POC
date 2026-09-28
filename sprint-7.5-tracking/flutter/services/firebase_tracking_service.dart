import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

// Firebase Realtime DB structure:
// active_deliveries/
//   {orderId}/
//     lat: 19.8762
//     lng: 75.3433
//     updated_at: 1727000000   ← epoch seconds
//     status: "out_for_delivery" | "delivered"

class FirebaseTrackingService {
  static final _db = FirebaseDatabase.instance;

  // ── RIDER SIDE ──────────────────────────────────────────────

  // Called by rider's app — starts sending GPS to Firebase every 5 sec
  static Future<void> startBroadcastingLocation(String orderId) async {
    final ref = _db.ref('active_deliveries/$orderId');
    await LocationService.riderPositionStream().forEach((Position pos) async {
      await ref.update({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'status': 'out_for_delivery',
      });
    });
  }

  // Called when rider taps "Delivered"
  static Future<void> markDelivered(String orderId) async {
    final ref = _db.ref('active_deliveries/$orderId');
    await ref.update({'status': 'delivered'});
    // Clean up after 5 minutes
    await Future.delayed(const Duration(minutes: 5));
    await ref.remove();
  }

  // ── CUSTOMER SIDE ────────────────────────────────────────────

  // Live stream of rider location — customer subscribes to this
  // Returns null if no active delivery found
  static Stream<RiderLocation?> watchRiderLocation(String orderId) {
    return _db
        .ref('active_deliveries/$orderId')
        .onValue
        .map((event) {
          final data = event.snapshot.value as Map?;
          if (data == null) return null;
          return RiderLocation(
            lat: (data['lat'] as num).toDouble(),
            lng: (data['lng'] as num).toDouble(),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
                (data['updated_at'] as int) * 1000),
            status: data['status'] as String,
          );
        });
  }
}

class RiderLocation {
  final double lat;
  final double lng;
  final DateTime updatedAt;
  final String status;

  const RiderLocation({
    required this.lat,
    required this.lng,
    required this.updatedAt,
    required this.status,
  });

  bool get isDelivered => status == 'delivered';
}
