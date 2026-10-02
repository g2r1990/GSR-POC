import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  static const _amber = Color(0xFFD97706);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getRestaurantMenu(widget.restaurantId);
      if (mounted) setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Could not load menu. Tap to retry.'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: Text(widget.restaurantName,
            overflow: TextOverflow.ellipsis),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _amber))
          : _error != null
              ? _errorState()
              : _body(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: Color(0xFFD6D3D1)),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF78716C))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final restaurant = _data!['restaurant'] as Map<String, dynamic>;
    final menuRaw = _data!['menu'] as Map<String, dynamic>;

    if (menuRaw.isEmpty) {
      return _emptyMenu(restaurant);
    }

    final categories = menuRaw.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      color: _amber,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _RestaurantHeader(restaurant: restaurant),
          ),
          for (final cat in categories) ...[
            SliverToBoxAdapter(
              child: _CategoryHeader(title: cat),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final items =
                      menuRaw[cat] as List<dynamic>;
                  return _MenuItemTile(item: items[i] as Map<String, dynamic>);
                },
                childCount: (menuRaw[cat] as List).length,
              ),
            ),
          ],
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _emptyMenu(Map<String, dynamic> restaurant) {
    return ListView(
      children: [
        _RestaurantHeader(restaurant: restaurant),
        const SizedBox(height: 60),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_food_outlined,
                  size: 56, color: Color(0xFFD6D3D1)),
              SizedBox(height: 12),
              Text('No items available right now.',
                  style: TextStyle(
                      fontSize: 15, color: Color(0xFF78716C))),
            ],
          ),
        ),
      ],
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  const _RestaurantHeader({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final foodType = restaurant['food_type'] as String? ?? 'both';
    final area = restaurant['area'] as String? ?? '';
    final address = restaurant['address'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront,
                  color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  restaurant['name'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
            ],
          ),
          if (area.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(area,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF78716C))),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(address,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFA8A29E))),
          ],
          const SizedBox(height: 8),
          _foodTypeBadge(foodType),
        ],
      ),
    );
  }

  Widget _foodTypeBadge(String foodType) {
    Color bg, fg;
    String label;
    switch (foodType) {
      case 'veg':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF15803D);
        label = '🟢 Pure Veg';
        break;
      case 'nonveg':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFBE123C);
        label = '🔴 Non-Veg';
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        label = '🔵 Veg & Non-Veg';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF92400E),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final description = item['description'] as String?;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFFEF3C7)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF78716C)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
