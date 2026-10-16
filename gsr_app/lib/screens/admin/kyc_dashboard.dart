import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF166534);
  static const _greenLight = Color(0xFF059669);

  int _selectedIndex = 0;
  Timer? _autoRefreshTimer;

  // ── Stats (Home tab) ───────────────────────────────────────────────────────
  Map<String, dynamic> _stats = {};
  bool _statsLoading = true;

  // ── Orders tab (drill-down) ────────────────────────────────────────────────
  int _ordersLevel = 0; // 0=cities, 1=restaurants, 2=orders
  String _ordersCity = '';
  String _ordersRestaurantName = '';
  List<Map<String, dynamic>> _ordersCities = [];
  List<Map<String, dynamic>> _ordersRestaurants = [];
  List<Map<String, dynamic>> _ordersList = [];
  String _ordersStatusFilter = '';
  bool _ordersLoading = false;

  // ── Approvals tab ─────────────────────────────────────────────────────────
  late TabController _approvalTabController;
  List<Map<String, dynamic>> _kycList = [];
  bool _kycLoading = true;
  List<Map<String, dynamic>> _riderPending = [];
  bool _ridersLoading = true;
  List<Map<String, dynamic>> _deletions = [];
  bool _deletionsLoading = true;
  List<Map<String, dynamic>> _riderUpdates = [];
  bool _riderUpdatesLoading = true;
  List<Map<String, dynamic>> _ownerUpdates = [];
  bool _ownerUpdatesLoading = true;

  // ── Reports tab ───────────────────────────────────────────────────────────
  String _reportType = 'full';
  String _reportCity = '';
  String _reportFrom = '';
  String _reportTo = '';
  Map<String, dynamic> _reportData = {};
  bool _reportLoading = false;
  bool _reportLoaded = false;
  List<Map<String, dynamic>> _reportCities = [];

  // ── Finance tab ───────────────────────────────────────────────────────────
  int _financeTab = 0;
  String _gstPeriod = 'month';
  String _gstCity = '';
  Map<String, dynamic> _gstData = {};
  bool _gstLoading = false;
  bool _gstLoaded = false;
  String _payoutCity = '';
  String _payoutDate = '';
  Map<String, dynamic> _payoutData = {};
  bool _payoutLoading = false;
  bool _payoutLoaded = false;
  List<Map<String, dynamic>> _financeCities = [];

  @override
  void initState() {
    super.initState();
    _approvalTabController = TabController(length: 5, vsync: this);
    _loadStats();
    _loadAllApprovals();
    _loadCities();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _loadStats();
      _loadAllApprovals();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _approvalTabController.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────

  Future<void> _loadStats() async {
    try {
      final s = await ApiService.adminGetStats();
      if (mounted) setState(() { _stats = s; _statsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadCities() async {
    try {
      final cities = await ApiService.adminGetCities();
      if (mounted) setState(() {
        _ordersCities = cities;
        _reportCities = cities;
        _financeCities = cities;
      });
    } catch (_) {}
  }

  Future<void> _loadAllApprovals() async {
    _loadKyc();
    _loadRiders();
    _loadDeletions();
    _loadRiderUpdates();
    _loadOwnerUpdates();
  }

  Future<void> _loadKyc() async {
    try {
      final list = await ApiService.kycPending();
      if (mounted) setState(() { _kycList = list; _kycLoading = false; });
    } catch (_) { if (mounted) setState(() => _kycLoading = false); }
  }

  Future<void> _loadRiders() async {
    try {
      final list = await ApiService.adminGetRiders('pending_admin');
      if (mounted) setState(() { _riderPending = list; _ridersLoading = false; });
    } catch (_) { if (mounted) setState(() => _ridersLoading = false); }
  }

  Future<void> _loadDeletions() async {
    try {
      final list = await ApiService.adminGetDeletionRequests();
      if (mounted) setState(() { _deletions = list; _deletionsLoading = false; });
    } catch (_) { if (mounted) setState(() => _deletionsLoading = false); }
  }

  Future<void> _loadRiderUpdates() async {
    try {
      final list = await ApiService.adminGetRiderUpdates();
      if (mounted) setState(() { _riderUpdates = list; _riderUpdatesLoading = false; });
    } catch (_) { if (mounted) setState(() => _riderUpdatesLoading = false); }
  }

  Future<void> _loadOwnerUpdates() async {
    try {
      final list = await ApiService.adminGetOwnerProfileUpdates();
      if (mounted) setState(() { _ownerUpdates = list; _ownerUpdatesLoading = false; });
    } catch (_) { if (mounted) setState(() => _ownerUpdatesLoading = false); }
  }

  // ── Orders drill-down loaders ─────────────────────────────────────────────

  Future<void> _loadCityRestaurants(String city) async {
    setState(() { _ordersLoading = true; _ordersCity = city; _ordersLevel = 1; });
    try {
      final list = await ApiService.adminGetCityRestaurants(city);
      if (mounted) setState(() { _ordersRestaurants = list; _ordersLoading = false; });
    } catch (_) { if (mounted) setState(() => _ordersLoading = false); }
  }

  Future<void> _loadCityOrders(String restaurantName) async {
    setState(() { _ordersLoading = true; _ordersRestaurantName = restaurantName; _ordersLevel = 2; });
    try {
      final list = await ApiService.adminGetCityOrders(_ordersCity);
      if (mounted) setState(() { _ordersList = list; _ordersLoading = false; });
    } catch (_) { if (mounted) setState(() => _ordersLoading = false); }
  }

  // ── KYC actions ───────────────────────────────────────────────────────────

  Future<void> _approveKyc(String ownerId, String ownerName) async {
    try {
      await ApiService.kycApprove(ownerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$ownerName approved'), backgroundColor: Colors.green),
        );
        _loadKyc(); _loadStats();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectKyc(String ownerId, String ownerName) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject $ownerName'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.kycReject(ownerId, ctrl.text.trim().isEmpty ? 'Application rejected.' : ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$ownerName rejected'), backgroundColor: Colors.orange),
        );
        _loadKyc();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
    ctrl.dispose();
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) Navigator.pushReplacementNamed(context, '/admin/login');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text(_tabTitle(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () { _loadStats(); _loadAllApprovals(); _loadCities(); },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() {
            _selectedIndex = i;
            if (i == 1) { _ordersLevel = 0; _loadCities(); }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _green,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: _approvalBadge(), label: 'Approvals'),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
          const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Finance'),
        ],
      ),
    );
  }

  String _tabTitle() {
    switch (_selectedIndex) {
      case 0: return 'BossBite Admin';
      case 1:
        if (_ordersLevel == 2) return _ordersRestaurantName.isEmpty ? _ordersCity : _ordersCity;
        if (_ordersLevel == 1) return _ordersCity;
        return 'Orders';
      case 2: return 'Approvals';
      case 3: return 'Reports';
      case 4: return 'Finance';
      default: return 'Admin';
    }
  }

  Widget _approvalBadge() {
    final pending = (_stats['pending_kyc'] as int? ?? 0) +
        (_stats['pending_riders'] as int? ?? 0) +
        (_stats['pending_updates'] as int? ?? 0);
    if (pending == 0) return const Icon(Icons.approval_rounded);
    return Stack(clipBehavior: Clip.none, children: [
      const Icon(Icons.approval_rounded),
      Positioned(
        right: -4, top: -4,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildHomeTab();
      case 1: return _buildOrdersTab();
      case 2: return _buildApprovalsTab();
      case 3: return _buildReportsTab();
      case 4: return _buildFinanceTab();
      default: return _buildHomeTab();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOME TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHomeTab() {
    if (_statsLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    final activeRest = _stats['active_restaurants'] ?? 0;
    final revenue = _stats['total_revenue'] ?? 0.0;
    final profit = _stats['total_profit'] ?? 0.0;
    final activeRiders = _stats['active_riders'] ?? 0;
    final customers = _stats['total_customers'] ?? 0;
    final ordersToday = _stats['total_orders_today'] ?? 0;
    final pendingKyc = _stats['pending_kyc'] ?? 0;
    final pendingRiders = _stats['pending_riders'] ?? 0;
    final pendingUpdates = _stats['pending_updates'] ?? 0;

    return RefreshIndicator(
      color: _greenLight,
      onRefresh: () async { await _loadStats(); await _loadCities(); },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Overview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _ActionTile(
                icon: Icons.store_rounded, label: 'Active Restaurants', value: '$activeRest',
                color: const Color(0xFF1D4ED8),
                onTap: () { setState(() { _selectedIndex = 1; _ordersLevel = 0; }); _loadCities(); },
              ),
              _ActionTile(
                icon: Icons.payments_rounded, label: 'Total Sales', value: '₹${_fmt(revenue)}',
                color: const Color(0xFF059669),
                onTap: () { setState(() => _selectedIndex = 3); },
              ),
              _ActionTile(
                icon: Icons.trending_up_rounded, label: 'Platform Profit', value: '₹${_fmt(profit)}',
                color: const Color(0xFF7C3AED),
                onTap: () { setState(() { _selectedIndex = 4; _financeTab = 1; }); },
              ),
              _ActionTile(
                icon: Icons.delivery_dining_rounded, label: 'Active Riders', value: '$activeRiders',
                color: const Color(0xFFD97706), onTap: () {},
              ),
              _ActionTile(
                icon: Icons.people_rounded, label: 'Customers', value: '$customers',
                color: const Color(0xFF0891B2), onTap: () {},
              ),
              _ActionTile(
                icon: Icons.today_rounded, label: 'Orders Today', value: '$ordersToday',
                color: const Color(0xFF166534),
                onTap: () { setState(() { _selectedIndex = 1; _ordersLevel = 0; }); _loadCities(); },
              ),
            ],
          ),
          if (pendingKyc + pendingRiders + pendingUpdates > 0) ...[
            const SizedBox(height: 20),
            const Text('Needs Attention', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            if (pendingKyc > 0)
              _PendingTile(icon: Icons.store_outlined, label: 'Owner KYC pending', count: pendingKyc,
                  onTap: () { setState(() { _selectedIndex = 2; _approvalTabController.index = 0; }); }),
            if (pendingRiders > 0)
              _PendingTile(icon: Icons.delivery_dining_outlined, label: 'Rider approvals pending', count: pendingRiders,
                  onTap: () { setState(() { _selectedIndex = 2; _approvalTabController.index = 1; }); }),
            if (pendingUpdates > 0)
              _PendingTile(icon: Icons.edit_outlined, label: 'Update requests pending', count: pendingUpdates,
                  onTap: () { setState(() { _selectedIndex = 2; _approvalTabController.index = 2; }); }),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ORDERS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOrdersTab() {
    if (_ordersLevel == 0) return _buildOrdersCityList();
    if (_ordersLevel == 1) return _buildOrdersRestaurantList();
    return _buildOrdersOrderList();
  }

  Widget _buildOrdersCityList() {
    if (_ordersLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    if (_ordersCities.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.location_city, size: 64, color: Colors.black12),
        const SizedBox(height: 12),
        const Text('No cities found', style: TextStyle(color: Colors.black45)),
        TextButton(onPressed: _loadCities, child: const Text('Refresh')),
      ]));
    }
    return RefreshIndicator(
      color: _greenLight,
      onRefresh: _loadCities,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _ordersCities.length,
        itemBuilder: (_, i) {
          final c = _ordersCities[i];
          final city = c['city'] as String? ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFBBF7D0), child: Icon(Icons.location_city, color: _green, size: 22)),
              title: Text(city, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${c['restaurant_count']} restaurants · ${c['order_count']} orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _loadCityRestaurants(city),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersRestaurantList() {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => setState(() { _ordersLevel = 0; }),
      child: Column(children: [
        _DrillHeader(title: _ordersCity, onBack: () => setState(() { _ordersLevel = 0; })),
        if (_ordersLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _greenLight))),
        if (!_ordersLoading)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _ordersRestaurants.length,
              itemBuilder: (_, i) {
                final r = _ordersRestaurants[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: r['status'] == 'active' ? const Color(0xFFBBF7D0) : const Color(0xFFFEE2E2),
                      child: Icon(Icons.restaurant, color: r['status'] == 'active' ? _green : Colors.red, size: 20),
                    ),
                    title: Text(r['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${r['area']} · ${r['order_count']} orders · ${r['rider_count']} riders'),
                    trailing: _Badge(
                      label: r['status'] == 'active' ? 'OPEN' : (r['status'] as String? ?? '').toUpperCase(),
                      color: r['status'] == 'active' ? Colors.green : Colors.orange,
                    ),
                    onTap: () => _loadCityOrders(r['name'] as String),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildOrdersOrderList() {
    final filtered = _ordersStatusFilter.isEmpty
        ? _ordersList
        : _ordersList.where((o) => o['status'] == _ordersStatusFilter).toList();

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => setState(() { _ordersLevel = 1; }),
      child: Column(children: [
        _DrillHeader(title: _ordersCity, subtitle: 'All restaurants', onBack: () => setState(() { _ordersLevel = 1; })),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            _FilterChip(label: 'All', selected: _ordersStatusFilter.isEmpty, onTap: () => setState(() => _ordersStatusFilter = '')),
            const SizedBox(width: 6),
            for (final s in ['placed', 'accepted', 'ready', 'out_for_delivery', 'delivered', 'cancelled'])
              Padding(padding: const EdgeInsets.only(right: 6),
                child: _FilterChip(label: s.replaceAll('_', ' '), selected: _ordersStatusFilter == s,
                    onTap: () => setState(() => _ordersStatusFilter = s))),
          ]),
        ),
        if (_ordersLoading) const Expanded(child: Center(child: CircularProgressIndicator(color: _greenLight))),
        if (!_ordersLoading)
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No orders found', style: TextStyle(color: Colors.black45)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
                  ),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APPROVALS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildApprovalsTab() {
    return Column(children: [
      Container(
        color: _green,
        child: TabBar(
          controller: _approvalTabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: [
            _approvalTab('Owner KYC', _kycList.length),
            _approvalTab('Rider Reg', _riderPending.length),
            _approvalTab('Removals', _deletions.length),
            _approvalTab('Rider Upd', _riderUpdates.length),
            _approvalTab('Owner Upd', _ownerUpdates.length),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _approvalTabController, children: [
        _buildKycTab(),
        _buildRiderApprovalsTab(),
        _buildDeletionsTab(),
        _buildRiderUpdatesTab(),
        _buildOwnerUpdatesTab(),
      ])),
    ]);
  }

  Tab _approvalTab(String label, int count) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    ]),
  );

  Widget _buildKycTab() {
    if (_kycLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    if (_kycList.isEmpty) return const Center(child: Text('No pending KYC applications', style: TextStyle(color: Colors.black45)));
    return RefreshIndicator(
      color: _greenLight,
      onRefresh: _loadKyc,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _kycList.length,
        itemBuilder: (_, i) => _KycCard(
          owner: _kycList[i],
          onApprove: () => _approveKyc(_kycList[i]['id'] as String, _kycList[i]['name'] as String),
          onReject: () => _rejectKyc(_kycList[i]['id'] as String, _kycList[i]['name'] as String),
        ),
      ),
    );
  }

  Widget _buildRiderApprovalsTab() {
    if (_ridersLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    if (_riderPending.isEmpty) return const Center(child: Text('No pending rider registrations', style: TextStyle(color: Colors.black45)));
    return RefreshIndicator(
      color: _greenLight,
      onRefresh: _loadRiders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _riderPending.length,
        itemBuilder: (_, i) {
          final r = _riderPending[i];
          return _RiderCard(rider: r, actions: [
            _CardBtn(label: 'Approve', color: _green, onTap: () async {
              await ApiService.adminApproveRider(r['id'] as String);
              _loadRiders(); _loadStats();
            }),
            _CardBtn(label: 'Reject', color: Colors.red, onTap: () async {
              await ApiService.adminRejectRider(r['id'] as String);
              _loadRiders();
            }),
          ]);
        },
      ),
    );
  }

  Widget _buildDeletionsTab() {
    if (_deletionsLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    if (_deletions.isEmpty) return const Center(child: Text('No deletion requests', style: TextStyle(color: Colors.black45)));
    return RefreshIndicator(
      color: _greenLight,
      onRefresh: _loadDeletions,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _deletions.length,
        itemBuilder: (_, i) {
          final r = _deletions[i];
          return _RiderCard(
            rider: r, subtitle: 'Deletion requested', subtitleColor: Colors.red,
            actions: [
              _CardBtn(label: 'Remove', color: Colors.red, onTap: () async {
                await ApiService.adminApproveDeletion(r['id'] as String);
                _loadDeletions(); _loadStats();
              }),
              _CardBtn(label: 'Deny', color: Colors.grey, onTap: () async {
                await ApiService.adminRejectDeletion(r['id'] as String);
                _loadDeletions();
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRiderUpdatesTab() {
    if (_riderUpdatesLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    if (_riderUpdates.isEmpty) return const Center(child: Text('No rider update requests', style: TextStyle(color: Colors.black45)));
    return RefreshIndicator(
      color: _greenLight,
      onRefresh: _loadRiderUpdates,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _riderUpdates.length,
        itemBuilder: (_, i) {
          final r = _riderUpdates[i];
          return _RiderCard(rider: r, showPending: true, actions: [
            _CardBtn(label: 'Approve', color: _green, onTap: () async {
              await ApiService.adminApproveRiderUpdate(r['id'] as String);
              _loadRiderUpdates();
            }),
            _CardBtn(label: 'Reject', color: Colors.red, onTap: () async {
              await ApiService.adminRejectRiderUpdate(r['id'] as String);
              _loadRiderUpdates();
            }),
          ]);
        },
      ),
    );
  }

  Widget _buildOwnerUpdatesTab() {
    if (_ownerUpdatesLoading) return const Center(child: CircularProgressIndicator(color: _greenLight));
    if (_ownerUpdates.isEmpty) return const Center(child: Text('No owner update requests', style: TextStyle(color: Colors.black45)));
    return RefreshIndicator(
      color: _greenLight,
      onRefresh: _loadOwnerUpdates,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _ownerUpdates.length,
        itemBuilder: (_, i) {
          final o = _ownerUpdates[i];
          final changes = o['requested_changes'] as Map<String, dynamic>? ?? {};
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['owner_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(o['restaurant_name'] as String? ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 8),
              ...changes.entries.map((e) => _Info('${e.key}', '${e.value}')),
              const SizedBox(height: 10),
              Row(children: [
                _CardBtn(label: 'Approve', color: _green, onTap: () async {
                  await ApiService.adminApproveOwnerProfileUpdate(o['owner_id'] as String);
                  _loadOwnerUpdates();
                }),
                const SizedBox(width: 8),
                _CardBtn(label: 'Reject', color: Colors.red, onTap: () async {
                  await ApiService.adminRejectOwnerProfileUpdate(o['owner_id'] as String);
                  _loadOwnerUpdates();
                }),
              ]),
            ])),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORTS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReportsTab() {
    final now = DateTime.now();
    if (_reportFrom.isEmpty) {
      _reportFrom = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      _reportTo = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Report Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _reportType,
              decoration: const InputDecoration(labelText: 'Report Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('Full Summary')),
                DropdownMenuItem(value: 'profit', child: Text('Platform Profit')),
                DropdownMenuItem(value: 'owner_earnings', child: Text('Owner Earnings')),
                DropdownMenuItem(value: 'gst', child: Text('GST Collection')),
              ],
              onChanged: (v) => setState(() { _reportType = v!; _reportLoaded = false; }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _reportCity.isEmpty ? '' : _reportCity,
              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Cities')),
                ..._reportCities.map((c) => DropdownMenuItem(value: c['city'] as String, child: Text(c['city'] as String))),
              ],
              onChanged: (v) => setState(() { _reportCity = v ?? ''; _reportLoaded = false; }),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DateField(label: 'From', value: _reportFrom,
                  onPick: (d) => setState(() { _reportFrom = d; _reportLoaded = false; }))),
              const SizedBox(width: 10),
              Expanded(child: _DateField(label: 'To', value: _reportTo,
                  onPick: (d) => setState(() { _reportTo = d; _reportLoaded = false; }))),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              icon: const Icon(Icons.search, size: 18),
              label: _reportLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Generate Report'),
              onPressed: _reportLoading ? null : _generateReport,
            )),
          ])),
        ),
        if (_reportLoaded) ...[
          const SizedBox(height: 16),
          _buildReportResults(),
        ],
      ],
    );
  }

  Future<void> _generateReport() async {
    setState(() { _reportLoading = true; _reportLoaded = false; });
    try {
      final data = await ApiService.adminGetReport(
        fromDate: _reportFrom, toDate: _reportTo, city: _reportCity, reportType: _reportType,
      );
      if (mounted) setState(() { _reportData = data; _reportLoaded = true; _reportLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _reportLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildReportResults() {
    final summary = _reportData['summary'] as Map<String, dynamic>? ?? {};
    final restaurants = (_reportData['restaurants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
        children: [
          _SummaryCard('Total Revenue', '₹${_fmt(summary['total_revenue'] ?? 0)}', Colors.blue),
          _SummaryCard('Platform Profit', '₹${_fmt(summary['platform_profit'] ?? 0)}', Colors.purple),
          _SummaryCard('Owner Earnings', '₹${_fmt(summary['owner_earnings'] ?? 0)}', Colors.green),
          _SummaryCard('GST Collected', '₹${_fmt(summary['gst_collected'] ?? 0)}', Colors.orange),
        ],
      ),
      const SizedBox(height: 16),
      Text('Breakdown (${restaurants.length} restaurants)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
      const SizedBox(height: 8),
      ...restaurants.map((r) => _RestaurantReportCard(data: r, reportType: _reportType)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINANCE TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFinanceTab() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: _SubTabBtn(label: 'GST', selected: _financeTab == 0, onTap: () => setState(() => _financeTab = 0))),
        const SizedBox(width: 10),
        Expanded(child: _SubTabBtn(label: 'Payout', selected: _financeTab == 1, onTap: () => setState(() => _financeTab = 1))),
      ])),
      Expanded(child: _financeTab == 0 ? _buildGstTab() : _buildPayoutTab()),
    ]);
  }

  Widget _buildGstTab() {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('GST Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _gstPeriod,
            decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'week', child: Text('Last 7 days')),
              DropdownMenuItem(value: 'month', child: Text('This month')),
              DropdownMenuItem(value: 'quarter', child: Text('This quarter')),
              DropdownMenuItem(value: 'all', child: Text('All time')),
            ],
            onChanged: (v) => setState(() { _gstPeriod = v!; _gstLoaded = false; }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _gstCity.isEmpty ? '' : _gstCity,
            decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Cities')),
              ..._financeCities.map((c) => DropdownMenuItem(value: c['city'] as String, child: Text(c['city'] as String))),
            ],
            onChanged: (v) => setState(() { _gstCity = v ?? ''; _gstLoaded = false; }),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.calculate_rounded, size: 18),
            label: _gstLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Calculate GST'),
            onPressed: _gstLoading ? null : _loadGst,
          )),
        ])),
      ),
      if (_gstLoaded) ...[
        const SizedBox(height: 16),
        _buildGstResults(),
      ],
    ]);
  }

  Future<void> _loadGst() async {
    setState(() { _gstLoading = true; _gstLoaded = false; });
    try {
      final data = await ApiService.adminGetGstReport(period: _gstPeriod, city: _gstCity);
      if (mounted) setState(() { _gstData = data; _gstLoaded = true; _gstLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _gstLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildGstResults() {
    final summary = _gstData['summary'] as Map<String, dynamic>? ?? {};
    final breakdown = (_gstData['breakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('GST Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
        children: [
          _SummaryCard('Taxable Value', '₹${_fmt(summary['taxable_value'] ?? 0)}', Colors.blue),
          _SummaryCard('Total GST', '₹${_fmt(summary['total_gst'] ?? 0)}', Colors.orange),
          _SummaryCard('CGST (2.5%)', '₹${_fmt(summary['total_cgst'] ?? 0)}', Colors.teal),
          _SummaryCard('SGST (2.5%)', '₹${_fmt(summary['total_sgst'] ?? 0)}', Colors.indigo),
        ],
      ),
      const SizedBox(height: 16),
      Text('Breakdown (${breakdown.length} restaurants)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
      const SizedBox(height: 8),
      ...breakdown.map((r) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['restaurant'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(r['city'] as String? ?? '', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Info('Orders', '${r['order_count']}')),
            Expanded(child: _Info('Taxable', '₹${_fmt(r['taxable_value'] ?? 0)}')),
          ]),
          Row(children: [
            Expanded(child: _Info('CGST', '₹${_fmt(r['cgst'] ?? 0)}')),
            Expanded(child: _Info('SGST', '₹${_fmt(r['sgst'] ?? 0)}')),
          ]),
        ])),
      )),
    ]);
  }

  Widget _buildPayoutTab() {
    final now = DateTime.now();
    if (_payoutDate.isEmpty) {
      _payoutDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payout Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
          const SizedBox(height: 10),
          _DateField(label: 'Date (EOD Payout)', value: _payoutDate,
              onPick: (d) => setState(() { _payoutDate = d; _payoutLoaded = false; })),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _payoutCity.isEmpty ? '' : _payoutCity,
            decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Cities')),
              ..._financeCities.map((c) => DropdownMenuItem(value: c['city'] as String, child: Text(c['city'] as String))),
            ],
            onChanged: (v) => setState(() { _payoutCity = v ?? ''; _payoutLoaded = false; }),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.account_balance_rounded, size: 18),
            label: _payoutLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Calculate Payouts'),
            onPressed: _payoutLoading ? null : _loadPayout,
          )),
        ])),
      ),
      if (_payoutLoaded) ...[
        const SizedBox(height: 16),
        _buildPayoutResults(),
      ],
    ]);
  }

  Future<void> _loadPayout() async {
    setState(() { _payoutLoading = true; _payoutLoaded = false; });
    try {
      final data = await ApiService.adminGetPayoutReport(city: _payoutCity, date: _payoutDate);
      if (mounted) setState(() { _payoutData = data; _payoutLoaded = true; _payoutLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _payoutLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildPayoutResults() {
    final total = _payoutData['total_payout'] ?? 0.0;
    final payouts = (_payoutData['payouts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Payout', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('₹${_fmt(total)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Text('${payouts.length} restaurants',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
      const SizedBox(height: 8),
      ...payouts.map((p) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['restaurant_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(p['city'] as String? ?? '', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text('${p['order_count']} orders · Gross ₹${_fmt(p['gross_revenue'] ?? 0)}',
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${_fmt(p['owner_payout'] ?? 0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _green)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(p['status'] as String? ?? 'pending',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
            ),
          ]),
        ])),
      )),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (d >= 100000) return '${(d / 100000).toStringAsFixed(1)}L';
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
    return d.toStringAsFixed(2);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helper widgets
// ═════════════════════════════════════════════════════════════════════════════

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 22),
            const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
          ]),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  const _PendingTile({required this.icon, required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: const Color(0xFFFEF3C7),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD97706), size: 24),
        title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        onTap: onTap, dense: true,
      ),
    );
  }
}

