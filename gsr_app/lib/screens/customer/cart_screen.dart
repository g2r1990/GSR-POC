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

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final items = CartService.items;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Your Cart'),
        centerTitle: true,
        elevation: 0,
      ),
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Color(0xFFD6D3D1)),
                  SizedBox(height: 12),
                  Text('Your cart is empty',
                      style: TextStyle(
                          fontSize: 16, color: Color(0xFF78716C))),
                ],
              ),
            )
          : Column(
              children: [
                // Restaurant banner
                if (CartService.restaurantName != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFFFEF3C7),
                    child: Row(children: [
                      const Icon(Icons.storefront,
                          size: 16, color: Color(0xFF92400E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(CartService.restaurantName!,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E))),
                      ),
                    ]),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) =>
                        _CartItemRow(item: items[i], onChanged: _refresh),
                  ),
                ),

                // Summary + checkout
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        top: BorderSide(color: Color(0xFFFEF3C7), width: 2)),
                  ),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${CartService.itemCount} item${CartService.itemCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF78716C)),
                          ),
                          Text(
                            '₹${CartService.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706)),
                          ),
                        ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
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
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
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
            Text('₹${item.price.toStringAsFixed(item.price.truncateToDouble() == item.price ? 0 : 2)} each',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF78716C))),
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
