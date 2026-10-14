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

  // KYC tab state
  List<Map<String, dynamic>> _kycPending = [];
  bool _kycLoading = true;
  String? _kycError;

  // Rider tab state
  List<Map<String, dynamic>> _pendingRiders = [];
  bool _ridersLoading = true;
  String? _ridersError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadKyc();
    _loadRiders();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/roles', (_) => false);
    }
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { _loadKyc(); _loadRiders(); },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Owner KYC'),
                  if (_kycPending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(_kycPending.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Rider Approvals'),
                  if (_pendingRiders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(_pendingRiders.length),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKycTab(),
          _buildRiderTab(),
        ],
      ),
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
            name: name,
            phone: phone,
            vehicle: vehicle,
            restaurant: restaurant,
            onApprove: () => _approveRider(id, name),
            onReject: () => _rejectRider(id, name),
          );
        },
      ),
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
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class _KycCard extends StatelessWidget {
  final String name, mobile, gstin;
  final VoidCallback onApprove, onReject;

  const _KycCard({
    required this.name,
    required this.mobile,
    required this.gstin,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.store, color: Color(0xFF1E40AF)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
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
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
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
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  final String name, phone, vehicle, restaurant;
  final VoidCallback onApprove, onReject;

  const _RiderCard({
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.restaurant,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.delivery_dining, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
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
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
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
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
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
            Text(message,
                textAlign: TextAlign.center,
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
