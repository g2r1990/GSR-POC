import 'package:flutter/material.dart';
import 'restaurant_menu_screen.dart';

class RestaurantListScreen extends StatelessWidget {
  final String pincode;
  final List<Map<String, dynamic>> restaurants;

  const RestaurantListScreen({
    super.key,
    required this.pincode,
    required this.restaurants,
  });

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: Text('Restaurants — $pincode'),
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

  @override
  Widget build(BuildContext context) {
    final foodType = data['food_type'] as String? ?? 'both';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A)),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(Icons.storefront,
                    color: Color(0xFFD97706), size: 28),
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
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFFD97706), size: 24),
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
