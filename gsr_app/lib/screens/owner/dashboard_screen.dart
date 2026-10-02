import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'menu_list_screen.dart';
import 'orders_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStats();
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
                  const SizedBox(height: 28),

                  // Stat cards
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.restaurant_menu,
                        color: const Color(0xFF166534),
                        bgColor: const Color(0xFFDCFCE7),
                        label: 'Menu Items',
                        value: '$_menuCount',
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
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
