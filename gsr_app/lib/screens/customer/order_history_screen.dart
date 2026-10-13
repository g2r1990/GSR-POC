import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'order_status_screen.dart';

class CustomerOrderHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialOrders;
  const CustomerOrderHistoryScreen({super.key, this.initialOrders});

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFD97706);
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  String _mobile = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (widget.initialOrders != null && widget.initialOrders!.isNotEmpty) {
      _orders = List.from(widget.initialOrders!);
      _loading = false;
      _loadSilent(); // refresh in background without showing spinner
    } else {
      _load();
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadSilent();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSilent() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString('customer_phone') ?? '';
    if (mobile.isEmpty) return;
    try {
      final orders = await ApiService.customerOrderHistory(mobile);
      if (mounted) setState(() { _orders = orders; });
    } catch (_) {}
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
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Active Orders'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _error != null
              ? _errorView()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _tabView(active: true),
                    _tabView(active: false),
                  ],
                ),
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

  Widget _tabView({required bool active}) {
    final filtered = _orders.where((o) {
      final isDone = o['status'] == 'delivered' || o['status'] == 'cancelled';
      return active ? !isDone : isDone;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_outlined, size: 72, color: Color(0xFFD6D3D1)),
            const SizedBox(height: 16),
            Text(
              active ? 'No Active Orders' : 'No Order History',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1917)),
            ),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'Your active orders will appear here.'
                  : 'Completed and cancelled orders will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF78716C)),
            ),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      color: _amber,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: filtered.map((o) => _OrderCard(order: o, mobile: _mobile, onRefresh: _load)).toList(),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String mobile;
  final VoidCallback? onRefresh;
  const _OrderCard({required this.order, required this.mobile, this.onRefresh});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _showBill = false;

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
      final isoZ = iso.endsWith('Z') ? iso : '${iso}Z';
      final dt = DateTime.parse(isoZ).toLocal();
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
    final order = widget.order;
    final status = order['status'] as String? ?? 'placed';
    final shortId = order['short_id'] as String? ?? '';
    final restaurant = order['restaurant_name'] as String? ?? '';
    final itemsCount = (order['items_count'] as int?) ?? 0;
    final createdAt = order['created_at'] as String?;
    final isDone = status == 'delivered' || status == 'cancelled';
    final items = (order['items'] as List<dynamic>?) ?? [];
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 20.0;
    final discountAmt = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final offerCode = order['offer_code'] as String? ?? '';
    final itemTotal = items.fold<double>(0.0, (sum, item) =>
        sum + ((item['price'] as num).toDouble() * (item['qty'] as num).toDouble()));
    final computedGst = double.parse(((itemTotal - discountAmt) * 0.05).toStringAsFixed(2));
    final grandTotal = (itemTotal - discountAmt) + deliveryFee + computedGst;

    return Container(
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
            // Header row: order id + status badge
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OrderStatusScreen(
                    orderId: order['order_id'] as String,
                    shortId: shortId,
                    total: grandTotal,
                  ),
                ));
                widget.onRefresh?.call();
              },
              child: Row(children: [
                Text('#$shortId',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1917))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBg[status] ?? const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel[status] ?? status,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: _statusColor[status] ?? _amber),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.restaurant, size: 14, color: Color(0xFF78716C)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(restaurant,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.fastfood_outlined, size: 14, color: Color(0xFF78716C)),
              const SizedBox(width: 5),
              Text('$itemsCount item${itemsCount == 1 ? '' : 's'}  •  ₹${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ]),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFFA8A29E)),
                const SizedBox(width: 5),
                Text(_formatDate(createdAt),
                    style: const TextStyle(fontSize: 12, color: Color(0xFFA8A29E))),
              ]),
            ],

            // View Bill toggle
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showBill = !_showBill),
              child: Row(children: [
                const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFF78716C)),
                const SizedBox(width: 4),
                Text(_showBill ? 'Hide Bill' : 'View Bill',
                    style: const TextStyle(
                        fontSize: 12, color: _amber, fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(_showBill ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: _amber),
              ]),
            ),

            // Expandable bill
            if (_showBill) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${item['qty']}×  ${item['name']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                          ),
                        ),
                        Text(
                          '₹${((item['price'] as num) * (item['qty'] as num)).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                        ),
                      ]),
                    ),
                  const Divider(height: 12),
                  if (discountAmt > 0) ...[
                    _BillLine('Item Subtotal', '₹${itemTotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 2),
                    _BillLine(
                      offerCode.isNotEmpty ? 'Offer Discount ($offerCode)' : 'Offer Discount',
                      '- ₹${discountAmt.toStringAsFixed(0)}',
                      color: const Color(0xFF16A34A),
                    ),
                    const Divider(height: 10),
                  ],
                  _BillLine('Total Food Cost', '₹${(itemTotal - discountAmt).toStringAsFixed(0)}', bold: true),
                  const SizedBox(height: 2),
                  _BillLine('Delivery fee', '₹${deliveryFee.toStringAsFixed(0)}'),
                  const SizedBox(height: 2),
                  _BillLine(
                    'GST (5% of Total Food Cost)',
                    '₹${computedGst.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 10),
                  _BillLine('Total', '₹${grandTotal.toStringAsFixed(0)}', bold: true),
                ]),
              ),
            ],

            // Track Order button (active only)
            if (!isDone) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OrderStatusScreen(
                        orderId: order['order_id'] as String,
                        shortId: shortId,
                        total: grandTotal,
                      ),
                    ));
                    widget.onRefresh?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Track Order',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _BillLine(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final defaultColor = bold ? const Color(0xFFD97706) : const Color(0xFF374151);
    return Row(children: [
      Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? const Color(0xFF374151)))),
      Text(value,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? defaultColor)),
    ]);
  }
}
