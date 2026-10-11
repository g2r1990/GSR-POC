import 'package:flutter/material.dart';
import 'restaurant_menu_screen.dart';

class RestaurantListScreen extends StatelessWidget {
  final String pincode;
  final List<Map<String, dynamic>> restaurants;
  final String? searchLabel;

  const RestaurantListScreen({
    super.key,
    required this.pincode,
    required this.restaurants,
    this.searchLabel,
  });

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: Text(searchLabel ?? 'Restaurants — $pincode'),
        centerTitle: true,
        elevation: 0,
      ),
      body: restaurants.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: restaurants.length,
              itemBuilder: (ctx, i) => _RestaurantCard(
                data: restaurants[i],
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => RestaurantMenuScreen(
                      restaurantId: restaurants[i]['id'] as String,
                      restaurantName: restaurants[i]['name'] as String,
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
              'No restaurants found for $pincode',
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

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _RestaurantCard({required this.data, required this.onTap});

  String? _fmtBackOnline(String? raw) {
    if (raw == null) return null;
    try {
      final utcStr = (raw.endsWith('Z') || raw.contains('+')) ? raw : '${raw}Z';
      final dt = DateTime.parse(utcStr).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $ampm';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAccepting = data['is_accepting_orders'] as bool? ?? true;
    final backOnlineLabel = _fmtBackOnline(data['back_online_at'] as String?);
    final foodType = data['food_type'] as String? ?? 'both';

    return Opacity(
      opacity: isAccepting ? 1.0 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: isAccepting
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFFCA5A5)),
        ),
        color: Colors.white,
        child: InkWell(
          onTap: isAccepting ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isAccepting
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isAccepting
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFD1D5DB)),
                      ),
                      child: Icon(Icons.storefront,
                          color: isAccepting
                              ? const Color(0xFFD97706)
                              : const Color(0xFF9CA3AF),
                          size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['area'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF78716C)),
                          ),
                          const SizedBox(height: 6),
                          _FoodTypeBadge(foodType: foodType),
                          Builder(builder: (_) {
                            final matching = (data['matching_items'] as List<dynamic>?)?.cast<String>();
                            if (matching == null || matching.isEmpty) return const SizedBox.shrink();
                            final preview = matching.take(3).join(', ');
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Serves: $preview',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                  overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: isAccepting
                            ? const Color(0xFFD97706)
                            : const Color(0xFF9CA3AF),
                        size: 24),
                  ],
                ),
              ),
              if (!isAccepting)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Text(
                    backOnlineLabel != null
                        ? 'Currently unavailable · Back by $backOnlineLabel'
                        : 'Currently unavailable',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w500),
                  ),
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
