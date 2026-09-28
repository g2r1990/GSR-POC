import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firebase_tracking_service.dart';
import '../services/mbtiles_tile_provider.dart';

// Customer's live order tracking screen.
// Shows three pins on the offline map:
//   📍 Restaurant location (fixed, orange)
//   🛵 Rider location (live, blue — updates every 5–10 sec from Firebase)
//   🏠 Customer delivery address (fixed, red)
//
// Data flow:
//   Rider app → Firebase Realtime DB → this stream → map refreshes

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final LatLng restaurantLatLng;
  final LatLng deliveryLatLng;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.restaurantLatLng,
    required this.deliveryLatLng,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _mapController = MapController();
  RiderLocation? _rider;
  bool _delivered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Your Order')),
      body: StreamBuilder<RiderLocation?>(
        stream: FirebaseTrackingService.watchRiderLocation(widget.orderId),
        builder: (context, snapshot) {
          final rider = snapshot.data;
          if (rider != null && rider != _rider) {
            _rider = rider;
            if (rider.isDelivered) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _delivered = true);
              });
            } else {
              // Auto-pan map to keep rider in view
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapController.move(LatLng(rider.lat, rider.lng), 15.0);
              });
            }
          }

          return Column(children: [
            // ── Status banner ──────────────────────────────────────────
            _StatusBanner(delivered: _delivered, hasRider: rider != null),

            // ── Map ────────────────────────────────────────────────────
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.restaurantLatLng,
                  initialZoom: 14.0,
                ),
                children: [
                  // Pre-bundled offline map tiles — no internet needed
                  TileLayer(tileProvider: MapService.tileProvider),

                  MarkerLayer(markers: [
                    // Restaurant pin (orange)
                    _buildMarker(
                      widget.restaurantLatLng,
                      Icons.storefront,
                      Colors.orange,
                      'Restaurant',
                    ),
                    // Customer pin (red)
                    _buildMarker(
                      widget.deliveryLatLng,
                      Icons.home,
                      Colors.red,
                      'Your door',
                    ),
                    // Rider pin (blue, only when out for delivery)
                    if (rider != null && !rider.isDelivered)
                      _buildMarker(
                        LatLng(rider.lat, rider.lng),
                        Icons.electric_moped,
                        Colors.blue,
                        'Rider',
                      ),
                  ]),

                  // Dotted route line: restaurant → rider → customer
                  if (rider != null && !rider.isDelivered)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [
                          widget.restaurantLatLng,
                          LatLng(rider.lat, rider.lng),
                          widget.deliveryLatLng,
                        ],
                        color: Colors.blue.withOpacity(0.4),
                        strokeWidth: 3,
                        isDotted: true,
                      ),
                    ]),
                ],
              ),
            ),

            // ── Last updated footer ────────────────────────────────────
            if (rider != null && !rider.isDelivered)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Location updated ${_timeAgo(rider.updatedAt)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Marker _buildMarker(LatLng pos, IconData icon, Color color, String label) {
    return Marker(
      point: pos,
      width: 60, height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          Icon(icon, color: color, size: 28),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).inSeconds;
    if (diff < 10) return 'just now';
    if (diff < 60) return '${diff}s ago';
    return '${diff ~/ 60}m ago';
  }
}

class _StatusBanner extends StatelessWidget {
  final bool delivered;
  final bool hasRider;

  const _StatusBanner({required this.delivered, required this.hasRider});

  @override
  Widget build(BuildContext context) {
    if (delivered) {
      return _banner(Colors.green, Icons.check_circle, 'Delivered! Enjoy your meal 🍽️');
    }
    if (hasRider) {
      return _banner(Colors.blue, Icons.electric_moped, 'Rider is on the way…');
    }
    return _banner(Colors.orange, Icons.restaurant, 'Food is being prepared…');
  }

  Widget _banner(Color color, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: color.withOpacity(0.12),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
