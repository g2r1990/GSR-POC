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
  List<Map<String, dynamic>> _menuItems = [];
  bool _loading = true;
  String? _error;

  // Collapse/expand state for sections
  bool _topExpanded = true;
  bool _bottomExpanded = true;
  bool _unsoldExpanded = true;

  String _dateFilter = 'week';
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
      List<Map<String, dynamic>> menuItems = [];
      try {
        menuItems = (await ApiService.getMenu())
            .where((e) => e['is_deleted'] != true)
            .toList();
      } catch (_) {}
      if (mounted) setState(() {
        _orders = orders;
        _menuItems = menuItems;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load stats.'; _loading = false; });
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

  String _fmtShort(DateTime d) => '${d.day} ${_months[d.month]}';

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

  Map<String, int> get _itemQtyMap {
    final map = <String, int>{};
    for (final order in _filtered) {
      final items = (order['items'] as List?) ?? [];
      for (final item in items) {
        final name = item['name'] as String? ?? 'Unknown';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        map[name] = (map[name] ?? 0) + qty;
      }
    }
    return map;
  }

  Map<String, int> get _areaMap {
    final map = <String, int>{};
    for (final order in _filtered) {
      final area = (order['customer_area'] as String?)?.trim();
      final key = (area == null || area.isEmpty) ? 'Unknown' : area;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<int, int> get _hourlyMap {
    final map = <int, int>{};
    for (final order in _filtered) {
      final createdAt = order['created_at'] as String?;
      if (createdAt == null) continue;
      try {
        final dt = DateTime.parse('${createdAt}Z').toLocal();
        map[dt.hour] = (map[dt.hour] ?? 0) + 1;
      } catch (_) {}
    }
    return map;
  }

  int get _totalItemsSold =>
      _itemQtyMap.values.fold(0, (a, b) => a + b);

  double get _avgOrderValue {
    final d = _filtered;
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
      total += sub + 20 + sub * 0.05;
    }
    return total / d.length;
  }

  // Peak hour: hour with the most orders, formatted as "2 PM"
  String get _peakHour {
    final map = _hourlyMap;
    if (map.isEmpty) return '–';
    final peak = map.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    if (peak == 0) return '12 AM';
    if (peak < 12) return '$peak AM';
    if (peak == 12) return '12 PM';
    return '${peak - 12} PM';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Date filter chips ─────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _dateOptions.map((opt) {
              final isSelected = _dateFilter == opt.$1;
              final chipLabel = (opt.$1 == 'custom' &&
                      _dateFilter == 'custom' &&
                      _customStart != null &&
                      _customEnd != null)
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
                  selectedColor: _amber,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                      color: isSelected
                          ? _amber
                          : const Color(0xFFFDE68A)),
                  showCheckmark: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_filtered.length} delivered order${_filtered.length == 1 ? '' : 's'} · $_filterLabel',
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 16),

        // ── Summary tiles (3 tiles — removed Unique Items) ────────────────────
        if (_filtered.isEmpty) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart, size: 64, color: Color(0xFFD6D3D1)),
                SizedBox(height: 16),
                Text('No delivered orders in this period',
                    style: TextStyle(fontSize: 15, color: Color(0xFF78716C))),
                SizedBox(height: 6),
                Text('Try a different date range.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFA8A29E))),
              ]),
            ),
          ),
        ] else ...[
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
                value: '${_filtered.length}',
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
                icon: Icons.schedule,
                label: 'Peak Hour',
                value: _peakHour,
                color: const Color(0xFFDC2626),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Top Selling Items ───────────────────────────────────────────────
          ..._buildTopItems(),
          const SizedBox(height: 20),

          // ── Least Selling Items ─────────────────────────────────────────────
          ..._buildBottomItems(),
          const SizedBox(height: 20),

          // ── Unsold Items ────────────────────────────────────────────────────
          ..._buildUnsoldItems(),
          const SizedBox(height: 20),

          // ── Orders by Area ──────────────────────────────────────────────────
          ..._buildAreaChart(),
          const SizedBox(height: 20),

          // ── Hourly Order Volume ─────────────────────────────────────────────
          ..._buildHourlyChart(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool expanded, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: _amber,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopItems() {
    final itemMap = _itemQtyMap;
    if (itemMap.isEmpty) return [];
    final sorted = itemMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sorted.take(10).toList();
    final maxQty = topItems.first.value;

    final items = topItems.asMap().entries.map((e) {
      final rank = e.key + 1;
      final name = e.value.key;
      final qty = e.value.value;
      final pct = maxQty == 0 ? 0.0 : qty / maxQty;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ItemBar(rank: rank, name: name, qty: qty, pct: pct, isTop: rank == 1),
      );
    }).toList();

    return [
      _buildSectionHeader('🏆 Top Selling Items', _topExpanded,
          () => setState(() => _topExpanded = !_topExpanded)),
      if (_topExpanded) ...[
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(children: items),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildBottomItems() {
    final itemMap = _itemQtyMap;
    if (itemMap.length < 2) return [];
    final sorted = itemMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final bottomItems = sorted.take(10).toList();
    final maxQty = bottomItems.last.value;

    final items = bottomItems.asMap().entries.map((e) {
      final rank = e.key + 1;
      final name = e.value.key;
      final qty = e.value.value;
      final pct = maxQty == 0 ? 0.0 : qty / maxQty;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ItemBar(rank: rank, name: name, qty: qty, pct: pct, isTop: false,
            barColor: const Color(0xFF64748B)),
      );
    }).toList();

    return [
      _buildSectionHeader('📉 Least Selling Items', _bottomExpanded,
          () => setState(() => _bottomExpanded = !_bottomExpanded)),
      if (_bottomExpanded) ...[
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(children: items),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildUnsoldItems() {
    if (_menuItems.isEmpty) return [];
    final soldNames = _itemQtyMap.keys.map((n) => n.toLowerCase()).toSet();
    final unsold = _menuItems
        .where((m) =>
            m['is_available'] == true &&
            !(soldNames.contains((m['name'] as String? ?? '').toLowerCase())))
        .map((m) => m['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (unsold.isEmpty) return [];

    final tiles = unsold.map((name) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
          ),
          const Text('0 sold',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
      ),
    )).toList();

    return [
      _buildSectionHeader('🚫 Unsold Items (${unsold.length})', _unsoldExpanded,
          () => setState(() => _unsoldExpanded = !_unsoldExpanded)),
      if (_unsoldExpanded) ...[
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(children: tiles),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildAreaChart() {
    final areaMap = _areaMap;
    if (areaMap.isEmpty) return [];
    final sorted = areaMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxOrders = sorted.first.value;

    final items = sorted.map((e) {
      final pct = maxOrders == 0 ? 0.0 : e.value / maxOrders;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0F2FE)),
          ),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF0891B2)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(e.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A))),
                  ),
                  Text('${e.value} order${e.value == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: Color(0xFF0891B2))),
                ]),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (ctx, constraints) {
                  return Stack(children: [
                    Container(height: 5, width: constraints.maxWidth,
                        decoration: BoxDecoration(color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4))),
                    Container(height: 5, width: constraints.maxWidth * pct,
                        decoration: BoxDecoration(color: const Color(0xFF0891B2),
                            borderRadius: BorderRadius.circular(4))),
                  ]);
                }),
              ]),
            ),
          ]),
        ),
      );
    }).toList();

    return [
      const _SectionTitle('📍 Orders by Area'),
      const SizedBox(height: 10),
      Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(children: items),
        ),
      ),
    ];
  }

  List<Widget> _buildHourlyChart() {
    final hourlyMap = _hourlyMap;
    final hours = List.generate(18, (i) => i + 6); // 6 AM to 11 PM
    final maxHourly = hours.map((h) => hourlyMap[h] ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return [
      const _SectionTitle('⏰ Hourly Order Volume'),
      const SizedBox(height: 6),
      Text('Orders by hour (IST) · $_filterLabel',
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 12),
      _HourlyChart(
        hours: hours,
        hourlyMap: hourlyMap,
        maxValue: maxHourly == 0 ? 1 : maxHourly,
      ),
    ];
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
  final Color? barColor;

  const _ItemBar({
    required this.rank,
    required this.name,
    required this.qty,
    required this.pct,
    required this.isTop,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = barColor ??
        (isTop ? _amber : const Color(0xFF7C3AED).withOpacity(0.7));
    final borderColor = barColor != null
        ? const Color(0xFFE2E8F0)
        : (isTop ? const Color(0xFFFDE68A) : const Color(0xFFEDE9FE));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
    const amber = Color(0xFFD97706);

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
                            color: isPeak ? amber : const Color(0xFF6B7280))),
                  const SizedBox(height: 2),
                  Container(
                    width: barWidth,
                    height: barH.clamp(2.0, maxBarHeight),
                    decoration: BoxDecoration(
                      color: isPeak
                          ? amber
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
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
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
