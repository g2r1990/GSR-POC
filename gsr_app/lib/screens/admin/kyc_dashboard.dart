import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1E40AF);

  late TabController _tabController;

  // KYC tab
  List<Map<String, dynamic>> _kycPending = [];
  bool _kycLoading = true;
  String? _kycError;

  // Rider approval tab
  List<Map<String, dynamic>> _pendingRiders = [];
  bool _ridersLoading = true;
  String? _ridersError;

  // Rider deletion tab
  List<Map<String, dynamic>> _deletionRequests = [];
  bool _deletionsLoading = true;
  String? _deletionsError;

  // Rider profile update tab
  List<Map<String, dynamic>> _riderUpdates = [];
  bool _updatesLoading = true;
  String? _updatesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadKyc();
    _loadRiders();
    _loadDeletions();
    _loadRiderUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadKyc() async {
    setState(() { _kycLoading = true; _kycError = null; });
    try {
      final list = await ApiService.kycPending();
      if (mounted) setState(() { _kycPending = list; _kycLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _kycError = e.message; _kycLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _kycError = 'Cannot reach server.'; _kycLoading = false; });
    }
  }

  Future<void> _loadRiders() async {
    setState(() { _ridersLoading = true; _ridersError = null; });
    try {
      final list = await ApiService.adminGetRiders('pending_admin');
      if (mounted) setState(() { _pendingRiders = list; _ridersLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _ridersError = e.message; _ridersLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _ridersError = 'Cannot reach server.'; _ridersLoading = false; });
    }
  }

  Future<void> _loadDeletions() async {
    setState(() { _deletionsLoading = true; _deletionsError = null; });
    try {
      final list = await ApiService.adminGetDeletionRequests();
      if (mounted) setState(() { _deletionRequests = list; _deletionsLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _deletionsError = e.message; _deletionsLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _deletionsError = 'Cannot reach server.'; _deletionsLoading = false; });
    }
  }

  Future<void> _loadRiderUpdates() async {
    setState(() { _updatesLoading = true; _updatesError = null; });
    try {
      final list = await ApiService.adminGetRiderUpdates();
      if (mounted) setState(() { _riderUpdates = list; _updatesLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _updatesError = e.message; _updatesLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _updatesError = 'Cannot reach server.'; _updatesLoading = false; });
    }
  }

  void _loadAll() {
    _loadKyc();
    _loadRiders();
    _loadDeletions();
    _loadRiderUpdates();
  }

  Future<void> _approveDeletion(String id, String name) async {
    final ok = await _confirmDialog('Remove "$name"?',
        'This will permanently deactivate the rider. They will no longer be able to log in.');
    if (!ok) return;
    try {
      await ApiService.adminApproveDeletion(id);
      _showSnack('$name has been removed', Colors.red);
      _loadDeletions();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _rejectDeletion(String id, String name) async {
    final ok = await _confirmDialog('Keep "$name"?',
        'The removal request will be cancelled and the rider will remain active.');
    if (!ok) return;
    try {
      await ApiService.adminRejectDeletion(id);
      _showSnack('Removal request for $name rejected', Colors.green);
      _loadDeletions();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _approveKyc(String id, String name) async {
    final ok = await _confirmDialog('Approve "$name"?',
        'This will mark the owner as active and allow them to proceed.');
    if (!ok) return;
    try {
      await ApiService.kycApprove(id);
      _showSnack('$name approved', Colors.green);
      _loadKyc();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _rejectKyc(String id, String name) async {
    final reason = await _reasonDialog();
    if (reason == null) return;
    try {
      await ApiService.kycReject(id, reason);
      _showSnack('$name rejected', Colors.orange);
      _loadKyc();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _approveRider(String id, String name) async {
    final ok = await _confirmDialog(
      'Approve "$name"?',
      'This will send the rider to the restaurant owner for confirmation.',
    );
    if (!ok) return;
    try {
      await ApiService.adminApproveRider(id);
      _showSnack('$name sent to owner for confirmation', Colors.green);
      _loadRiders();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _rejectRider(String id, String name) async {
    final ok = await _confirmDialog(
      'Reject "$name"?',
      'This will reject the rider registration. They may re-register.',
    );
    if (!ok) return;
    try {
      await ApiService.adminRejectRider(id);
      _showSnack('$name registration rejected', Colors.orange);
      _loadRiders();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _approveRiderUpdate(String id, String name) async {
    final ok = await _confirmDialog(
      'Apply update for "$name"?',
      'The rider\'s profile changes will be applied immediately.',
    );
    if (!ok) return;
    try {
      await ApiService.adminApproveRiderUpdate(id);
      _showSnack('$name profile updated', Colors.green);
      _loadRiderUpdates();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<void> _rejectRiderUpdate(String id, String name) async {
    final ok = await _confirmDialog(
      'Reject update for "$name"?',
      'The pending profile changes will be discarded.',
    );
    if (!ok) return;
    try {
      await ApiService.adminRejectRiderUpdate(id);
      _showSnack('Update request for $name rejected', Colors.orange);
      _loadRiderUpdates();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  Future<bool> _confirmDialog(String title, String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _reasonDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Documents unclear, GSTIN mismatch...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/roles', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll, tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Logout'),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(child: _tabLabel('Owner KYC', _kycPending.length)),
            Tab(child: _tabLabel('Rider Approvals', _pendingRiders.length)),
            Tab(child: _tabLabel('Removals', _deletionRequests.length)),
            Tab(child: _tabLabel('Profile Updates', _riderUpdates.length)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKycTab(),
          _buildRiderTab(),
          _buildDeletionsTab(),
          _buildRiderUpdatesTab(),
        ],
      ),
    );
  }

  Widget _tabLabel(String text, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 6),
          _Badge(count),
        ],
      ],
    );
  }

  Widget _buildKycTab() {
    if (_kycLoading) return const Center(child: CircularProgressIndicator());
    if (_kycError != null) return _ErrorView(message: _kycError!, onRetry: _loadKyc);
    if (_kycPending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF059669)),
            SizedBox(height: 16),
            Text('All clear!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('No pending KYC applications.', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadKyc,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _kycPending.length,
        itemBuilder: (ctx, i) {
          final o = _kycPending[i];
          final name = o['name']?.toString() ?? 'Unknown';
          final mobile = o['mobile']?.toString() ?? '';
          final gstin = o['gstin']?.toString() ?? '-';
          final id = o['id']?.toString() ?? '';
          return _KycCard(
            name: name,
            mobile: mobile,
            gstin: gstin,
            onApprove: () => _approveKyc(id, name),
            onReject: () => _rejectKyc(id, name),
          );
        },
      ),
    );
  }

  Widget _buildRiderTab() {
    if (_ridersLoading) return const Center(child: CircularProgressIndicator());
    if (_ridersError != null) return _ErrorView(message: _ridersError!, onRetry: _loadRiders);
    if (_pendingRiders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text('No pending rider approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('New rider registrations appear here.', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRiders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRiders.length,
        itemBuilder: (ctx, i) {
          final r = _pendingRiders[i];
          final name = r['name']?.toString() ?? '';
          final phone = r['phone']?.toString() ?? '';
          final vehicle = r['vehicle_number']?.toString() ?? '';
          final restaurant = r['restaurant_name']?.toString() ?? '';
          final id = r['id']?.toString() ?? '';
          return _RiderCard(
            name: name, phone: phone, vehicle: vehicle, restaurant: restaurant,
            onApprove: () => _approveRider(id, name),
            onReject: () => _rejectRider(id, name),
          );
        },
      ),
    );
  }

  Widget _buildDeletionsTab() {
    if (_deletionsLoading) return const Center(child: CircularProgressIndicator());
    if (_deletionsError != null) return _ErrorView(message: _deletionsError!, onRetry: _loadDeletions);
    if (_deletionRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_remove_outlined, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text('No removal requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Owner-requested rider removals appear here.', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDeletions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deletionRequests.length,
        itemBuilder: (ctx, i) {
          final r = _deletionRequests[i];
          final name = r['name']?.toString() ?? '';
          final phone = r['phone']?.toString() ?? '';
          final vehicle = r['vehicle_number']?.toString() ?? '';
          final restaurant = r['restaurant_name']?.toString() ?? '';
          final id = r['id']?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.person_remove, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text('Removal\nRequested',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                ]),
                const SizedBox(height: 10),
                _Info(label: 'Restaurant', value: restaurant),
                _Info(label: 'Vehicle', value: vehicle),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectDeletion(id, name),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Keep Rider'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDeletion(id, name),
                      icon: const Icon(Icons.person_remove, size: 16),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRiderUpdatesTab() {
    if (_updatesLoading) return const Center(child: CircularProgressIndicator());
    if (_updatesError != null) return _ErrorView(message: _updatesError!, onRetry: _loadRiderUpdates);
    if (_riderUpdates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_accounts_outlined, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text('No profile update requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Owner-approved rider profile changes appear here.', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRiderUpdates,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _riderUpdates.length,
        itemBuilder: (ctx, i) {
          final r = _riderUpdates[i];
          final name    = r['name']?.toString() ?? '';
          final phone   = r['phone']?.toString() ?? '';
          final vehicle = r['vehicle_number']?.toString() ?? '';
          final restaurant = r['restaurant_name']?.toString() ?? '';
          final id      = r['id']?.toString() ?? '';
          final pendingPhone   = r['pending_phone'] as String?;
          final pendingVehicle = r['pending_vehicle'] as String?;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.manage_accounts, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text(restaurant, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text('Final\nApproval',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                  ),
                ]),
                const SizedBox(height: 12),
                if (pendingPhone != null) _changeRow('Phone', phone, pendingPhone),
                if (pendingVehicle != null) _changeRow('Vehicle', vehicle, pendingVehicle),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRiderUpdate(id, name),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRiderUpdate(id, name),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Apply Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _changeRow(String field, String current, String proposed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(field, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          Text(current, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B),
              decoration: TextDecoration.lineThrough)),
        ])),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF94A3B8)),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New $field', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          Text(proposed, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: Color(0xFF059669))),
        ])),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

class _KycCard extends StatelessWidget {
  final String name, mobile, gstin;
  final VoidCallback onApprove, onReject;

  const _KycCard({
    required this.name, required this.mobile, required this.gstin,
    required this.onApprove, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.store, color: Color(0xFF1E40AF)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('Pending', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          ]),
          const SizedBox(height: 8),
          _Info(label: 'Mobile', value: mobile),
          _Info(label: 'GSTIN', value: gstin),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  final String name, phone, vehicle, restaurant;
  final VoidCallback onApprove, onReject;

  const _RiderCard({
    required this.name, required this.phone, required this.vehicle,
    required this.restaurant, required this.onApprove, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFFEF3C7),
              child: Icon(Icons.delivery_dining, color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('New', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 10),
          _Info(label: 'Restaurant', value: restaurant),
          _Info(label: 'Vehicle', value: vehicle),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Send to Owner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label, value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
