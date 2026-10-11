import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'menu_list_screen.dart';
import 'orders_screen.dart';
import 'offers_screen.dart';
import 'billing_screen.dart';
import 'stats_screen.dart';
import 'owner_profile_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final String ownerName;
  const OwnerDashboardScreen({super.key, required this.ownerName});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _menuCount = 0;
  int _activeOrders = 0;
  bool _loading = true;
  Timer? _refreshTimer;

  bool _isAccepting = true;
  DateTime? _backOnlineAt;
  bool _availLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAvailability();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    try {
      final data = await ApiService.getRestaurantAvailability();
      if (mounted) {
        setState(() {
          _isAccepting = data['is_accepting_orders'] as bool? ?? true;
          final raw = data['back_online_at'] as String?;
          if (raw != null) {
            final utcStr = (raw.endsWith('Z') || raw.contains('+')) ? raw : '${raw}Z';
            _backOnlineAt = DateTime.tryParse(utcStr)?.toLocal();
          } else {
            _backOnlineAt = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAvailability(bool value) async {
    if (_availLoading) return;
    if (!value) {
      // Step 1: Today or Custom date
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('When will you be back?'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.today, color: Color(0xFFD97706)),
              title: const Text('Later today'),
              subtitle: const Text('Pick a time today'),
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFF7C3AED)),
              title: const Text('Custom date & time'),
              subtitle: const Text('Pick a future date and time'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ]),
        ),
      );
      if (choice == null || !mounted) return;

      DateTime? backAt;
      if (choice == 'today') {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          helpText: 'Back online by (today)',
        );
        if (picked != null) {
          final now = DateTime.now();
          backAt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
          if (backAt.isBefore(now)) backAt = backAt.add(const Duration(days: 1));
        }
      } else {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          helpText: 'Select date',
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          helpText: 'Select time',
        );
        if (time != null) {
          backAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (backAt.isBefore(DateTime.now())) backAt = null;
        }
      }
      setState(() { _availLoading = true; });
      try {
        await ApiService.setRestaurantAvailability(
          isAccepting: false,
          backOnlineAt: backAt?.toUtc().toIso8601String(),
        );
        if (mounted) setState(() { _isAccepting = false; _backOnlineAt = backAt; });
      } catch (_) {} finally {
        if (mounted) setState(() { _availLoading = false; });
      }
    } else {
      setState(() { _availLoading = true; });
      try {
        await ApiService.setRestaurantAvailability(isAccepting: true);
        if (mounted) setState(() { _isAccepting = true; _backOnlineAt = null; });
      } catch (_) {} finally {
        if (mounted) setState(() { _availLoading = false; });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        ApiService.getMenu(),
        ApiService.getOwnerOrders(),
      ]);
      final items = results[0] as List<Map<String, dynamic>>;
      final orders = results[1] as List<Map<String, dynamic>>;
      final active = orders
          .where((o) =>
              ['placed', 'accepted', 'ready', 'out_for_delivery']
                  .contains(o['status']))
          .length;
      if (mounted) {
        setState(() {
          _menuCount = items.length;
          _activeOrders = active;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('My Restaurant'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OwnerProfileScreen()),
            ),
            tooltip: 'My Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Greeting
                  Text('Hello, ${widget.ownerName.split(' ').first}!',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  const Text('Manage your restaurant from here.',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  // ── Availability toggle card ──────────────────────────────
                  _AvailabilityCard(
                    isAccepting: _isAccepting,
                    backOnlineAt: _backOnlineAt,
                    loading: _availLoading,
                    onToggle: _toggleAvailability,
                  ),
                  const SizedBox(height: 20),

                  // Stat cards
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.restaurant_menu,
                        color: const Color(0xFF166534),
                        bgColor: const Color(0xFFDCFCE7),
                        label: 'Menu Items',
                        value: '$_menuCount',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const MenuListScreen()),
                          );
                          _loadStats();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt_long,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                        label: 'Active Orders',
                        value: '$_activeOrders',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const OwnerOrdersScreen()),
                          );
                          _loadStats();
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // Quick actions
                  const Text('Quick Actions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  _ActionTile(
                    icon: Icons.restaurant_menu,
                    title: 'Manage Menu',
                    subtitle: 'Add, edit and toggle items',
                    color: const Color(0xFF166534),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const MenuListScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.receipt_long,
                    title: 'View Orders',
                    subtitle: 'Accept, track and update orders',
                    color: const Color(0xFFD97706),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const OwnerOrdersScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.local_offer,
                    title: 'My Offers',
                    subtitle: 'Push deals to nearby customers',
                    color: const Color(0xFF7C3AED),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OwnerOffersScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.account_balance_wallet,
                    title: 'Billing & Revenue',
                    subtitle: 'Orders, earnings & platform fee',
                    color: const Color(0xFF059669),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OwnerBillingScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.bar_chart,
                    title: 'Food Stats',
                    subtitle: 'Top items, hourly volume & trends',
                    color: const Color(0xFFD97706),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OwnerStatsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    subtitle: 'View & request updates to your details',
                    color: const Color(0xFF0891B2),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OwnerProfileScreen()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool isAccepting;
  final DateTime? backOnlineAt;
  final bool loading;
  final ValueChanged<bool> onToggle;

  const _AvailabilityCard({
    required this.isAccepting,
    required this.backOnlineAt,
    required this.loading,
    required this.onToggle,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isGreen = const Color(0xFF166534);
    final isRed = const Color(0xFFDC2626);
    final color = isAccepting ? isGreen : isRed;
    final bgColor = isAccepting
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          isAccepting ? Icons.storefront : Icons.store_mall_directory_outlined,
          color: color,
          size: 26,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAccepting ? 'Accepting Orders' : 'Not Accepting Orders',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Text(
                isAccepting
                    ? 'Customers can place orders now'
                    : 'Tap toggle to go live again',
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        loading
            ? SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color))
            : Switch(
                value: isAccepting,
                onChanged: onToggle,
                activeColor: isGreen,
                inactiveThumbColor: isRed,
                inactiveTrackColor: const Color(0xFFFCA5A5),
              ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: onTap != null
                ? color.withOpacity(0.3)
                : const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A))),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B))),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }
}
