import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OwnerOrdersScreen extends StatefulWidget {
  const OwnerOrdersScreen({super.key});

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  static const _amber = Color(0xFFD97706);
  static const _green = Color(0xFF166534);

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  String _filter = '';

  static const _statuses = [
    '',
    'placed',
    'accepted',
    'ready',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  static const _labels = {
    '': 'All',
    'placed': 'New',
    'accepted': 'Accepted',
    'ready': 'Ready',
    'out_for_delivery': 'Out',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getOwnerOrders(statusFilter: _filter);
      if (mounted) setState(() { _orders = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Could not load orders.'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _statuses.map((s) {
            final selected = _filter == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_labels[s] ?? s),
                selected: selected,
                onSelected: (_) {
                  setState(() => _filter = s);
                  _load();
                },
                selectedColor: const Color(0xFFDCFCE7),
                checkmarkColor: _green,
                labelStyle: TextStyle(
                  color: selected ? _green : const Color(0xFF64748B),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: Color(0xFFD6D3D1)),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF78716C))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Color(0xFFD6D3D1)),
            SizedBox(height: 12),
            Text('No orders yet.',
                style: TextStyle(color: Color(0xFF78716C), fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _green,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (ctx, i) => _OrderCard(
          order: _orders[i],
          onStatusChanged: _load,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStatusChanged;

  const _OrderCard({required this.order, required this.onStatusChanged});

  static const _nextStatus = {
    'placed': 'accepted',
    'accepted': 'ready',
    'ready': 'out_for_delivery',
    'out_for_delivery': 'delivered',
  };

  static const _nextLabel = {
    'placed': 'Accept',
    'accepted': 'Mark Ready',
    'ready': 'Out for Delivery',
    'out_for_delivery': 'Mark Delivered',
  };

  static Color _statusColor(String s) {
    switch (s) {
      case 'placed':      return const Color(0xFF2563EB);
      case 'accepted':    return const Color(0xFF166534);
      case 'ready':       return const Color(0xFFD97706);
      case 'out_for_delivery': return const Color(0xFF7C3AED);
      case 'delivered':   return const Color(0xFF15803D);
      case 'cancelled':   return const Color(0xFFDC2626);
      default:            return const Color(0xFF64748B);
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'out_for_delivery': return 'Out for Delivery';
      default: return s[0].toUpperCase() + s.substring(1);
    }
  }

  Future<void> _advance(BuildContext context, String orderId, String next) async {
    try {
      await ApiService.updateOrderStatus(orderId, next);
      onStatusChanged();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancel(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await _advance(context, orderId, 'cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as String;
    final shortId = order['short_id'] as String? ?? id.substring(0, 8).toUpperCase();
    final status = order['status'] as String;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final name = order['customer_name'] as String? ?? '';
    final phone = order['customer_phone'] as String? ?? '';
    final address = order['delivery_address'] as String? ?? '';
    final items = order['items'] as List<dynamic>? ?? [];
    final notes = order['notes'] as String?;

    final nextSt = _nextStatus[status];
    final canCancel = status == 'placed' || status == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Order #$shortId',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  Text('$name • $phone',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status)),
                ),
              ),
            ]),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${item['qty']}× ${item['name']}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151)),
                      ),
                    ),
                    Text(
                      '₹${(item['subtotal'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ]),
                ),
              const Divider(height: 16),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(address,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)))),
              ]),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.note_outlined,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(notes,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)))),
                ]),
              ],
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                Text('₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534))),
              ]),
            ]),
          ),

          // Actions
          if (nextSt != null || canCancel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                if (canCancel) ...[
                  OutlinedButton(
                    onPressed: () => _cancel(context, id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (nextSt != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _advance(context, id, nextSt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF166534),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_nextLabel[status] ?? 'Advance'),
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}
