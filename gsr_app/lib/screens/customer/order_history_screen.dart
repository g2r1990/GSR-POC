import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'order_status_screen.dart';

class CustomerOrderHistoryScreen extends StatefulWidget {
  const CustomerOrderHistoryScreen({super.key});

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  static const _amber = Color(0xFFD97706);

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  String _mobile = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString('customer_phone') ?? '';
    if (mobile.isEmpty) {
      setState(() { _loading = false; _error = 'No mobile number found on device.'; });
      return;
    }
    _mobile = mobile;
    try {
      final orders = await ApiService.customerOrderHistory(mobile);
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not connect. Check your network.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('My Orders'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _error != null
              ? _errorView()
              : _orders.isEmpty
                  ? _emptyView()
                  : _listView(),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFD6D3D1)),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF78716C))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _amber, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ]),
        ),
      );

  Widget _emptyView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_outlined,
                size: 72, color: Color(0xFFD6D3D1)),
            const SizedBox(height: 16),
            const Text('No Orders Yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917))),
            const SizedBox(height: 8),
            const Text(
              'Your order history will appear here once you place your first order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
            ),
          ]),
        ),
      );

  Widget _listView() {
    // Separate active (not delivered/cancelled) vs past
    final active = _orders
        .where((o) =>
            o['status'] != 'delivered' && o['status'] != 'cancelled')
        .toList();
    final past = _orders
        .where((o) =>
            o['status'] == 'delivered' || o['status'] == 'cancelled')
        .toList();

    return RefreshIndicator(
      color: _amber,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active.isNotEmpty) ...[
            _SectionLabel('Active Orders'),
            const SizedBox(height: 10),
            ...active.map((o) => _OrderCard(order: o, mobile: _mobile)),
            const SizedBox(height: 20),
          ],
          if (past.isNotEmpty) ...[
            _SectionLabel('Past Orders'),
            const SizedBox(height: 10),
            ...past.map((o) => _OrderCard(order: o, mobile: _mobile)),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
            letterSpacing: 0.8),
      );
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String mobile;
  const _OrderCard({required this.order, required this.mobile});

  static const _amber = Color(0xFFD97706);

  static const _statusLabel = {
    'placed': 'Placed',
    'accepted': 'Accepted',
    'ready': 'Ready',
    'out_for_delivery': 'Out for Delivery',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  static const _statusColor = {
    'placed': Color(0xFFF59E0B),
    'accepted': Color(0xFF2563EB),
    'ready': Color(0xFF7C3AED),
    'out_for_delivery': Color(0xFF0891B2),
    'delivered': Color(0xFF166534),
    'cancelled': Color(0xFFDC2626),
  };

  static const _statusBg = {
    'placed': Color(0xFFFEF3C7),
    'accepted': Color(0xFFDBEAFE),
    'ready': Color(0xFFEDE9FE),
    'out_for_delivery': Color(0xFFCFFAFE),
    'delivered': Color(0xFFF0FDF4),
    'cancelled': Color(0xFFFEF2F2),
  };

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month]} ${dt.year}  $h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'placed';
    final shortId = order['short_id'] as String? ?? '';
    final restaurant = order['restaurant_name'] as String? ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final itemsCount = (order['items_count'] as int?) ?? 0;
    final createdAt = order['created_at'] as String?;
    final isDone = status == 'delivered' || status == 'cancelled';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderStatusScreen(
            orderId: order['order_id'] as String,
            shortId: shortId,
            total: total,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('#$shortId',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBg[status] ?? const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel[status] ?? status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusColor[status] ?? _amber),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.restaurant, size: 14, color: Color(0xFF78716C)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(restaurant,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF374151)),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.fastfood_outlined,
                    size: 14, color: Color(0xFF78716C)),
                const SizedBox(width: 5),
                Text('$itemsCount item${itemsCount == 1 ? '' : 's'}  •  ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151))),
              ]),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 14, color: Color(0xFFA8A29E)),
                  const SizedBox(width: 5),
                  Text(_formatDate(createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFA8A29E))),
                ]),
              ],
              if (!isDone) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderStatusScreen(
                          orderId: order['order_id'] as String,
                          shortId: shortId,
                          total: total,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Track Order',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
