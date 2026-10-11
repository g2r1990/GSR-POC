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
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'restaurant_list_screen.dart';
import 'notifications_screen.dart';
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

  // Recent order + cached full list for instant orders screen
  Map<String, dynamic>? _recentOrder;
  List<Map<String, dynamic>> _cachedOrders = [];

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
  Timer? _activeOrdersTimer;
  Timer? _restaurantsTimer;
  Timer? _notifTimer;

  // In-app notifications
  List<Map<String, dynamic>> _notifications = [];
  int get _unreadCount => _notifications.where((n) => n['is_read'] == false).length;

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
    _activeOrdersTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _pollActiveOrders();
    });
    _restaurantsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadRestaurantCount();
    });
    _notifTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadNotifications();
    });
  }

  int get _openCount => _nearbyRestaurants
      .where((r) => r['is_accepting_orders'] as bool? ?? true)
      .length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    if (mounted) _loadActiveOrders();
    if (mounted) _loadRecentOrder();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _offersTimer?.cancel();
    _activeOrdersTimer?.cancel();
    _restaurantsTimer?.cancel();
    _notifTimer?.cancel();
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
    _loadNotifications();
  }

  Future<void> _loadRecentOrder() async {
    if (_phone.isEmpty) return;
    try {
      final orders = await ApiService.customerOrderHistory(_phone);
      if (mounted) {
        setState(() {
          _cachedOrders = orders;
          if (orders.isNotEmpty) _recentOrder = orders.first;
        });
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

  Future<void> _pollActiveOrders() async {
    if (!mounted || _activeOrders.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_orders') ?? '[]';
    List<dynamic> list;
    try { list = jsonDecode(raw) as List<dynamic>; } catch (_) { return; }

    bool changed = false;
    final remaining = <Map<String, dynamic>>[];
    for (final entry in list) {
      final orderId = (entry as Map)['order_id'] as String? ?? '';
      if (orderId.isEmpty) continue;
      try {
        final data = await ApiService.getOrderStatus(orderId);
        final status = data['status'] as String? ?? '';
        if (status == 'delivered' || status == 'cancelled') {
          changed = true;
        } else {
          remaining.add(Map<String, dynamic>.from(entry));
        }
      } catch (_) {
        remaining.add(Map<String, dynamic>.from(entry));
      }
    }

    if (changed && mounted) {
      await prefs.setString('active_orders', jsonEncode(remaining));
      setState(() {
        _activeOrders = remaining
            .map((e) => Map<String, String>.from(e))
            .toList();
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

  Future<void> _loadNotifications() async {
    if (_phone.isEmpty) return;
    try {
      final notifs = await ApiService.getCustomerNotifications(_phone);
      if (!mounted) return;
      final prevUnread = _unreadCount;
      setState(() => _notifications = notifs);
      final newUnread = _unreadCount;
      if (newUnread > prevUnread) {
        final newest = _notifications.firstWhere(
          (n) => n['is_read'] == false,
          orElse: () => {},
        );
        if (newest.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newest['message'] as String? ??
                  'A restaurant is now accepting orders!'),
              backgroundColor: const Color(0xFF166534),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CustomerNotificationsScreen(
                      mobile: _phone,
                      initialNotifications: _notifications,
                    ),
                  ));
                  _loadNotifications();
                },
              ),
            ),
          );
        }
      }
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
            customerPhone: _phone,
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
            customerPhone: _phone,
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
          builder: (_) => RestaurantListScreen(
                pincode: pincode, restaurants: restaurants, customerPhone: _phone),
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CustomerNotificationsScreen(
                      mobile: _phone,
                      initialNotifications: _notifications,
                    ),
                  ));
                  _loadNotifications();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My Orders',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => CustomerOrderHistoryScreen(initialOrders: _cachedOrders),
              ));
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
                                  ? '$_openCount of $_restaurantCount restaurants near you are open'
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
                          child: Text('$_openCount open',
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
                              customerPhone: _phone,
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
                        '$_openCount open',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                for (final r in _nearbyRestaurants.take(5))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _NearbyRestaurantTile(
                      restaurant: r,
                      customerPhone: _phone,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantListScreen(
                            pincode: _pincode,
                            restaurants: _nearbyRestaurants,
                            customerPhone: _phone,
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
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CustomerOrderHistoryScreen(initialOrders: _cachedOrders),
                    ));
                    _loadActiveOrders();
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_outlined,
                                color: _amber, size: 22),
                          ),
                          if (_activeOrders.isNotEmpty)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_activeOrders.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Orders',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1917))),
                            Text(
                              _activeOrders.isNotEmpty
                                  ? '${_activeOrders.length} active order${_activeOrders.length == 1 ? '' : 's'} — tap to track'
                                  : 'Track active & view order history',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _activeOrders.isNotEmpty
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF78716C)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: _amber),
                    ]),
                  ),
                ),
              ),

              // ── My Cart ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Builder(builder: (_) {
                  final cartCount = CartService.itemCount;
                  final hasCart = cartCount > 0;
                  return GestureDetector(
                    onTap: hasCart
                        ? () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CartScreen()),
                            );
                            if (mounted) setState(() {});
                          }
                        : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasCart ? Colors.white : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: hasCart
                            ? [BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 8,
                                offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: hasCart
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.shopping_cart_outlined,
                                  color: hasCart ? _amber : const Color(0xFF9CA3AF),
                                  size: 22),
                            ),
                            if (hasCart)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _amber,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$cartCount',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('My Cart',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: hasCart
                                          ? const Color(0xFF1C1917)
                                          : const Color(0xFF9CA3AF))),
                              Text(
                                hasCart
                                    ? '$cartCount item${cartCount == 1 ? '' : 's'} · ₹${CartService.total.toStringAsFixed(0)}'
                                        '${CartService.restaurantName != null ? ' — ${CartService.restaurantName}' : ''}'
                                    : 'No items in cart',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: hasCart
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF9CA3AF)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (hasCart)
                          const Icon(Icons.chevron_right, color: _amber),
                      ]),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
        ), // Scrollbar
      ), // RefreshIndicator / body
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

