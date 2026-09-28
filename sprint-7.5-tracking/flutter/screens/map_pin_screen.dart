import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/mbtiles_tile_provider.dart';

// Customer pins their exact delivery location on the pre-bundled offline map.
// Flow:
//   1. App requests GPS permission
//   2. Map centres on customer's current GPS position
//   3. Customer drags the pin to their exact door / gate
//   4. Address is reverse-geocoded and shown below the map
//   5. Customer taps "Confirm Location" → lat/lng + address saved to order

class MapPinScreen extends StatefulWidget {
  const MapPinScreen({super.key});

  @override
  State<MapPinScreen> createState() => _MapPinScreenState();
}

class _MapPinScreenState extends State<MapPinScreen> {
  final _mapController = MapController();
  LatLng? _pinPosition;
  String _addressText = 'Detecting your location…';
  bool _loading = true;

  // CSN city centre as fallback if GPS unavailable
  static const _defaultCenter = LatLng(19.8762, 75.3433);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    final latlng = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _defaultCenter;

    setState(() {
      _pinPosition = latlng;
      _loading = false;
    });
    _mapController.move(latlng, 16.0);
    _reverseGeocode(latlng);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    final address = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() => _addressText = address);
  }

  // Called whenever the map finishes moving — pin stays centred
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    final centre = camera.center;
    setState(() {
      _pinPosition = centre;
      _addressText = 'Finding address…';
    });
    _reverseGeocode(centre);
  }

  void _confirmLocation() {
    if (_pinPosition == null) return;
    Navigator.pop(context, {
      'lat': _pinPosition!.latitude,
      'lng': _pinPosition!.longitude,
      'address': _addressText,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pin Your Delivery Location')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              // ── Offline map ────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pinPosition ?? _defaultCenter,
                  initialZoom: 16.0,
                  minZoom: 10,
                  maxZoom: 18,
                  onPositionChanged: _onMapPositionChanged,
                ),
                children: [
                  TileLayer(tileProvider: MapService.tileProvider),
                ],
              ),

              // ── Fixed centre pin ───────────────────────────────────────
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin, color: Colors.red, size: 48),
                    SizedBox(height: 40), // offset so tip of pin = map centre
                  ],
                ),
              ),

              // ── Address + confirm button ───────────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Delivery Address',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(_addressText,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Drag the map to adjust the pin',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Confirm Location'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
    );
  }
}
