import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OwnerStatsScreen extends StatefulWidget {
  const OwnerStatsScreen({super.key});

  @override
  State<OwnerStatsScreen> createState() => _OwnerStatsScreenState();
}

class _OwnerStatsScreenState extends State<OwnerStatsScreen> {
  static const _amber = Color(0xFFD97706);

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
      if (mounted) setState(() { _error = 'Could not load stats.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _delivered =>
      _orders.where((o) => o['status'] == 'delivered').toList();

  // Item name → total qty sold
  Map<String, int> get _itemQtyMap {
    final map = <String, int>{};
    for (final order in _delivered) {
      final items = (order['items'] as List?) ?? [];
      for (final item in items) {
        final name = item['name'] as String? ?? 'Unknown';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        map[name] = (map[name] ?? 0) + qty;
      }
    }
    return map;
  }

  // Hour (0–23) → order count
  Map<int, int> get _hourlyMap {
    final map = <int, int>{};
    for (final order in _delivered) {
      final createdAt = order['created_at'] as String?;
      if (createdAt == null) continue;
      try {
        final dt = DateTime.parse('${createdAt}Z').toLocal();
        map[dt.hour] = (map[dt.hour] ?? 0) + 1;
      } catch (_) {}
    }
    return map;
  }

  int get _totalItemsSold {
    return _itemQtyMap.values.fold(0, (a, b) => a + b);
  }

  double get _avgOrderValue {
    final d = _delivered;
    if (d.isEmpty) return 0;
    double total = 0;
    for (final order in d) {
      final items = (order['items'] as List?) ?? [];
      double sub = 0;
      for (final item in items) {
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        sub += price * qty;
      }
      total += sub + 20 + sub * 0.05; // delivery + GST
    }
    return total / d.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Food Stats'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
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
                  color: _amber,
                  child: _body(),
                ),
    );
  }

  Widget _body() {
    if (_delivered.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart, size: 64, color: Color(0xFFD6D3D1)),
          SizedBox(height: 16),
          Text('No delivered orders yet',
              style: TextStyle(fontSize: 16, color: Color(0xFF78716C))),
          SizedBox(height: 8),
          Text('Stats will appear once orders are delivered.',
              style: TextStyle(fontSize: 13, color: Color(0xFFA8A29E))),
        ]),
      );
    }

    final itemMap = _itemQtyMap;
    final sortedItems = itemMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(10).toList();
    final maxQty = topItems.isEmpty ? 1 : topItems.first.value;

    final hourlyMap = _hourlyMap;
    // Show 6 AM to 11 PM
    final hours = List.generate(18, (i) => i + 6);
    final maxHourly = hours.isEmpty
        ? 1
        : hours.map((h) => hourlyMap[h] ?? 0).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Summary tiles
        Row(children: [
          Expanded(
            child: _StatTile(
              icon: Icons.shopping_bag_outlined,
              label: 'Items Sold',
              value: '$_totalItemsSold',
              color: _amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.receipt_outlined,
              label: 'Orders',
              value: '${_delivered.length}',
              color: const Color(0xFF7C3AED),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatTile(
              icon: Icons.trending_up,
              label: 'Avg Order Value',
              value: '₹${_avgOrderValue.toStringAsFixed(0)}',
              color: const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.menu_book_outlined,
              label: 'Unique Items',
              value: '${itemMap.length}',
              color: const Color(0xFFDC2626),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Top Selling Items
        if (topItems.isNotEmpty) ...[
          const _SectionTitle('🏆 Top Selling Items'),
          const SizedBox(height: 10),
          ...topItems.asMap().entries.map((e) {
            final rank = e.key + 1;
            final name = e.value.key;
            final qty = e.value.value;
            final pct = maxQty == 0 ? 0.0 : qty / maxQty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ItemBar(
                rank: rank,
                name: name,
                qty: qty,
                pct: pct,
                isTop: rank == 1,
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Hourly Order Volume
        const _SectionTitle('⏰ Hourly Order Volume'),
        const SizedBox(height: 6),
        const Text('Orders by hour (IST), delivered orders',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 12),
        _HourlyChart(
          hours: hours,
          hourlyMap: hourlyMap,
          maxValue: maxHourly == 0 ? 1 : maxHourly,
        ),
      ],
    );
  }
}

// ── Bar for top items ──────────────────────────────────────────────────────────

class _ItemBar extends StatelessWidget {
  static const _amber = Color(0xFFD97706);
  final int rank;
  final String name;
  final int qty;
  final double pct;
  final bool isTop;

  const _ItemBar({
    required this.rank,
    required this.name,
    required this.qty,
    required this.pct,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final color = isTop ? _amber : const Color(0xFF7C3AED).withOpacity(0.7);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isTop
                ? const Color(0xFFFDE68A)
                : const Color(0xFFEDE9FE)),
      ),
      child: Row(children: [
        SizedBox(
          width: 24,
          child: Text('$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isTop ? _amber : const Color(0xFF9CA3AF))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1917))),
              ),
              Text('$qty sold',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ]),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (ctx, constraints) {
              return Stack(children: [
                Container(
                  height: 6,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 6,
                  width: constraints.maxWidth * pct,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ]);
            }),
          ]),
        ),
      ]),
    );
  }
}

// ── Hourly bar chart ──────────────────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  final List<int> hours;
  final Map<int, int> hourlyMap;
  final int maxValue;

  const _HourlyChart({
    required this.hours,
    required this.hourlyMap,
    required this.maxValue,
  });

  String _label(int h) {
    if (h == 0) return '12A';
    if (h < 12) return '${h}A';
    if (h == 12) return '12P';
    return '${h - 12}P';
  }

  @override
  Widget build(BuildContext context) {
    const barWidth = 18.0;
    const maxBarHeight = 80.0;
    const _amber = Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: hours.map((h) {
            final count = hourlyMap[h] ?? 0;
            final barH = maxValue == 0
                ? 0.0
                : (count / maxValue) * maxBarHeight;
            final isPeak = count == maxValue && count > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (count > 0)
                    Text('$count',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPeak ? _amber : const Color(0xFF6B7280))),
                  const SizedBox(height: 2),
                  Container(
                    width: barWidth,
                    height: barH.clamp(2.0, maxBarHeight),
                    decoration: BoxDecoration(
                      color: isPeak
                          ? _amber
                          : const Color(0xFF7C3AED).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_label(h),
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEF3C7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7280))),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1917)));
  }
}
