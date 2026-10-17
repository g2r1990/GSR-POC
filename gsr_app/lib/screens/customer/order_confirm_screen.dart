import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'order_status_screen.dart';

class OrderConfirmScreen extends StatefulWidget {
  final String orderId;
  final String shortId;
  final double total;
  final double deliveryFee;
  final double gst;
  final String? createdAt;
  final String offerCode;
  final double discountAmount;
  final String orderType;
  final String paymentMethod;
  final String? pickupCode;
  final int cancellationWindowMins;

  const OrderConfirmScreen({
    super.key,
    required this.orderId,
    required this.shortId,
    required this.total,
    this.deliveryFee = 20.0,
    this.gst = 0.0,
    this.createdAt,
    this.offerCode = '',
    this.discountAmount = 0.0,
    this.orderType = 'delivery',
    this.paymentMethod = 'online',
    this.pickupCode,
    this.cancellationWindowMins = 1,
  });

  @override
  State<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends State<OrderConfirmScreen> {
  static const _amber = Color(0xFFD97706);

  int _cancelSecondsLeft = 60;
  Timer? _cancelTimer;
  bool _cancelling = false;
  bool _cancelled = false;

  double get _grandTotal => widget.total;

  @override
  void initState() {
    super.initState();
    final windowSecs = widget.cancellationWindowMins * 60;
    if (widget.createdAt != null) {
      try {
        final raw = widget.createdAt!;
        final createdAt = DateTime.parse(raw.endsWith('Z') ? raw : '${raw}Z');
        final elapsed = DateTime.now().toUtc().difference(createdAt).inSeconds;
        final remaining = windowSecs - elapsed;
        _cancelSecondsLeft = remaining > 0 ? remaining : 0;
      } catch (_) {
        _cancelSecondsLeft = windowSecs;
      }
    } else {
      _cancelSecondsLeft = windowSecs;
    }
    if (_cancelSecondsLeft > 0) {
      _cancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _cancelSecondsLeft--;
          if (_cancelSecondsLeft <= 0) { _cancelSecondsLeft = 0; t.cancel(); }
        });
      });
    }
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelOrder() async {
    setState(() => _cancelling = true);
    try {
      await ApiService.cancelOrder(widget.orderId);
      _cancelTimer?.cancel();
      if (mounted) setState(() { _cancelled = true; _cancelling = false; });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFDC2626)),
        );
        setState(() => _cancelling = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not cancel. Try again.'),
              backgroundColor: Color(0xFFDC2626)),
        );
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cancelled) return _cancelledBody(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _cancelSecondsLeft > 0
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  _cancelSecondsLeft > 0
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_outline,
                  size: 48,
                  color: _cancelSecondsLeft > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                  _cancelSecondsLeft > 0 ? 'Order in Queue' : 'Order Placed!',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917))),
              const SizedBox(height: 8),
              Text(
                  _cancelSecondsLeft > 0
                      ? 'Order is in queue — waiting for restaurant to confirm'
                      : widget.orderType == 'takeaway'
                          ? 'Your takeaway order is confirmed'
                          : 'Your order has been confirmed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF78716C))),
              if (widget.paymentMethod == 'cod') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.money, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text('Cash on Delivery — pay rider at your door',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
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
                      style: TextStyle(fontSize: 13, color: Color(0xFF78716C))),
                  const SizedBox(height: 4),
                  Text('#${widget.shortId}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                          letterSpacing: 2)),
                  if (widget.orderType == 'takeaway' && widget.pickupCode != null) ...[
                    const SizedBox(height: 8),
                    const Text('Pickup Code',
                        style: TextStyle(fontSize: 12, color: Color(0xFF78716C))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(widget.pickupCode!,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF166534),
                              letterSpacing: 4)),
                    ),
                    const SizedBox(height: 4),
                    const Text('Show this code to collect your order',
                        style: TextStyle(fontSize: 11, color: Color(0xFF78716C))),
                  ],
                  const Divider(height: 24),
                  if (widget.offerCode.isNotEmpty && widget.discountAmount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, size: 12, color: Color(0xFF166534)),
                          const SizedBox(width: 4),
                          Text('Offer (${widget.offerCode})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
                        ]),
                        Text('-₹${widget.discountAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 14),
                  ],
                  if (widget.deliveryFee > 0) ...[
                    _BillRow('Delivery Fee', '₹${widget.deliveryFee.toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                  ],
                  if (widget.gst > 0) ...[
                    _BillRow('GST', '₹${widget.gst.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                  ],
                  if (widget.orderType == 'takeaway')
                    const _BillRow('Delivery Fee / GST', '₹0 (Takeaway)'),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('₹${_grandTotal.round()}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text(
                widget.orderType == 'takeaway'
                    ? 'The restaurant will prepare your order.\nCome to collect when it\'s ready.'
                    : 'The restaurant will prepare your order.\nPlease wait for delivery.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF78716C), height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => OrderStatusScreen(
                        orderId: widget.orderId,
                        shortId: widget.shortId,
                        total: _grandTotal,
                      ),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Track My Order',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              if (_cancelSecondsLeft > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancelOrder,
                    icon: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFDC2626)))
                        : const Icon(Icons.cancel_outlined,
                            color: Color(0xFFDC2626), size: 20),
                    label: Text(
                      _cancelling
                          ? 'Cancelling…'
                          : 'Cancel Order  ($_cancelSecondsLeft s)',
                      style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/customer/home', (_) => false),
                child: const Text('Back to Home',
                    style: TextStyle(color: Color(0xFF78716C))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cancelledBody(BuildContext context) {
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
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      size: 48, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 24),
                const Text('Order Cancelled',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626))),
                const SizedBox(height: 8),
                const Text('Your order has been cancelled successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF78716C))),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/customer/home', (_) => false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Back to Home',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _BillRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final weight = bold ? FontWeight.w700 : FontWeight.normal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: const Color(0xFF78716C), fontWeight: weight)),
        Text(value,
            style: TextStyle(fontSize: 12, color: const Color(0xFF374151), fontWeight: weight)),
      ],
    );
  }
}
