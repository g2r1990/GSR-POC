import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'order_status_screen.dart';
import 'restaurant_list_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _amber = Color(0xFFD97706);

  final _pincodeCtrl = TextEditingController();
  bool _searching = false;
  bool _detecting = false;
  String? _error;
  String? _detectedPincode;
  String? _activeOrderId;
  String? _activeOrderShortId;

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
    _autoDetect();
  }

  Future<void> _loadActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _activeOrderId = prefs.getString('active_order_id');
        _activeOrderShortId = prefs.getString('active_order_short_id');
      });
    }
  }

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoDetect() async {
    setState(() { _detecting = true; _error = null; });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _detecting = false;
            _error = 'Location permission denied. Enter pincode manually.';
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final pincode =
          await ApiService.getPincodeFromCoords(pos.latitude, pos.longitude);

      if (mounted) {
        if (pincode != null && pincode.length == 6) {
          setState(() {
            _detectedPincode = pincode;
            _pincodeCtrl.text = pincode;
            _detecting = false;
          });
          await _search(auto: true);
        } else {
          setState(() {
            _detecting = false;
            _error = 'Could not detect pincode. Enter manually.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detecting = false;
          _error = 'Location unavailable. Enter pincode manually.';
        });
      }
    }
  }

  Future<void> _search({bool auto = false}) async {
    final pincode = _pincodeCtrl.text.trim();
    if (pincode.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit pincode.');
      return;
    }
    setState(() { _searching = true; _error = null; });
    try {
      final restaurants = await ApiService.searchRestaurants(pincode);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantListScreen(
            pincode: pincode,
            restaurants: restaurants,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect. Check your network.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('BossBite'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () => Navigator.pushNamed(context, '/customer/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active order banner — shown when user has an order in progress
              if (_activeOrderId != null) ...[
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OrderStatusScreen(
                        orderId: _activeOrderId!,
                        shortId: _activeOrderShortId ?? '',
                        total: 0,
                      ),
                    ));
                    _loadActiveOrder(); // refresh — order may have completed
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _amber, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delivery_dining, color: _amber, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Order in Progress',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E))),
                              Text(
                                'Tap to track order #${_activeOrderShortId ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: _amber),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Icon(Icons.restaurant_menu, size: 72, color: _amber),
              const SizedBox(height: 16),
              const Text(
                'Find Restaurants Near You',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),

              // Location status message
              if (_detecting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _amber)),
                      SizedBox(width: 8),
                      Text('Detecting your location…',
                          style: TextStyle(fontSize: 13, color: _amber)),
                    ],
                  ),
                )
              else if (_detectedPincode != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on,
                          size: 15, color: Color(0xFF166534)),
                      const SizedBox(width: 4),
                      Text(
                        'Detected: $_detectedPincode',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF166534)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _autoDetect,
                        child: const Text('Re-detect',
                            style: TextStyle(
                                fontSize: 12,
                                color: _amber,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Enter your pincode to discover local restaurants',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF78716C)),
                ),

              const SizedBox(height: 28),

              // Pincode field
              TextField(
                controller: _pincodeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Color(0xFF1C1917),
                ),
                decoration: InputDecoration(
                  hintText: '431005',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD6D3D1),
                    letterSpacing: 8,
                    fontWeight: FontWeight.normal,
                    fontSize: 28,
                  ),
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFFDE68A), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _amber, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _detectedPincode != null
                      ? const Icon(Icons.location_on,
                          color: Color(0xFF166534), size: 20)
                      : null,
                ),
                onSubmitted: (_) => _search(),
              ),

              const SizedBox(height: 12),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 13),
                  ),
                ),

              const SizedBox(height: 12),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_searching || _detecting) ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _amber.withAlpha(128),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: (_searching || _detecting)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Find Restaurants',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              // Re-detect button when location was denied
              if (!_detecting && _detectedPincode == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _autoDetect,
                    icon: const Icon(Icons.my_location,
                        size: 16, color: _amber),
                    label: const Text('Use my location',
                        style: TextStyle(color: _amber, fontSize: 13)),
                  ),
                ),

              const SizedBox(height: 36),
              const _TipCard(
                icon: Icons.location_on,
                text:
                    'BossBite auto-detects your location. You can also enter pincode manually.',
              ),
              const SizedBox(height: 12),
              const _TipCard(
                icon: Icons.visibility,
                text:
                    'Browse the menu before ordering — no login required.',
              ),
              const SizedBox(height: 12),
              const _TipCard(
                icon: Icons.payments_outlined,
                text:
                    'Pay by cash or UPI (PhonePe / Google Pay) on delivery.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF44403C)),
            ),
          ),
        ],
      ),
    );
  }
}
