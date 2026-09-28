import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firebase_tracking_service.dart';
import '../services/location_service.dart';
import '../services/mbtiles_tile_provider.dart';

// Rider's active delivery screen.
// When rider taps "Start Delivery":
//   - Phone GPS starts streaming to Firebase every 5–10 sec
//   - Customer sees the rider moving on their map
// When rider taps "Mark Delivered":
//   - Firebase entry updated to "delivered"
//   - Customer sees delivery confirmation
//   - Firebase entry cleaned up after 5 minutes

class RiderDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String deliveryAddress;
  final LatLng deliveryLatLng;

  const RiderDeliveryScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.deliveryAddress,
    required this.deliveryLatLng,
  });

  @override
  State<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends State<RiderDeliveryScreen> {
  bool _broadcasting = false;
  bool _delivered = false;

  Future<void> _startDelivery() async {
    final granted = await LocationService.requestPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required for delivery tracking')),
      );
      return;
    }
    setState(() => _broadcasting = true);
    // Runs in background — streams GPS to Firebase until marked delivered
    FirebaseTrackingService.startBroadcastingLocation(widget.orderId);
  }

  Future<void> _markDelivered() async {
    await FirebaseTrackingService.markDelivered(widget.orderId);
    setState(() => _delivered = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Delivery')),
      body: Column(children: [
        // ── Delivery info card ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deliver to ${widget.customerName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.deliveryAddress, style: const TextStyle(fontSize: 13))),
              ]),
            ],
          ),
        ),

        // ── Offline map showing destination ───────────────────────────
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: widget.deliveryLatLng,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(tileProvider: MapService.tileProvider),
              MarkerLayer(markers: [
                Marker(
                  point: widget.deliveryLatLng,
                  child: const Icon(Icons.home, color: Colors.red, size: 36),
                ),
              ]),
            ],
          ),
        ),

        // ── Action buttons ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: _delivered
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 8),
                    Text('Marked as Delivered',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                )
              : Column(children: [
                  if (!_broadcasting)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.electric_moped),
                        label: const Text('Start Delivery (Share Live Location)'),
                        onPressed: _startDelivery,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (_broadcasting) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.gps_fixed, color: Colors.green, size: 14),
                      const SizedBox(width: 6),
                      Text('Sharing live location…',
                          style: TextStyle(color: Colors.green[700], fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Mark as Delivered'),
                        onPressed: _markDelivered,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }
}
