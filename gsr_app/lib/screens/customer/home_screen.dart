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
  int? _restaurantCount;

  // Offers + nearby restaurants
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _nearbyRestaurants = [];

  // Controllers
  late TextEditingController _pincodeCtrl;
  late TextEditingController _foodQueryCtrl;

  @override
  void initState() {
    super.initState();
    _pincodeCtrl = TextEditingController();
    _foodQueryCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    _foodQueryCtrl.dispose();
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
    _loadRestaurantCount();
    _loadOffers();
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

  Future<void> _loadRestaurantCount() async {
    if (_pincode.isEmpty) return;
    try {
      final list = await ApiService.searchRestaurants(_pincode);
      if (mounted) setState(() {
        _restaurantCount = list.length;
        _nearbyRestaurants = list;
      });
    } catch (_) {}
  }

  Future<void> _loadOffers() async {
    if (_pincode.isEmpty) return;
    try {
      final offers = await ApiService.getCustomerOffers(_pincode);
      if (mounted) setState(() => _offers = offers);
    } catch (_) {}
  }

  Future<void> _search() async {
    final query = _foodQueryCtrl.text.trim();
    if (_pincode.isEmpty) {
      setState(() => _searchError = 'Please detect your location first.');
      return;
    }
    if (query.isEmpty) {
      _findRestaurants();
      return;
    }
    setState(() { _searching = true; _searchError = null; });
    try {
      final results = await ApiService.searchFood(query, _pincode);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantListScreen(
            pincode: _pincode,
            restaurants: results,
            searchLabel: 'Results for "$query"',
          ),
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
    setState(() { _searching = true; _searchError = null; });
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

              // ── Food search card ─────────────────────────────────────
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
                        const Icon(Icons.search, color: _amber, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Find Food or Restaurants',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C1917))),
                        ),
                        _detectingLocation
                            ? const SizedBox(
                                width: 20, height: 20,
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: _foodQueryCtrl,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'biryani, naan, pizza...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14),
                          prefixIcon: const Icon(Icons.restaurant_menu,
                              color: _amber, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFFFFBEB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFFDE68A))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFFDE68A))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: _amber, width: 2)),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                      if (_pincode.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on,
                              size: 12, color: Color(0xFFA8A29E)),
                          const SizedBox(width: 4),
                          Text(
                            'Near $_pincode${_district.isNotEmpty ? ' · $_district' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFA8A29E)),
                          ),
                        ]),
                      ],
                      if (_searchError != null) ...[
                        const SizedBox(height: 6),
                        Text(_searchError!,
                            style: const TextStyle(
                                color: Color(0xFFDC2626), fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _searching ? null : _search,
                          icon: _searching
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search, size: 20),
                          label: Text(
                              _searching ? 'Searching…' : 'Search Food',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
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

              // ── Browse Restaurants card ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GestureDetector(
                  onTap: _searching ? null : _findRestaurants,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_outlined, color: _amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Browse Restaurants',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1917))),
                            Text(
                              _restaurantCount != null
                                  ? '$_restaurantCount restaurants accepting orders near you'
                                  : 'See all restaurants near your location',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF78716C)),
                            ),
                          ],
                        ),
                      ),
                      if (_restaurantCount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$_restaurantCount open',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _amber)),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: _amber, size: 20),
                    ]),
                  ),
                ),
              ),

              // ── Offers ──────────────────────────────────────────────
              ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    const Icon(Icons.local_offer,
                        size: 17, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 6),
                    const Text('Offers',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1917))),
                  ]),
                ),
                const SizedBox(height: 10),
                if (_offers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEDE9FE)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_offer_outlined,
                            size: 20, color: Color(0xFFD8B4FE)),
                        const SizedBox(width: 10),
                        const Text('No deals right now — check back later!',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF6D28D9))),
                      ]),
                    ),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _offers.length,
                      itemBuilder: (ctx, i) => _OfferCard(offer: _offers[i]),
                    ),
                  ),
              ],

              // ── Restaurants Near You ─────────────────────────────────
              if (_nearbyRestaurants.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    const Expanded(
                      child: Text('Restaurants Near You',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1917))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_nearbyRestaurants.length} open',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                for (final r in _nearbyRestaurants.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _NearbyRestaurantTile(
                      restaurant: r,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantListScreen(
                            pincode: _pincode,
                            restaurants: _nearbyRestaurants,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_nearbyRestaurants.length > 3)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: TextButton.icon(
                      onPressed: _findRestaurants,
                      icon: const Icon(Icons.storefront_outlined,
                          size: 16, color: _amber),
                      label: Text(
                        'See all ${_nearbyRestaurants.length} restaurants →',
                        style: const TextStyle(fontSize: 13, color: _amber),
                      ),
                    ),
                  ),
              ],

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

// ── Offer + restaurant widgets ────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final discount = offer['discount_pct'];
    final restaurant = offer['restaurant_name'] as String? ?? '';
    final title = offer['title'] as String? ?? '';
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_offer, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(restaurant,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const Spacer(),
          if (discount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$discount% OFF',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

class _NearbyRestaurantTile extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;
  const _NearbyRestaurantTile(
      {required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final foodType = restaurant['food_type'] as String? ?? 'both';
    final foodLabel = foodType == 'veg'
        ? 'Pure Veg'
        : foodType == 'nonveg'
            ? 'Non-Veg'
            : 'Veg & Non-Veg';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront,
                color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant['name'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917))),
                Text(
                    '${restaurant['area'] ?? ''}  •  $foodLabel',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78716C)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFD6D3D1)),
        ]),
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