class _NearbyRestaurantTile extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  final String customerPhone;
  final VoidCallback onTap;
  const _NearbyRestaurantTile({
    required this.restaurant,
    required this.customerPhone,
    required this.onTap,
  });

  @override
  State<_NearbyRestaurantTile> createState() => _NearbyRestaurantTileState();
}

class _NearbyRestaurantTileState extends State<_NearbyRestaurantTile> {
  bool _notifyRequested = false;
  bool _notifyLoading = false;

  @override
  void didUpdateWidget(_NearbyRestaurantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasOff = !(oldWidget.restaurant['is_accepting_orders'] as bool? ?? true);
    final isNowOn = widget.restaurant['is_accepting_orders'] as bool? ?? true;
    // Restaurant came back online — clear stale "✓ Notified" state
    if (wasOff && isNowOn && _notifyRequested) {
      setState(() => _notifyRequested = false);
    }
  }

  Future<void> _requestNotify() async {
    if (_notifyLoading || _notifyRequested) return;
    final restaurantId = widget.restaurant['id'] as String? ?? '';
    if (restaurantId.isEmpty || widget.customerPhone.isEmpty) return;
    setState(() => _notifyLoading = true);
    try {
      await ApiService.notifyMeWhenOpen(restaurantId, widget.customerPhone);
      if (mounted) setState(() { _notifyRequested = true; _notifyLoading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _notifyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not register. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAccepting = widget.restaurant['is_accepting_orders'] as bool? ?? true;
    final foodType = widget.restaurant['food_type'] as String? ?? 'both';
    final foodLabel = foodType == 'veg'
        ? 'Pure Veg'
        : foodType == 'nonveg' ? 'Non-Veg' : 'Veg & Non-Veg';

    return GestureDetector(
      onTap: isAccepting ? widget.onTap : null,
      child: Opacity(
        opacity: isAccepting ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: isAccepting ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isAccepting
                ? [BoxShadow(color: Colors.black.withAlpha(10),
                      blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isAccepting ? const Color(0xFFFEF3C7) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAccepting ? Icons.storefront : Icons.store_mall_directory_outlined,
                      color: isAccepting ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.restaurant['name'] as String? ?? '',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: isAccepting ? const Color(0xFF1C1917) : const Color(0xFF6B7280))),
                      Text('${widget.restaurant['area'] ?? ''}  •  $foodLabel',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFD6D3D1)),
                ]),
              ),
              if (!isAccepting)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    const Expanded(
                      child: Text('Currently not accepting orders',
                          style: TextStyle(fontSize: 11, color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500)),
                    ),
                    if (widget.customerPhone.isNotEmpty)
                      _notifyRequested
                          ? const Text('✓ Notified',
                              style: TextStyle(fontSize: 11, color: Color(0xFF166534),
                                  fontWeight: FontWeight.w700))
                          : GestureDetector(
                              onTap: _notifyLoading ? null : _requestNotify,
                              child: _notifyLoading
                                  ? const SizedBox(width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5, color: Color(0xFFDC2626)))
                                  : const Text('Notify me',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline)),
                            ),
                  ]),
                ),
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