class _DrillHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  const _DrillHeader({required this.title, this.subtitle, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECFDF5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF166534)), onPressed: onBack),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF166634))),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  static const _statusColors = {
    'placed': Color(0xFF1D4ED8), 'accepted': Color(0xFF059669),
    'ready': Color(0xFF7C3AED), 'out_for_delivery': Color(0xFFD97706),
    'delivered': Color(0xFF166534), 'cancelled': Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final color = _statusColors[status] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${order['short_id'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(order['restaurant_name'] as String? ?? '', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text(order['customer_name'] as String? ?? '', style: const TextStyle(color: Colors.black38, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${(order['total'] as num?)?.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534))),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _KycCard extends StatelessWidget {
  final Map<String, dynamic> owner;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _KycCard({required this.owner, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final rest = owner['restaurant'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(owner['name'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(owner['mobile'] as String? ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13)),
        if (owner['gstin'] != null) Text('GSTIN: ${owner['gstin']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        if (rest != null) ...[
          const Divider(height: 16),
          Text(rest['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${rest['area']}, ${rest['pincode']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          Text(rest['address'] as String? ?? '', style: const TextStyle(color: Colors.black45, fontSize: 12)),
          _Info('Food Type', rest['food_type'] as String? ?? ''),
          _Info('Code', rest['restaurant_code'] as String? ?? 'Pending'),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: onApprove, child: const Text('Approve'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: onReject, child: const Text('Reject'),
          )),
        ]),
      ])),
    );
  }
}

class _RiderCard extends StatelessWidget {
  final Map<String, dynamic> rider;
  final List<Widget> actions;
  final String? subtitle;
  final Color? subtitleColor;
  final bool showPending;
  const _RiderCard({required this.rider, required this.actions, this.subtitle, this.subtitleColor, this.showPending = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rider['name'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        if (subtitle != null) Text(subtitle!, style: TextStyle(color: subtitleColor ?? Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
        _Info('Phone', rider['phone'] as String? ?? ''),
        _Info('Vehicle', rider['vehicle_number'] as String? ?? ''),
        _Info('Restaurant', rider['restaurant_name'] as String? ?? 'Unknown'),
        if (showPending && rider['pending_phone'] != null) _Info('New Phone', rider['pending_phone'] as String),
        if (showPending && rider['pending_vehicle'] != null) _Info('New Vehicle', rider['pending_vehicle'] as String),
        const SizedBox(height: 8),
        Row(children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            actions[i],
          ],
        ]),
      ])),
    );
  }
}

class _CardBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF166534) : Colors.white,
          border: Border.all(color: selected ? const Color(0xFF166534) : const Color(0xFFBBF7D0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _SubTabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubTabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF166534) : Colors.white,
          border: Border.all(color: const Color(0xFF166534)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF166534), fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _RestaurantReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String reportType;
  const _RestaurantReportCard({required this.data, required this.reportType});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['restaurant_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Text('${data['area']} · ${data['city']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 8),
        if (reportType == 'full' || reportType == 'profit')
          Row(children: [
            Expanded(child: _Info('Revenue', '₹${data['revenue']}')),
            Expanded(child: _Info('Profit', '₹${data['platform_profit']}')),
          ]),
        if (reportType == 'full' || reportType == 'owner_earnings')
          _Info('Owner Earnings', '₹${data['owner_earnings']}'),
        if (reportType == 'full' || reportType == 'gst')
          _Info('GST', '₹${data['gst_collected']}'),
        _Info('Orders', '${data['order_count']}'),
      ])),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String) onPick;
  const _DateField({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        DateTime initial;
        try { initial = DateTime.parse(value); } catch (_) { initial = DateTime.now(); }
        final picked = await showDatePicker(
          context: context, initialDate: initial,
          firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) {
          onPick('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
            Text(value.isEmpty ? 'Pick date' : value, style: const TextStyle(fontSize: 13)),
          ])),
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black54),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(text: value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      )),
    );
  }
}
