import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;
  final String shortId;
  final double total;

  const OrderStatusScreen({
    super.key,
    required this.orderId,
    required this.shortId,
    required this.total,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  static const _amber = Color(0xFFD97706);
  static const _green = Color(0xFF166534);

  static const _steps = [
    'placed',
    'accepted',
    'ready',
    'out_for_delivery',
    'delivered',
  ];

  static const _stepLabels = {
    'placed': 'Order Placed',
    'accepted': 'Accepted',
    'ready': 'Ready',
    'out_for_delivery': 'Out for Delivery',
    'delivered': 'Delivered',
  };

  static const _stepIcons = {
    'placed': Icons.receipt_long_outlined,
    'accepted': Icons.thumb_up_outlined,
    'ready': Icons.restaurant_outlined,
    'out_for_delivery': Icons.delivery_dining,
    'delivered': Icons.check_circle_outline,
  };

  static const _stepMessages = {
    'placed': 'Your order has been sent to the restaurant.',
    'accepted': 'The restaurant has accepted your order and is preparing it.',
    'ready': 'Your order is ready and waiting for pickup by the delivery person.',
    'out_for_delivery': 'Your order is on its way to you!',
    'delivered': 'Your order has been delivered. Enjoy your meal!',
  };

  Map<String, dynamic>? _order;
  String _status = 'placed';
  bool _loading = true;
  String? _error;
  Timer? _timer;

  // 60-second cancel window
  int _cancelSecondsLeft = 0;
  Timer? _cancelTimer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_status != 'delivered' && _status != 'cancelled') _fetch();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _startCancelTimer() {
    if (_order == null || _status != 'placed') return;
    final raw = _order!['created_at'] as String? ?? '';
    if (raw.isEmpty) return;
    try {
      final createdAt = DateTime.parse(raw.endsWith('Z') ? raw : '${raw}Z');
      final elapsed = DateTime.now().toUtc().difference(createdAt).inSeconds;
      final remaining = 30 - elapsed;
      if (remaining <= 0) return;
      if (mounted) setState(() => _cancelSecondsLeft = remaining);
      _cancelTimer?.cancel();
      _cancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _status != 'placed') { t.cancel(); return; }
        setState(() {
          _cancelSecondsLeft--;
          if (_cancelSecondsLeft <= 0) { _cancelSecondsLeft = 0; t.cancel(); }
        });
      });
    } catch (_) {}
  }

  Future<void> _removeFromActiveOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('active_orders') ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      final updated = list.where((e) => (e as Map)['order_id'] != widget.orderId).toList();
      await prefs.setString('active_orders', jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> _restoreOfferCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapRaw = prefs.getString('order_offer_map') ?? '{}';
      final offerMap = jsonDecode(mapRaw) as Map<String, dynamic>;
      final code = offerMap[widget.orderId] as String?;
      if (code == null || code.isEmpty) return;
      final usedRaw = prefs.getString('used_offer_codes') ?? '[]';
      final usedList = (jsonDecode(usedRaw) as List<dynamic>)
          .where((e) => e.toString() != code)
          .toList();
      await prefs.setString('used_offer_codes', jsonEncode(usedList));
      offerMap.remove(widget.orderId);
      await prefs.setString('order_offer_map', jsonEncode(offerMap));
    } catch (_) {}
  }

  Future<void> _cancelOrder() async {
    setState(() => _cancelling = true);
    try {
      await ApiService.cancelOrder(widget.orderId);
      _cancelTimer?.cancel();
      await _restoreOfferCode();
      if (mounted) setState(() { _status = 'cancelled'; _cancelSecondsLeft = 0; });
      _removeFromActiveOrders();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel. Try again.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.getOrderStatus(widget.orderId);
      if (mounted) {
        final wasPlaced = _status == 'placed';
        setState(() {
          _order = data;
          _status = data['status'] as String? ?? 'placed';
          _loading = false;
          _error = null;
        });
        // Start cancel countdown on first load when order is 'placed'
        if (!wasPlaced || _cancelTimer == null) _startCancelTimer();
        if (_status == 'delivered' || _status == 'cancelled') {
          _timer?.cancel();
          _cancelTimer?.cancel();
          _removeFromActiveOrders();
          if (_status == 'cancelled') _restoreOfferCode();
        }
      }
    } catch (_) {
      if (mounted && _loading) {
        setState(() { _loading = false; _error = 'Could not fetch status.'; });
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
        title: Text('Order #${widget.shortId}'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _error != null && _order == null
              ? _errorBody()
              : _body(),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFD6D3D1)),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Color(0xFF78716C))),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _fetch,
          style: ElevatedButton.styleFrom(
              backgroundColor: _amber, foregroundColor: Colors.white),
          child: const Text('Retry'),
        ),
      ]),
    );
  }

  Widget _body() {
    final isCancelled = _status == 'cancelled';
    final currentIdx = _steps.indexOf(_status);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCancelled
                  ? const Color(0xFFFEF2F2)
                  : _status == 'delivered'
                      ? const Color(0xFFF0FDF4)
                      : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isCancelled
                      ? const Color(0xFFFECACA)
                      : _status == 'delivered'
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFDE68A)),
            ),
            child: Column(children: [
              Icon(
                isCancelled
                    ? Icons.cancel_outlined
                    : (_stepIcons[_status] ?? Icons.hourglass_empty),
                size: 48,
                color: isCancelled
                    ? const Color(0xFFDC2626)
                    : _status == 'delivered'
                        ? _green
                        : _amber,
              ),
              const SizedBox(height: 10),
              Text(
                isCancelled
                    ? 'Order Cancelled'
                    : (_stepLabels[_status] ?? _status),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCancelled
                        ? const Color(0xFFDC2626)
                        : _status == 'delivered'
                            ? _green
                            : const Color(0xFF1C1917)),
              ),
              const SizedBox(height: 6),
              Text(
                isCancelled
                    ? 'Your order was cancelled.'
                    : (_stepMessages[_status] ?? ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF78716C), height: 1.4),
              ),
              if (_status != 'delivered' && !isCancelled) ...[
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _amber)),
                    SizedBox(width: 8),
                    Text('Live updates every 10s',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFFA8A29E))),
                  ],
                ),
              ],
            ]),
          ),

          // Cancel button (only while placed + within 60s window)
          if (_status == 'placed' && _cancelSecondsLeft > 0) ...[
            const SizedBox(height: 16),
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
                    : const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
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

          // Progress stepper
          if (!isCancelled) ...[
            const SizedBox(height: 24),
            const Text('Order Progress',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: List.generate(_steps.length, (i) {
                  final done = i <= currentIdx;
                  final active = i == currentIdx;
                  final isLast = i == _steps.length - 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: done
                                ? (active ? _amber : _green)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            done ? Icons.check : Icons.circle,
                            size: done ? 16 : 8,
                            color: done ? Colors.white : const Color(0xFFCBD5E1),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 32,
                            color: i < currentIdx
                                ? _green
                                : const Color(0xFFE2E8F0),
                          ),
                      ]),
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _stepLabels[_steps[i]] ?? _steps[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: done
                                ? const Color(0xFF1C1917)
                                : const Color(0xFFA8A29E),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],

          // Order summary
          if (_order != null) ...[
            const SizedBox(height: 20),
            const Text('Order Summary',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(children: [
                for (final item
                    in (_order!['items'] as List<dynamic>? ?? []))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              '${item['qty']}× ${item['name']}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF374151)))),
                      Text(
                          '₹${(item['subtotal'] as num?)?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF78716C))),
                    ]),
                  ),
                const Divider(height: 16),
                Builder(builder: (_) {
                  final _items = (_order!['items'] as List<dynamic>? ?? []);
                  final _sub = _items.fold(0.0, (s, item) =>
                      s + ((item['subtotal'] as num?)?.toDouble() ?? 0.0));
                  final _discount = (_order!['discount_amount'] as num?)?.toDouble() ?? 0.0;
                  final _offerCode = (_order!['offer_code'] as String?) ?? '';
                  final _discountedSub = _sub - _discount;
                  final _gst = double.parse((_discountedSub * 0.05).toStringAsFixed(2));
                  final _grand = _discountedSub + 20.0 + _gst;
                  return Column(children: [
                    if (_discount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _offerCode.isNotEmpty ? 'Discount ($_offerCode)' : 'Offer Discount',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                          ),
                          Text('-₹${_discount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    _BillRow('Delivery Fee', '₹20'),
                    const SizedBox(height: 4),
                    _BillRow('GST (5%)', '₹${_gst.toStringAsFixed(2)}'),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${_grand.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _amber)),
                      ],
                    ),
                  ]);
                }),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/customer/home', (_) => false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _amber,
                side: const BorderSide(color: _amber),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Home',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      ), // SingleChildScrollView
    ); // Scrollbar
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  const _BillRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF78716C))),
          Text(value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF78716C))),
        ],
      );
}
