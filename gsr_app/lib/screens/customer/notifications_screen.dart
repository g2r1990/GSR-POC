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
      // Mark all as read after fetching
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

  String _timeAgo(String? isoStr) {
    if (isoStr == null) return '';
    try {
      final dt = DateTime.parse('${isoStr}Z').toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _notifications.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No notifications yet',
                        style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    const Text(
                        'You\'ll be notified here when a restaurant you\'re\nwaiting for comes back online.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadAndMarkRead,
                  color: _amber,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final isUnread = n['is_read'] == false;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUnread
                              ? const Color(0xFFFFFBEB)
                              : Colors.white,
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
                                      _timeAgo(n['created_at'] as String?),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    n['message'] as String? ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF374151)),
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
                      );
                    },
                  ),
                ),
    );
  }
}
