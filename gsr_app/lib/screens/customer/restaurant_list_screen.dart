import 'dart:async';
import 'package:flutter/material.dart';
import 'restaurant_menu_screen.dart';
import '../../services/api_service.dart';

class RestaurantListScreen extends StatefulWidget {
  final String pincode;
  final List<Map<String, dynamic>> restaurants;
  final String? searchLabel;
  final String customerPhone;

  const RestaurantListScreen({
    super.key,
    required this.pincode,
    required this.restaurants,
    this.searchLabel,
    this.customerPhone = '',
  });

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  static const _amber = Color(0xFFD97706);

  late List<Map<String, dynamic>> _restaurants;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _restaurants = List.from(widget.restaurants);
    // Only auto-refresh pincode-based lists (not search results)
    if (widget.searchLabel == null) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final list = await ApiService.searchRestaurants(widget.pincode);
      if (mounted) setState(() => _restaurants = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: Text(widget.searchLabel ?? 'Restaurants — ${widget.pincode}'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _restaurants.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _restaurants.length,
              itemBuilder: (ctx, i) => _RestaurantCard(
                data: _restaurants[i],
                customerPhone: widget.customerPhone,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => RestaurantMenuScreen(
                      restaurantId: _restaurants[i]['id'] as String,
                      restaurantName: _restaurants[i]['name'] as String,
                      freshStart: true,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 64, color: Color(0xFFD6D3D1)),
            const SizedBox(height: 16),
            Text(
              'No restaurants found for ${widget.pincode}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1917),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a nearby pincode, or check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF78716C)),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Search again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String customerPhone;
  final VoidCallback onTap;

  const _RestaurantCard({required this.data, required this.customerPhone, required this.onTap});

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  bool _notifyRequested = false;
  bool _notifyLoading = false;

  Future<void> _requestNotify() async {
    if (_notifyLoading || _notifyRequested) return;
    final restaurantId = widget.data['id'] as String? ?? '';
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
    final isAccepting = widget.data['is_accepting_orders'] as bool? ?? true;
    final foodType = widget.data['food_type'] as String? ?? 'both';

    return Opacity(
      opacity: isAccepting ? 1.0 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: isAccepting ? const Color(0xFFFDE68A) : const Color(0xFFFCA5A5)),
        ),
        color: Colors.white,
        child: InkWell(
          onTap: isAccepting ? widget.onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: isAccepting ? const Color(0xFFFFF7ED) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isAccepting ? const Color(0xFFFDE68A) : const Color(0xFFD1D5DB)),
                    ),
                    child: Icon(Icons.storefront,
                        color: isAccepting ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                        size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.data['name'] as String? ?? '',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1917))),
                      const SizedBox(height: 4),
                      Text(widget.data['area'] as String? ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF78716C))),
                      const SizedBox(height: 6),
                      _FoodTypeBadge(foodType: foodType),
                      Builder(builder: (_) {
                        final matching = (widget.data['matching_items'] as List<dynamic>?)?.cast<String>();
                        if (matching == null || matching.isEmpty) return const SizedBox.shrink();
                        final preview = matching.take(3).join(', ');
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Serves: $preview',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                              overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ]),
                  ),
                  Icon(Icons.chevron_right,
                      color: isAccepting ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                      size: 24),
                ]),
              ),
              if (!isAccepting)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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

class _FoodTypeBadge extends StatelessWidget {
  final String foodType;
  const _FoodTypeBadge({required this.foodType});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (foodType) {
      case 'veg':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF15803D);
        label = 'Pure Veg';
        icon = Icons.eco;
        break;
      case 'nonveg':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFBE123C);
        label = 'Non-Veg';
        icon = Icons.lunch_dining;
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        label = 'Veg & Non-Veg';
        icon = Icons.restaurant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
