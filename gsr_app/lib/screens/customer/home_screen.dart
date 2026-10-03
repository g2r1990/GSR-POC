import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import '../../services/offer_service.dart';
import '../../services/route_observer.dart';
import 'cart_screen.dart';
import 'order_status_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'restaurant_list_screen.dart';
import 'restaurant_menu_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with RouteAware {
  static const _amber = Color(0xFFD97706);

  // Profile
  String _name = '';
  String _phone = '';
  String _pincode = '';
  String _district = '';

  // Active orders (list — one banner per order)
  List<Map<String, String>> _activeOrders = [];

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
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _offersTimer;

  @override
  void initState() {
    super.initState();
    _pincodeCtrl = TextEditingController();
    _foodQueryCtrl = TextEditingController();
    _foodQueryCtrl.addListener(() { if (mounted) setState(() {}); });
    _loadAll();
    _offersTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _loadOffers();
    });
  }

  List<Map<String, dynamic>> get _filteredRestaurants {
    final q = _foodQueryCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _nearbyRestaurants;
    return _nearbyRestaurants
        .where((r) => (r['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    // Triggered whenever a route on top of home is popped (e.g. restaurant menu)
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _offersTimer?.cancel();
    _pincodeCtrl.dispose();
    _foodQueryCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Read active orders list; migrate from legacy single-key format if needed
    final activeRaw = prefs.getString('active_orders') ?? '[]';
    List<dynamic> decoded;
    try { decoded = jsonDecode(activeRaw) as List<dynamic>; } catch (_) { decoded = []; }
    if (decoded.isEmpty) {
      final oldId = prefs.getString('active_order_id');
      final oldShortId = prefs.getString('active_order_short_id');
      if (oldId != null) {
        decoded = [{'order_id': oldId, 'short_id': oldShortId ?? ''}];
        await prefs.setString('active_orders', jsonEncode(decoded));
        await prefs.remove('active_order_id');
        await prefs.remove('active_order_short_id');
      }
    }
    final activeOrders = decoded
        .map((e) => Map<String, String>.from(e as Map))
        .toList();

    if (!mounted) return;
    setState(() {
      _name = prefs.getString('customer_name') ?? '';
      _phone = prefs.getString('customer_phone') ?? '';
      _pincode = prefs.getString('customer_pincode') ?? '';
      _district = prefs.getString('customer_district') ?? '';
      _activeOrders = activeOrders;
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

  Future<void> _loadActiveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString('active_orders') ?? '[]';
    List<dynamic> decoded;
    try { decoded = jsonDecode(raw) as List<dynamic>; } catch (_) { decoded = []; }
    setState(() {
      _activeOrders = decoded
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    });
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

    // Client-side: match restaurant names first
    final q = query.toLowerCase();
    final matchedByName = _nearbyRestaurants
        .where((r) => (r['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
    if (matchedByName.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantListScreen(
            pincode: _pincode,
            restaurants: matchedByName,
            searchLabel: 'Restaurants for "$query"',
          ),
        ),
      );
      return;
    }

    // Backend: search food items
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
              _loadActiveOrders();
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
      bottomNavigationBar: CartService.itemCount > 0
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _cartBar(),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: _amber,
        onRefresh: _loadAll,
        child: Scrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
          controller: _scrollCtrl,
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

              // ── Active orders banners (one per active order) ─────────
              if (_activeOrders.isNotEmpty)
                ...List.generate(_activeOrders.length, (i) {
                  final order = _activeOrders[i];
                  final orderId = order['order_id'] ?? '';
                  final shortId = order['short_id'] ?? '';
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 6, 16, 0),
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => OrderStatusScreen(
                            orderId: orderId,
                            shortId: shortId,
                            total: 0,
                          ),
                        ));
                        _loadActiveOrders();
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
                                Text(
                                  _activeOrders.length > 1
                                      ? 'Order ${i + 1} in Progress'
                                      : 'Order in Progress',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E))),
                                Text(
                                    'Tap to track  #$shortId',
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
                  );
                }),

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
                    height: 115,
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
                    if (_nearbyRestaurants.length > 5)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RestaurantListScreen(
                              pincode: _pincode,
                              restaurants: _nearbyRestaurants,
                            ),
                          ),
                        ),
                        child: const Text('View All',
                            style: TextStyle(
                                fontSize: 12,
                                color: _amber,
                                fontWeight: FontWeight.w600)),
                      ),
                    if (_nearbyRestaurants.length > 5) const SizedBox(width: 8),
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
                for (final r in _filteredRestaurants.take(5))
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
              ],

              // ── My Orders ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/customer/orders');
                    _loadActiveOrders();
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
                            Text('Track active & view order history',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78716C))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: _amber),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
        ), // Scrollbar
      ), // RefreshIndicator / body
    );
  }

  Widget _cartBar() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _amber,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(64),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${CartService.itemCount} item${CartService.itemCount == 1 ? '' : 's'} in cart',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              if (CartService.restaurantName != null)
                Text(CartService.restaurantName!,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(
            '₹${CartService.total.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('View Cart',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ]),
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
    final restaurantId = offer['restaurant_id'] as String? ?? '';
    final restaurant = offer['restaurant_name'] as String? ?? '';
    final area = offer['restaurant_area'] as String? ?? '';
    final title = offer['title'] as String? ?? '';
    final offerCode = offer['offer_code'] as String? ?? '';
    return GestureDetector(
      onTap: () {
        if (restaurantId.isEmpty) return;

        // One offer at a time — block if any offer is already applied
        if (OfferService.hasOffer) {
          final msg = OfferService.restaurantId == restaurantId
              ? 'Offer already applied! Proceed to checkout or remove the current offer.'
              : 'Remove your current offer before applying another.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF7C3AED),
            duration: const Duration(seconds: 3),
          ));
          return;
        }

        // Cart has items from a different restaurant with no offer → block
        if (CartService.itemCount > 0 && CartService.restaurantId != restaurantId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clear your current cart to use this offer.'),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        OfferService.apply(offer);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RestaurantMenuScreen(
            restaurantId: restaurantId,
            restaurantName: restaurant,
          ),
        ));
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
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
              const Icon(Icons.local_offer, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(restaurant,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            if (area.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(area,
                  style: const TextStyle(fontSize: 9, color: Colors.white54),
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            if (offerCode.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white54, width: 0.5),
                ),
                child: Text(offerCode,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 4),
            ],
            Row(children: [
              if (discount != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$discount% OFF',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Order →',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ]),
          ],
        ),
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
