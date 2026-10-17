import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});
  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFD97706);

  late TabController _tabController;
  Timer? _timer;

  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _history = [];
  bool _loadingActive = true;
  bool _loadingHistory = true;
  String _riderName = '';
  String _restaurantName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrefs();
    _refreshActive();
    _refreshHistory();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshActive();
      _maybeSendLocation();
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _riderName = prefs.getString('rider_name') ?? '';
        _restaurantName = prefs.getString('rider_restaurant_name') ?? '';
      });
    }
  }

  Future<void> _refreshActive() async {
    try {
      final orders = await ApiService.riderGetActiveOrders();
      if (mounted) setState(() { _activeOrders = orders; _loadingActive = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _refreshHistory() async {
    try {
      final orders = await ApiService.riderGetHistory();
      if (mounted) setState(() { _history = orders; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _maybeSendLocation() async {
    if (_activeOrders.isEmpty) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      await ApiService.riderSendLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rider_token');
    await prefs.remove('rider_id');
    await prefs.remove('rider_name');
    await prefs.remove('rider_restaurant_id');
    await prefs.remove('rider_restaurant_name');
    if (mounted) Navigator.pushReplacementNamed(context, '/rider/login');
  }

  Future<void> _confirmDelivery(Map<String, dynamic> order) async {
    final pinCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? pinError;
          bool confirming = false;

          return AlertDialog(
            title: const Text('Enter Delivery PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ask the customer for their 6-digit delivery PIN to confirm delivery.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                    errorText: pinError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              StatefulBuilder(
                builder: (ctx2, setBtn) => FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: confirming
                      ? null
                      : () async {
                          final pin = pinCtrl.text.trim();
                          if (pin.length != 6) {
                            setDialogState(() => pinError = 'Enter 6-digit PIN');
                            return;
                          }
                          setBtn(() => confirming = true);
                          try {
                            await ApiService.riderConfirmDelivery(
                                order['id'] as String, pin);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _refreshActive();
                            _refreshHistory();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Delivery confirmed!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(
                                () => pinError = e.toString());
                            setBtn(() => confirming = false);
                          }
                        },
                  child: confirming
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Confirm Delivery'),
                ),
              ),
            ],
          );
        },
      ),
    );
    pinCtrl.dispose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BossBite Rider',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_restaurantName.isNotEmpty)
              Text(_restaurantName,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_riderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(_riderName,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile',
            onPressed: () => Navigator.pushNamed(context, '/rider/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ready to Pick Up'),
            Tab(text: 'My Trips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_loadingActive) {
      return const Center(child: CircularProgressIndicator(color: _amber));
    }
    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 64, color: Colors.black12),
            const SizedBox(height: 12),
            const Text('No orders assigned yet',
                style: TextStyle(color: Colors.black45, fontSize: 15)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refreshActive,
              child: const Text('Refresh', style: TextStyle(color: _amber)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _amber,
      onRefresh: _refreshActive,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _activeOrders.length,
        itemBuilder: (_, i) => _buildOrderCard(_activeOrders[i], active: true),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: _amber));
    }
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.black12),
            SizedBox(height: 12),
            Text('No completed trips yet',
                style: TextStyle(color: Colors.black45, fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _amber,
      onRefresh: () async { await _refreshHistory(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (_, i) => _buildOrderCard(_history[i], active: false),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {required bool active}) {
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final address = order['delivery_address'] as String? ?? '';
    final customerName = order['customer_name'] as String? ?? '';
    final paid = (order['customer_paid'] as num?)?.toStringAsFixed(0) ?? '0';
    final orderId = (order['id'] as String).substring(0, 8).toUpperCase();
    final deliveryLat = (order['delivery_lat'] as num?)?.toDouble();
    final deliveryLng = (order['delivery_lng'] as num?)?.toDouble();
    final hasMap = active && deliveryLat != null && deliveryLng != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#$orderId',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    active ? 'PICK UP' : 'DELIVERED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: active
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(customerName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(address,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${item['qty']}× ${item['name']}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                )),
            if (items.length > 3)
              Text('+${items.length - 3} more items',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black38)),
            if (hasMap) ...[
              const SizedBox(height: 10),
              Row(children: const [
                Icon(Icons.location_on, size: 14, color: _amber),
                SizedBox(width: 4),
                Text('Drop Location',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _amber)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 160,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(deliveryLat!, deliveryLng!),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.bossbite.gsr_app',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(deliveryLat, deliveryLng),
                          width: 48,
                          height: 56,
                          child: const Column(children: [
                            Icon(Icons.home_rounded, color: Colors.red, size: 32),
                            Icon(Icons.location_on, color: Colors.red, size: 14),
                          ]),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹$paid',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _amber)),
                if (active)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark Delivered'),
                    onPressed: () => _confirmDelivery(order),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
