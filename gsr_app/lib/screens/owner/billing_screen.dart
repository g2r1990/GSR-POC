import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OwnerBillingScreen extends StatefulWidget {
  const OwnerBillingScreen({super.key});

  @override
  State<OwnerBillingScreen> createState() => _OwnerBillingScreenState();
}

class _OwnerBillingScreenState extends State<OwnerBillingScreen> {
  static const _purple = Color(0xFF7C3AED);

  List<Map<String, dynamic>> _orders = [];
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
      final orders = await ApiService.getOwnerOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load billing data.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _delivered =>
      _orders.where((o) => o['status'] == 'delivered').toList();

  // Item subtotal only (excludes delivery + GST) — base for commission calc
  double _itemSubtotal(Map<String, dynamic> order) {
    final items = (order['items'] as List?) ?? [];
    return items.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + price * qty;
    });
  }

  double get _grossRevenue {
    return _delivered.fold(0.0, (sum, o) {
      final sub = _itemSubtotal(o);
      final deliveryFee = 20.0;
      final gst = sub * 0.05;
      return sum + sub + deliveryFee + gst;
    });
  }

  double get _totalItemSubtotal =>
      _delivered.fold(0.0, (sum, o) => sum + _itemSubtotal(o));

  double get _bbTechShare => double.parse((_totalItemSubtotal * 0.15).toStringAsFixed(2));
  double get _ownerEarnings => double.parse((_totalItemSubtotal * 0.85).toStringAsFixed(2));
  double get _totalDeliveryFees => _delivered.length * 20.0;
  double get _totalGst => double.parse((_totalItemSubtotal * 0.05).toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        title: const Text('Billing & Revenue'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _body(),
                ),
    );
  }

  Widget _body() {
    final count = _delivered.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero stat card
        _StatCard(
          icon: Icons.receipt_long,
          label: 'Total Delivered Orders',
          value: '$count',
          color: _purple,
        ),
        const SizedBox(height: 12),

        // Revenue breakdown
        _SectionHeader(title: 'Revenue Breakdown', subtitle: 'All-time, delivered orders only'),
        const SizedBox(height: 8),

        _DetailCard(
          rows: [
            _Row('Gross Collected', '₹${_grossRevenue.toStringAsFixed(2)}',
                bold: true),
            _Row('  Item Subtotal', '₹${_totalItemSubtotal.toStringAsFixed(2)}'),
            _Row('  Delivery Fees', '₹${_totalDeliveryFees.toStringAsFixed(2)}'),
            _Row('  GST (5%)', '₹${_totalGst.toStringAsFixed(2)}'),
          ],
        ),
        const SizedBox(height: 12),

        // Commission split
        _SectionHeader(title: 'Commission Split', subtitle: 'Based on item subtotal (excl. delivery & GST)'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _StatCard(
              icon: Icons.store,
              label: 'Your Earnings\n(85%)',
              value: '₹${_ownerEarnings.toStringAsFixed(0)}',
              color: const Color(0xFF059669),
              small: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.phone_android,
              label: 'BB Tech Share\n(15%)',
              value: '₹${_bbTechShare.toStringAsFixed(0)}',
              color: const Color(0xFF7C3AED),
              small: true,
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Per-order commission strip
        if (count > 0) ...[
          _SectionHeader(title: 'Per-Order Averages', subtitle: ''),
          const SizedBox(height: 8),
          _DetailCard(
            rows: [
              _Row('Avg order value',
                  '₹${(_grossRevenue / count).toStringAsFixed(2)}'),
              _Row('Avg item subtotal',
                  '₹${(_totalItemSubtotal / count).toStringAsFixed(2)}'),
              _Row('Avg your earnings',
                  '₹${(_ownerEarnings / count).toStringAsFixed(2)}'),
              _Row('Avg BB Tech fee',
                  '₹${(_bbTechShare / count).toStringAsFixed(2)}'),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151))),
      if (subtitle.isNotEmpty)
        Text(subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool small;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: small ? 11 : 12,
                    color: const Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: small ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
        ),
      ]),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<_Row> rows;
  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: idx < rows.length - 1
                  ? const Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6)))
                  : null,
            ),
            child: Row(children: [
              Expanded(
                child: Text(row.label,
                    style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                        fontWeight: row.bold
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
              Text(row.amount,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: row.bold
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: const Color(0xFF1C1917))),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _Row {
  final String label;
  final String amount;
  final bool bold;
  const _Row(this.label, this.amount, {this.bold = false});
}
