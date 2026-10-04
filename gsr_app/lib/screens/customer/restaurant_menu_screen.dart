import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import '../../services/offer_service.dart';
import 'cart_screen.dart';

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
  bool _offerItemAutoAdded = false;
  final _scrollCtrl = ScrollController();
  bool _showScrollHint = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 16;
    if (atBottom == _showScrollHint) setState(() => _showScrollHint = !atBottom);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getRestaurantMenu(widget.restaurantId);
      if (mounted) {
        setState(() { _data = data; _loading = false; _showScrollHint = true; });
        _autoAddOfferItem(data);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Could not load menu. Tap to retry.'; _loading = false; });
      }
    }
  }

  void _autoAddOfferItem(Map<String, dynamic> data) {
    if (_offerItemAutoAdded) return;
    if (!OfferService.hasOffer) return;
    if (OfferService.restaurantId != widget.restaurantId) return;
    final offerType = OfferService.offerType;
    if (offerType == 'order') return;
    final mid = OfferService.menuItemId;
    if (mid == null) return;

    final menuRaw = data['menu'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic>? foundItem;
    for (final cat in menuRaw.values) {
      for (final rawItem in cat as List) {
        final item = rawItem as Map<String, dynamic>;
        if (item['id'] == mid) { foundItem = item; break; }
      }
      if (foundItem != null) break;
    }
    if (foundItem == null) return;

    _offerItemAutoAdded = true;
    final itemId = foundItem['id'] as String;
    final name = foundItem['name'] as String? ?? '';
    final category = foundItem['category'] as String? ?? '';
    final price = (foundItem['price'] as num).toDouble();
    final qty = offerType == 'bogo'
        ? (OfferService.buyQty + OfferService.freeQty).clamp(1, 20)
        : 1;
    for (int i = 0; i < qty; i++) {
      CartService.add(widget.restaurantId, widget.restaurantName, itemId, name, category, price);
    }
    if (mounted) {
      final msg = offerType == 'bogo'
          ? '$name × $qty added (Buy ${OfferService.buyQty} Get ${OfferService.freeQty} Free)'
          : '$name added to your cart';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF7C3AED),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {});
    }
  }

  String _offerBannerText() {
    final type = OfferService.offerType;
    if (type == 'bogo') {
      return 'Buy ${OfferService.buyQty} Get ${OfferService.freeQty} Free — ${OfferService.menuItemName}';
    }
    if (type == 'item') {
      return '${OfferService.discountPct.toStringAsFixed(0)}% off on ${OfferService.menuItemName}';
    }
    return '${OfferService.discountPct.toStringAsFixed(0)}% off on your order';
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _refreshCart() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cartCount = CartService.restaurantId == widget.restaurantId
        ? CartService.itemCount
        : 0;
    final cartTotal = CartService.restaurantId == widget.restaurantId
        ? CartService.total
        : 0.0;

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
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator(color: _amber))
                    : _error != null
                        ? _errorState()
                        : _body(cartCount),
                if (_showScrollHint)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00FFF7ED), Color(0xCCFFF7ED)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFFD97706), size: 28),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (cartCount > 0)
            SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CartScreen()));
                  _refreshCart();
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '$cartCount item${cartCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      '₹${cartTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('View Cart',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      ),
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

  Widget _body(int cartCount) {
    final restaurant = _data!['restaurant'] as Map<String, dynamic>;
    final menuRaw = _data!['menu'] as Map<String, dynamic>;

    if (menuRaw.isEmpty) {
      return _emptyMenu(restaurant);
    }

    final categories = menuRaw.keys.toList()..sort();
    final offerApplied = OfferService.hasOffer &&
        OfferService.restaurantId == widget.restaurantId;
    return RefreshIndicator(
      onRefresh: _load,
      color: _amber,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          if (offerApplied)
            SliverToBoxAdapter(
              child: StatefulBuilder(
                builder: (ctx, setSt) {
                  if (!OfferService.hasOffer ||
                      OfferService.restaurantId != widget.restaurantId) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFF7C3AED),
                    child: Row(children: [
                      const Icon(Icons.local_offer,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _offerBannerText(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          OfferService.clear();
                          setSt(() {});
                        },
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 18),
                      ),
                    ]),
                  );
                },
              ),
            ),
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
                  final items = menuRaw[cat] as List<dynamic>;
                  return _MenuItemTile(
                    item: items[i] as Map<String, dynamic>,
                    restaurantId: widget.restaurantId,
                    restaurantName: widget.restaurantName,
                    onCartChanged: _refreshCart,
                  );
                },
                childCount: (menuRaw[cat] as List).length,
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 100)),
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

class _MenuItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final String restaurantId;
  final String restaurantName;
  final VoidCallback onCartChanged;

  const _MenuItemTile({
    required this.item,
    required this.restaurantId,
    required this.restaurantName,
    required this.onCartChanged,
  });

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile> {
  int get _qty => CartService.restaurantId == widget.restaurantId
      ? CartService.qtyFor(widget.item['id'] as String)
      : 0;

  void _add() {
    final item = widget.item;
    CartService.add(
      widget.restaurantId,
      widget.restaurantName,
      item['id'] as String,
      item['name'] as String,
      item['category'] as String? ?? '',
      (item['price'] as num).toDouble(),
    );
    setState(() {});
    widget.onCartChanged();
  }

  void _remove() {
    CartService.remove(widget.item['id'] as String);
    setState(() {});
    widget.onCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] as String? ?? '';
    final description = widget.item['description'] as String?;
    final price = (widget.item['price'] as num?)?.toDouble() ?? 0.0;
    final qty = _qty;

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
                  const SizedBox(height: 4),
                  Text(
                    '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            qty == 0
                ? GestureDetector(
                    onTap: _add,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD97706)),
                      ),
                      child: const Text('ADD',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706))),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Btn(icon: Icons.remove, onTap: _remove),
                      SizedBox(
                        width: 28,
                        child: Text('$qty',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1917))),
                      ),
                      _Btn(icon: Icons.add, onTap: _add),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFD97706),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
