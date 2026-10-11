import 'dart:async';
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

  List<Map<String, dynamic>> _allOrders = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';
  String _dateFilter = 'today';
  Timer? _refreshTimer;
  DateTime? _customStart;
  DateTime? _customEnd;

  static const _statuses = [
    '',
    'placed',
    'accepted',
    'ready',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  static const _statusLabels = {
    '': 'All',
    'placed': 'New',
    'accepted': 'Accepted',
    'ready': 'Ready',
    'out_for_delivery': 'Out-for-Delivery',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  static const _dateOptions = [
    ('today', 'Today'),
    ('yesterday', 'Yesterday'),
    ('7days', 'Last 7 days'),
    ('30days', 'Last 30 days'),
    ('all', 'All time'),
    ('custom', 'Custom Range…'),
  ];

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final sevenDaysStart = todayStart.subtract(const Duration(days: 6));
    final thirtyDaysStart = todayStart.subtract(const Duration(days: 29));

    return _allOrders.where((o) {
      final raw = o['created_at'] as String? ?? '';
      // Backend stores UTC; add Z to parse correctly
      final rawUtc = raw.isNotEmpty && !raw.endsWith('Z') ? '${raw}Z' : raw;
      final dt = rawUtc.isEmpty ? null : DateTime.tryParse(rawUtc)?.toLocal();
      if (dt != null) {
        switch (_dateFilter) {
          case 'today':
            if (dt.isBefore(todayStart)) return false;
          case 'yesterday':
            if (dt.isBefore(yesterdayStart) || !dt.isBefore(todayStart))
              return false;
          case '7days':
            if (dt.isBefore(sevenDaysStart)) return false;
          case '30days':
            if (dt.isBefore(thirtyDaysStart)) return false;
          case 'custom':
            if (_customStart != null && dt.isBefore(_customStart!)) return false;
            if (_customEnd != null &&
                dt.isAfter(_customEnd!.add(const Duration(days: 1)))) {
              return false;
            }
        }
      }
      if (_statusFilter.isNotEmpty && o['status'] != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  String _fmtShort(DateTime d) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month]}';
  }

  String get _dateLabel {
    if (_dateFilter == 'custom' && _customStart != null && _customEnd != null) {
      return '${_fmtShort(_customStart!)} – ${_fmtShort(_customEnd!)}';
    }
    return _dateOptions.firstWhere((d) => d.$1 == _dateFilter).$2;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadSilent();
    });
  }

  Future<void> _loadSilent() async {
    try {
      final data = await ApiService.getOwnerOrders();
      if (mounted) setState(() { _allOrders = data; });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getOwnerOrders();
      if (mounted) setState(() { _allOrders = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Could not load orders.'; _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_today,
                size: 15, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text('Filter by date',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                        ),
                        for (final opt in _dateOptions)
                          ListTile(
                            title: Text(opt.$2),
                            trailing: _dateFilter == opt.$1
                                ? const Icon(Icons.check,
                                    color: Color(0xFF166534))
                                : null,
                            onTap: () => Navigator.pop(ctx, opt.$1),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
                if (picked == 'custom') {
                  final start = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                    helpText: 'Select start date',
                  );
                  if (start == null || !mounted) return;
                  final end = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: start,
                    lastDate: DateTime.now(),
                    helpText: 'Select end date',
                  );
                  if (end == null || !mounted) return;
                  setState(() {
                    _dateFilter = 'custom';
                    _customStart = start;
                    _customEnd = end;
                  });
                } else if (picked != null && mounted) {
                  setState(() => _dateFilter = picked);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_dateLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A))),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: Color(0xFF64748B)),
                ]),
              ),
            ),
            const Spacer(),
            Text(
              '${_filtered.length} order${_filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statuses.map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_statusLabels[s] ?? s),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = s),
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
        ],
      ),
    );
  }

  Widget _summaryBanner() {
    final billed = _filtered
        .where((o) => o['status'] != 'cancelled')
        .toList();
    if (billed.isEmpty) return const SizedBox.shrink();

    double grossRevenue = 0;
    double itemSubtotal = 0;
    for (final order in billed) {
      grossRevenue += (order['total'] as num?)?.toDouble() ?? 0;
      final items = order['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        itemSubtotal += (item['subtotal'] as num?)?.toDouble() ?? 0;
      }
    }
    final bbCut = itemSubtotal * 0.15;
    final ownerNet = itemSubtotal * 0.85;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('$_dateLabel Summary',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${billed.length} order${billed.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _SummaryItem(
                label: 'Gross Collected',
                value: '₹${grossRevenue.toStringAsFixed(0)}',
                valueColor: Colors.white),
            const SizedBox(width: 16),
            _SummaryItem(
                label: 'BB Tech (15%)',
                value: '-₹${bbCut.toStringAsFixed(0)}',
                valueColor: const Color(0xFFFCA5A5)),
            const SizedBox(width: 16),
            _SummaryItem(
                label: 'Your Earnings',
                value: '₹${ownerNet.toStringAsFixed(0)}',
                valueColor: const Color(0xFF86EFAC)),
          ]),
        ],
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
    final orders = _filtered;
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 56, color: Color(0xFFD6D3D1)),
            const SizedBox(height: 12),
            Text(
              _allOrders.isEmpty
                  ? 'No orders yet.'
                  : 'No orders for $_dateLabel.',
              style: const TextStyle(color: Color(0xFF78716C), fontSize: 15),
            ),
            if (_allOrders.isNotEmpty && _dateFilter != 'all') ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _dateFilter = 'all'),
                child: const Text('View all orders',
                    style: TextStyle(color: Color(0xFFD97706))),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _green,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: orders.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _summaryBanner();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _OrderCard(
              key: ValueKey(orders[i - 1]['id']),
              order: orders[i - 1],
              onStatusChanged: _load,
            ),
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SummaryItem(
      {required this.label,
      required this.value,
      required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStatusChanged;

  const _OrderCard({super.key, required this.order, required this.onStatusChanged});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;
  int _cancelSecondsLeft = 0;
  Timer? _cancelTimer;

  @override
  void initState() {
    super.initState();
    _startCancelCountdown();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _startCancelCountdown() {
    final status = widget.order['status'] as String;
    if (status != 'placed') return;
    final raw = widget.order['created_at'] as String? ?? '';
    if (raw.isEmpty) return;
    try {
      final createdAt = DateTime.parse(raw.endsWith('Z') ? raw : '${raw}Z');
      final elapsed = DateTime.now().toUtc().difference(createdAt).inSeconds;
      final remaining = 30 - elapsed;
      if (remaining <= 0) return;
      setState(() => _cancelSecondsLeft = remaining);
      _cancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _cancelSecondsLeft--;
          if (_cancelSecondsLeft <= 0) { _cancelSecondsLeft = 0; t.cancel(); }
        });
      });
    } catch (_) {}
  }

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
      case 'placed':           return const Color(0xFF2563EB);
      case 'accepted':         return const Color(0xFF166534);
      case 'ready':            return const Color(0xFFD97706);
      case 'out_for_delivery': return const Color(0xFF7C3AED);
      case 'delivered':        return const Color(0xFF15803D);
      case 'cancelled':        return const Color(0xFFDC2626);
      default:                 return const Color(0xFF64748B);
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'out_for_delivery': return 'Out for Delivery';
      default: return s[0].toUpperCase() + s.substring(1);
    }
  }

  Future<void> _advance(String orderId, String next) async {
    try {
      await ApiService.updateOrderStatus(orderId, next);
      widget.onStatusChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancel(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content:
            const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _advance(orderId, 'cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final id = order['id'] as String;
    final shortId =
        order['short_id'] as String? ?? id.substring(0, 8).toUpperCase();
    final status = order['status'] as String;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final name = order['customer_name'] as String? ?? '';
    final phone = order['customer_phone'] as String? ?? '';
    final address = order['delivery_address'] as String? ?? '';
    final items = order['items'] as List<dynamic>? ?? [];
    final notes = order['notes'] as String?;

    final nextSt = _nextStatus[status];
    final canCancel = status == 'placed';

    // Bill breakdown
    double itemSubtotal = 0;
    for (final item in items) {
      itemSubtotal += (item['subtotal'] as num?)?.toDouble() ?? 0;
    }
    final discountAmount = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final offerCode = (order['offer_code'] as String?) ?? '';
    final discountedItemTotal = itemSubtotal - discountAmount;
    const deliveryFee = 20.0;
    final gst = double.parse((discountedItemTotal * 0.05).toStringAsFixed(2));
    final bbCut = double.parse((discountedItemTotal * 0.15).toStringAsFixed(2));
    final ownerNet = double.parse((discountedItemTotal * 0.85).toStringAsFixed(2));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (always visible, tappable to expand) ──────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: _expanded
                      ? Radius.zero
                      : const Radius.circular(12),
                ),
                border: _expanded
                    ? const Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)))
                    : null,
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #$shortId',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A))),
                        Text('$name · $phone',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B))),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                  const SizedBox(height: 4),
                  Text('₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534))),
                ]),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
              ]),
            ),
          ),

          // ── Always-visible advance button ─────────────────────────
          if (nextSt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: Builder(builder: (_) {
                  final blocked = status == 'placed' && _cancelSecondsLeft > 0;
                  return ElevatedButton(
                    onPressed: blocked ? null : () => _advance(id, nextSt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blocked
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      disabledForegroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      blocked
                          ? 'Accept (${_cancelSecondsLeft}s)'
                          : (_nextLabel[status] ?? 'Advance'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
              ),
            ),

          // ── Expanded body ─────────────────────────────────────────
          if (_expanded) ...[
            // Items list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Items',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
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
                  ]),
            ),

            // Bill breakdown
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                _BillRow('Item Subtotal', '₹${itemSubtotal.toStringAsFixed(0)}'),
                if (discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  _BillRow(
                      offerCode.isNotEmpty
                          ? 'Offer Discount ($offerCode)'
                          : 'Offer Discount',
                      '-₹${discountAmount.toStringAsFixed(0)}',
                      valueColor: const Color(0xFF166534)),
                ],
                const SizedBox(height: 4),
                _BillRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(0)}'),
                const SizedBox(height: 4),
                _BillRow('GST (5%)', '₹${gst.toStringAsFixed(2)}'),
                const Divider(height: 14),
                _BillRow('Customer Paid', '₹${total.toStringAsFixed(0)}',
                    bold: true),
                const Divider(height: 14),
                _BillRow('BossBite Platform Fee (15%)',
                    '-₹${bbCut.toStringAsFixed(0)}',
                    valueColor: const Color(0xFFDC2626)),
                const SizedBox(height: 4),
                _BillRow('Your Earnings (85%)',
                    '₹${ownerNet.toStringAsFixed(0)}',
                    bold: true,
                    valueColor: const Color(0xFF166534)),
              ]),
            ),

            // Address + notes
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Icon(Icons.note_outlined,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(notes,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B)))),
                  ]),
                ],
              ]),
            ),

            // Cancel button (inside expanded only — destructive action)
            if (canCancel)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _cancel(id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel Order'),
                  ),
                ),
              ),
            if (!canCancel)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

Widget _BillRow(String label, String value,
    {bool bold = false, Color? valueColor}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: bold ? 13 : 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF374151))),
      Text(value,
          style: TextStyle(
              fontSize: bold ? 13 : 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: valueColor ?? const Color(0xFF374151))),
    ],
  );
}
