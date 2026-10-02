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

  String _dateFilter = 'month';
  DateTime? _customStart;
  DateTime? _customEnd;

  static const _dateOptions = [
    ('today', 'Today'),
    ('yesterday', 'Yesterday'),
    ('week', 'This Week'),
    ('month', 'This Month'),
    ('all', 'All Time'),
    ('custom', 'Custom'),
  ];

  static const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _orders.where((o) {
      if (o['status'] != 'delivered') return false;
      final raw = o['created_at'] as String? ?? '';
      final rawUtc = raw.isNotEmpty && !raw.endsWith('Z') ? '${raw}Z' : raw;
      final dt = rawUtc.isEmpty ? null : DateTime.tryParse(rawUtc)?.toLocal();
      if (dt == null) return _dateFilter == 'all';
      switch (_dateFilter) {
        case 'today':
          return !dt.isBefore(todayStart);
        case 'yesterday':
          final yd = todayStart.subtract(const Duration(days: 1));
          return !dt.isBefore(yd) && dt.isBefore(todayStart);
        case 'week':
          return !dt.isBefore(todayStart.subtract(const Duration(days: 6)));
        case 'month':
          return !dt.isBefore(todayStart.subtract(const Duration(days: 29)));
        case 'custom':
          if (_customStart != null && dt.isBefore(_customStart!)) return false;
          if (_customEnd != null &&
              dt.isAfter(_customEnd!.add(const Duration(days: 1)))) return false;
          return true;
        default:
          return true;
      }
    }).toList();
  }

  String _fmtShort(DateTime d) =>
      '${d.day} ${_months[d.month]}';

  String get _filterLabel {
    if (_dateFilter == 'custom' && _customStart != null && _customEnd != null) {
      return '${_fmtShort(_customStart!)} – ${_fmtShort(_customEnd!)}';
    }
    return _dateOptions.firstWhere((d) => d.$1 == _dateFilter).$2;
  }

  Future<void> _onFilterTap(String key) async {
    if (key != 'custom') {
      setState(() { _dateFilter = key; _customStart = null; _customEnd = null; });
      return;
    }
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
    setState(() { _dateFilter = 'custom'; _customStart = start; _customEnd = end; });
  }

  // ── Computed values ──────────────────────────────────────────────────────────

  double _itemSubtotal(Map<String, dynamic> order) {
    final items = (order['items'] as List?) ?? [];
    return items.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + price * qty;
    });
  }

  double get _totalSales {
    return _filtered.fold(0.0, (sum, o) {
      final sub = _itemSubtotal(o);
      return sum + sub + 20.0 + sub * 0.05;
    });
  }

  double get _totalItemSubtotal =>
      _filtered.fold(0.0, (sum, o) => sum + _itemSubtotal(o));

  double get _totalGst =>
      double.parse((_totalItemSubtotal * 0.05).toStringAsFixed(2));
  double get _restaurantProfit =>
      double.parse((_totalItemSubtotal * 0.85).toStringAsFixed(2));
  double get _bbTechFee =>
      double.parse((_totalItemSubtotal * 0.15).toStringAsFixed(2));
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Date filter chips ─────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _dateOptions.map((opt) {
              final isSelected = _dateFilter == opt.$1;
              final chipLabel = (opt.$1 == 'custom' && _dateFilter == 'custom' &&
                      _customStart != null && _customEnd != null)
                  ? _filterLabel
                  : opt.$2;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(chipLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF374151))),
                  selected: isSelected,
                  onSelected: (_) => _onFilterTap(opt.$1),
                  selectedColor: _purple,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                      color: isSelected
                          ? _purple
                          : const Color(0xFFEDE9FE)),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _filtered.isEmpty
              ? 'No delivered orders in this period'
              : '${_filtered.length} delivered order${_filtered.length == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 16),

        // ── 4 key tiles ───────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _KpiTile(
              icon: Icons.currency_rupee,
              label: 'Total Sales',
              value: '₹${_totalSales.toStringAsFixed(0)}',
              sub: 'Gross collected',
              color: _purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiTile(
              icon: Icons.receipt_long,
              label: 'Total GST',
              value: '₹${_totalGst.toStringAsFixed(0)}',
              sub: '5% of item subtotal',
              color: const Color(0xFFD97706),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _KpiTile(
              icon: Icons.store,
              label: 'Restaurant Profit',
              value: '₹${_restaurantProfit.toStringAsFixed(0)}',
              sub: '85% of subtotal',
              color: const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiTile(
              icon: Icons.phone_android,
              label: 'BossBite Platform Fee',
              value: '₹${_bbTechFee.toStringAsFixed(0)}',
              sub: '15% of subtotal',
              color: const Color(0xFF7C3AED),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        Text(sub,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ]),
    );
  }
}

