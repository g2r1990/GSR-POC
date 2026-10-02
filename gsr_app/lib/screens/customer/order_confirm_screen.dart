import 'package:flutter/material.dart';
import 'order_status_screen.dart';

class OrderConfirmScreen extends StatelessWidget {
  final String orderId;
  final String shortId;
  final double total;

  const OrderConfirmScreen({
    super.key,
    required this.orderId,
    required this.shortId,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      size: 48, color: Color(0xFF166534)),
                ),
                const SizedBox(height: 24),
                const Text('Order Placed!',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917))),
                const SizedBox(height: 8),
                const Text('Your order has been sent to the restaurant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF78716C))),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(children: [
                    const Text('Order Number',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF78716C))),
                    const SizedBox(height: 4),
                    Text('#$shortId',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                            letterSpacing: 2)),
                    const SizedBox(height: 12),
                    const Text('Total Paid',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF78716C))),
                    const SizedBox(height: 4),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534))),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The restaurant will prepare your order.\nPlease wait for delivery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF78716C), height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => OrderStatusScreen(
                          orderId: orderId,
                          shortId: shortId,
                          total: total,
                        ),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Track My Order',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (_) => false),
                  child: const Text('Back to Home',
                      style: TextStyle(color: Color(0xFF78716C))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
