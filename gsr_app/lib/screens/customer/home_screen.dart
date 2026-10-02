import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'order_status_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'restaurant_list_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _amber = Color(0xFFD97706);

  // Profile
  String _name = '';
  String _phone = '';
  String _pincode = '';
  String _district = '';

  // Active order
  String? _activeOrderId;
  String? _activeOrderShortId;

  // Recent order
  Map<String, dynamic>? _recentOrder;

  // Search state
  bool _searching = false;
  String? _searchError;
  bool _detectingLocation = false;

  // Pincode override (editable inline)
  late TextEditingController _pincodeCtrl;
  bool _editingPincode = false;

  @override
  void initState() {
    super.initState();
    _pincodeCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('customer_name') ?? '';
      _phone = prefs.getString('customer_phone') ?? '';
      _pincode = prefs.getString('customer_pincode') ?? '';
      _district = prefs.getString('customer_district') ?? '';
      _activeOrderId = prefs.getString('active_order_id');
      _activeOrderShortId = prefs.getString('active_order_short_id');
      _pincodeCtrl.text = _pincode;
    });
    _loadRecentOrder();
  }

  Future<void> _loadRecentOrder() async {
    if (_phone.isEmpty) return;
    try {
      final orders = await ApiService.customerOrderHistory(_phone);
      if (mounted && orders.isNotEmpty) {
        setState(() => _recentOrder = orders.first);
      }
    } catch (_) {}
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

  Future<void> _detectLocation() async {
    setState(() { _detectingLocation = true; _searchError = null; });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detectingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );
      final loc =
          await ApiService.getLocationFromCoords(pos.latitude, pos.longitude);
      if (mounted && loc['pincode'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_pincode', loc['pincode']!);
        if (loc['district'] != null) {
          await prefs.setString('customer_district', loc['district']!);
        }
        setState(() {
          _pincode = loc['pincode']!;
          _district = loc['district'] ?? _district;
          _pincodeCtrl.text = _pincode;
          _detectingLocation = false;
        });
      } else {
        if (mounted) setState(() => _detectingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _findRestaurants() async {
    final pincode = _pincodeCtrl.text.trim();
    if (pincode.length != 6) {
      setState(() => _searchError = 'Enter a valid 6-digit pincode.');
      return;
    }
    setState(() { _searching = true; _searchError = null; _editingPincode = false; });
    try {
      final restaurants = await ApiService.searchRestaurants(pincode);
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_pincode', pincode);
      setState(() => _pincode = pincode);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RestaurantListScreen(pincode: pincode, restaurants: restaurants),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Could not connect. Check your network.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'B';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.location_on, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _district.isNotEmpty ? _district : 'BossBite',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_pincode.isNotEmpty)
                    Text(_pincode,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My Orders',
            onPressed: () async {
              await Navigator.pushNamed(context, '/customer/orders');
              _loadActiveOrder();
              _loadRecentOrder();
            },
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, '/customer/profile');
              _loadAll();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  initial,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _amber),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _amber,
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero / greeting ──────────────────────────────────────
              Container(
                width: double.infinity,
                color: _amber,
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_name.isNotEmpty ? _name.split(' ').first : 'there'}! 👋',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What would you like to eat today?',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // ── Find restaurants card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.storefront_outlined,
                            color: _amber, size: 20),
                        const SizedBox(width: 8),
                        const Text('Find Restaurants',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1917))),
                        const Spacer(),
                        // Location detect icon
                        _detectingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _amber))
                            : IconButton(
                                icon: const Icon(Icons.my_location,
                                    size: 20, color: _amber),
                                tooltip: 'Detect my location',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _detectLocation,
                              ),
                      ]),
                      const SizedBox(height: 12),

                      // Pincode row — display or edit mode
                      _editingPincode
                          ? TextField(
                              controller: _pincodeCtrl,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6,
                                  color: Color(0xFF1C1917)),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '431005',
                                hintStyle: const TextStyle(
                                    color: Color(0xFFD6D3D1),
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 22),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFFDE68A), width: 2)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: _amber, width: 2)),
                                filled: true,
                                fillColor: const Color(0xFFFFFBEB),
                              ),
                              onSubmitted: (_) => _findRestaurants(),
                            )
                          : GestureDetector(
                              onTap: () =>
                                  setState(() => _editingPincode = true),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                      width: 1.5),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.pin_drop_outlined,
                                      size: 18, color: _amber),
                                  const SizedBox(width: 10),
                                  Text(
                                    _pincode.isNotEmpty
                                        ? _pincode
                                        : 'Tap to enter pincode',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing:
                                            _pincode.isNotEmpty ? 4 : 0,
                                        color: _pincode.isNotEmpty
                                            ? const Color(0xFF1C1917)
                                            : const Color(0xFFA8A29E)),
                                  ),
                                  const Spacer(),
                                  const Text('Change',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _amber,
                                          decoration:
                                              TextDecoration.underline)),
                                ]),
                              ),
                            ),

                      if (_searchError != null) ...[
                        const SizedBox(height: 8),
                        Text(_searchError!,
                            style: const TextStyle(
                                color: Color(0xFFDC2626), fontSize: 12)),
                      ],

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _searching ? null : _findRestaurants,
                          icon: _searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search, size: 20),
                          label: Text(
                              _searching ? 'Searching…' : 'Find Restaurants',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amber,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Active order banner ──────────────────────────────────
              if (_activeOrderId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OrderStatusScreen(
                          orderId: _activeOrderId!,
                          shortId: _activeOrderShortId ?? '',
                          total: 0,
                        ),
                      ));
                      _loadActiveOrder();
                      _loadRecentOrder();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _amber, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(children: [
                        const Icon(Icons.delivery_dining,
                            color: _amber, size: 28),
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
                                  'Tap to track  #${_activeOrderShortId ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB45309))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: _amber),
                      ]),
                    ),
                  ),
                ),

              // ── Recent order ────────────────────────────────────────
              if (_recentOrder != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Recent Order',
                        action: 'View All',
                        onAction: () async {
                          await Navigator.pushNamed(context, '/customer/orders');
                          _loadActiveOrder();
                          _loadRecentOrder();
                        },
                      ),
                      const SizedBox(height: 10),
                      _RecentOrderCard(
                        order: _recentOrder!,
                        onTrack: (id, shortId, total) async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => OrderStatusScreen(
                              orderId: id,
                              shortId: shortId,
                              total: total,
                            ),
                          ));
                          _loadActiveOrder();
                          _loadRecentOrder();
                        },
                      ),
                    ],
                  ),
                ),

              // ── Order history shortcut ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SectionHeader(
                  title: 'Order History',
                  action: 'See All',
                  onAction: () async {
                    await Navigator.pushNamed(context, '/customer/orders');
                    _loadActiveOrder();
                    _loadRecentOrder();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/customer/orders');
                    _loadActiveOrder();
                    _loadRecentOrder();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_outlined,
                            color: _amber, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Orders',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1917))),
                            Text('View all your past & active orders',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78716C))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFFD6D3D1)),
                    ]),
                  ),
                ),
              ),

              // ── Profile shortcut ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/customer/profile');
                    _loadAll();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_outline,
                            color: _amber, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Profile',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1917))),
                            Text(
                                _name.isNotEmpty
                                    ? '$_name  •  +91 $_phone'
                                    : 'View and edit your profile',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78716C)),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFFD6D3D1)),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;
  const _SectionHeader(
      {required this.title,
      required this.action,
      required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1917))),
        const Spacer(),
        GestureDetector(
          onTap: onAction,
          child: Text(action,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final void Function(String orderId, String shortId, double total) onTrack;

  const _RecentOrderCard({required this.order, required this.onTrack});

  static const _statusLabel = {
    'placed': 'Placed',
    'accepted': 'Accepted',
    'ready': 'Ready',
    'out_for_delivery': 'Out for Delivery',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };
  static const _statusColor = {
    'placed': Color(0xFFF59E0B),
    'accepted': Color(0xFF2563EB),
    'ready': Color(0xFF7C3AED),
    'out_for_delivery': Color(0xFF0891B2),
    'delivered': Color(0xFF166534),
    'cancelled': Color(0xFFDC2626),
  };
  static const _statusBg = {
    'placed': Color(0xFFFEF3C7),
    'accepted': Color(0xFFDBEAFE),
    'ready': Color(0xFFEDE9FE),
    'out_for_delivery': Color(0xFFCFFAFE),
    'delivered': Color(0xFFF0FDF4),
    'cancelled': Color(0xFFFEF2F2),
  };

  static const _amber = Color(0xFFD97706);

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month]}  $h:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'placed';
    final shortId = order['short_id'] as String? ?? '';
    final restaurant = order['restaurant_name'] as String? ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final itemsCount = (order['items_count'] as int?) ?? 0;
    final createdAt = order['created_at'] as String?;
    final isDone = status == 'delivered' || status == 'cancelled';

    return GestureDetector(
      onTap: () => onTrack(
          order['order_id'] as String, shortId, total),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('#$shortId',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917))),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusBg[status] ?? const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel[status] ?? status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor[status] ?? _amber),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.restaurant, size: 14, color: Color(0xFF78716C)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(restaurant,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.fastfood_outlined,
                size: 14, color: Color(0xFF78716C)),
            const SizedBox(width: 6),
            Text(
                '$itemsCount item${itemsCount == 1 ? '' : 's'}  •  ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
            if (createdAt != null) ...[
              const Spacer(),
              Text(_formatDate(createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFA8A29E))),
            ],
          ]),
          if (!isDone) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () =>
                    onTrack(order['order_id'] as String, shortId, total),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Track Order',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
