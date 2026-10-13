import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  final String mobile;
  final List<Map<String, dynamic>> initialNotifications;

  const CustomerNotificationsScreen({
    super.key,
    required this.mobile,
    this.initialNotifications = const [],
  });

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  static const _amber = Color(0xFFD97706);

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _notifications = List.from(widget.initialNotifications);
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    setState(() => _loading = _notifications.isEmpty);
    try {
      final notifs = await ApiService.getCustomerNotifications(widget.mobile);
      if (mounted) setState(() { _notifications = notifs; _loading = false; });
      await ApiService.markNotificationsRead(widget.mobile);
      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n['is_read'] = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAll() async {
    try {
      await ApiService.markNotificationsRead(widget.mobile);
    } catch (_) {}
    if (mounted) setState(() => _notifications = []);
  }

  DateTime? _parseDate(String? isoStr) {
    if (isoStr == null) return null;
    try {
      final s = isoStr.endsWith('Z') ? isoStr : '${isoStr}Z';
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _timeAgo(String? isoStr) {
    final dt = _parseDate(isoStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedByDay() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _notifications.where((n) {
      final dt = _parseDate(n['created_at'] as String?);
      return dt != null && dt.isAfter(cutoff);
    }).toList();

    final Map<String, List<Map<String, dynamic>>> groups = {};
    final List<String> order = [];
    for (final n in recent) {
      final dt = _parseDate(n['created_at'] as String?)!;
      final label = _dayLabel(dt);
      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(n);
    }
    return order.map((k) => MapEntry(k, groups[k]!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedByDay();
    final hasVisible = groups.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (hasVisible)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear All',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : !hasVisible
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No notifications',
                        style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    const Text(
                        'Notifications from the last 7 days appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadAndMarkRead,
                  color: _amber,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: groups.length,
                    itemBuilder: (context, gi) {
                      final label = groups[gi].key;
                      final items = groups[gi].value;
                      return _DayGroup(
                        label: label,
                        initiallyExpanded: label == 'Today',
                        items: items,
                        timeAgo: _timeAgo,
                      );
                    },
                  ),
                ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final String label;
  final bool initiallyExpanded;
  final List<Map<String, dynamic>> items;
  final String Function(String?) timeAgo;

  const _DayGroup({
    required this.label,
    required this.initiallyExpanded,
    required this.items,
    required this.timeAgo,
  });

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final unreadCount = items.where((n) => n['is_read'] == false).length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        title: Row(children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3),
          ),
          const SizedBox(width: 8),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _amber,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ]),
        children: [
          ...items.map((n) {
            final isUnread = n['is_read'] == false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUnread ? const Color(0xFFFFFBEB) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnread
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant,
                          color: _amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                n['restaurant_name'] as String? ?? '',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: const Color(0xFF111827)),
                              ),
                            ),
                            Text(
                              timeAgo(n['created_at'] as String?),
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            n['message'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF374151)),
                          ),
                        ],
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _amber, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
