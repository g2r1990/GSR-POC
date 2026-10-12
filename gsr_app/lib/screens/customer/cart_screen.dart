import 'package:flutter/material.dart';
import '../../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _amber = Color(0xFFD97706);

  // null = landing (restaurant list), set = detail (items for that restaurant)
  String? _selectedId;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (_selectedId != null &&
        CartService.itemsForRestaurant(_selectedId!).isEmpty) {
      _selectedId = null;
    }

    return PopScope(
      canPop: _selectedId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedId != null) {
          setState(() => _selectedId = null);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7ED),
        appBar: AppBar(
          backgroundColor: _amber,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          title: Text(_selectedId == null
              ? 'My Cart'
              : CartService.nameForRestaurant(_selectedId!) ?? 'Cart'),
          leading: _selectedId != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedId = null),
                )
              : null,
        ),
        body: _selectedId == null ? _buildLanding() : _buildDetail(_selectedId!),
      ),
    );
  }

  // ── Landing: list of restaurants with saved items ─────────────────────────

  Widget _buildLanding() {
    final ids = CartService.restaurantIds;

    if (ids.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFFD6D3D1)),
            SizedBox(height: 12),
            Text('Your cart is empty',
                style: TextStyle(fontSize: 16, color: Color(0xFF78716C))),
            SizedBox(height: 6),
            Text('Add items from a restaurant to get started',
                style: TextStyle(fontSize: 13, color: Color(0xFFA8A29E))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ids.length,
      itemBuilder: (ctx, i) {
        final id = ids[i];
        final name = CartService.nameForRestaurant(id) ?? id;
        final count = CartService.countForRestaurant(id);
        final total = CartService.totalForRestaurant(id);

        return GestureDetector(
          onTap: () {
            CartService.setActive(id);
            setState(() => _selectedId = id);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 6,
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
                child: const Icon(Icons.storefront, color: _amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1917))),
                    const SizedBox(height: 2),
                    Text(
                      '$count item${count == 1 ? '' : 's'}  ·  ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF78716C)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _amber),
            ]),
          ),
        );
      },
    );
  }

  // ── Detail: items for one restaurant ─────────────────────────────────────

  Widget _buildDetail(String restaurantId) {
    final items = CartService.itemsForRestaurant(restaurantId);
    final count = CartService.countForRestaurant(restaurantId);
    final total = CartService.totalForRestaurant(restaurantId);

    if (items.isEmpty) {
      return const Center(
        child: Text('No items in cart',
            style: TextStyle(fontSize: 15, color: Color(0xFF78716C))),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: items.length,
              itemBuilder: (ctx, i) =>
                  _CartItemRow(item: items[i], onChanged: _refresh),
            ),
          ),
        ),

        // Bottom panel
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: Color(0xFFFEF3C7), width: 2)),
            ),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$count item${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF78716C))),
                  Text('₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _amber)),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                // Clear cart button
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Cart?'),
                        content: const Text(
                            'All saved items for this restaurant will be removed.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear',
                                  style: TextStyle(color: Color(0xFFDC2626)))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      CartService.clearRestaurant(restaurantId);
                      setState(() => _selectedId = null);
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFFDC2626)),
                  label: const Text('Clear',
                      style: TextStyle(color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                // Proceed to checkout
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        CartService.setActive(restaurantId);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CheckoutScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Proceed to Checkout',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onChanged;

  const _CartItemRow({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1917))),
            Text(
                '₹${item.price.toStringAsFixed(item.price.truncateToDouble() == item.price ? 0 : 2)} each',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78716C))),
          ]),
        ),
        _QtyControl(
          qty: item.qty,
          onAdd: () {
            CartService.add(
                CartService.restaurantId!,
                CartService.restaurantName!,
                item.itemId,
                item.name,
                item.category,
                item.price);
            onChanged();
          },
          onRemove: () {
            CartService.remove(item.itemId);
            onChanged();
          },
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            '₹${(item.price * item.qty).toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD97706)),
          ),
        ),
      ]),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QtyControl(
      {required this.qty, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(icon: Icons.remove, onTap: onRemove),
        SizedBox(
          width: 28,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917))),
        ),
        _Btn(icon: Icons.add, onTap: onAdd),
      ],
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
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF92400E)),
      ),
    );
  }
}
