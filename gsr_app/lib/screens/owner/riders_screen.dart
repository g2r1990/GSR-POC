import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OwnerRidersScreen extends StatefulWidget {
  const OwnerRidersScreen({super.key});
  @override
  State<OwnerRidersScreen> createState() => _OwnerRidersScreenState();
}

class _OwnerRidersScreenState extends State<OwnerRidersScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF166534);

  late TabController _tabController;
  Timer? _timer;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _updates = [];
  bool _loadingPending = true;
  bool _loadingActive = true;
  bool _loadingUpdates = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadPending();
    });
  }

  Future<void> _loadAll() async {
    _loadPending();
    _loadActive();
    _loadUpdates();
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final data = await ApiService.ownerGetPendingRiders();
      if (mounted) setState(() { _pending = data; _loadingPending = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadActive() async {
    setState(() => _loadingActive = true);
    try {
      final data = await ApiService.ownerGetActiveRiders();
      if (mounted) setState(() { _active = data; _loadingActive = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _loadUpdates() async {
    setState(() => _loadingUpdates = true);
    try {
      final data = await ApiService.ownerGetRiderUpdates();
      if (mounted) setState(() { _updates = data; _loadingUpdates = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingUpdates = false);
    }
  }

  Future<void> _confirm(String riderId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Rider'),
        content: Text('Approve $name as an active delivery rider for your restaurant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.ownerConfirmRider(riderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name approved as rider.'), backgroundColor: _green),
        );
        _loadAll();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(String riderId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Rider'),
        content: Text('Reject $name\'s rider registration for your restaurant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.ownerRejectRider(riderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rider rejected.'), backgroundColor: Colors.red),
        );
        _loadAll();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Manage Riders'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
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
                  const Text('Pending'),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pending.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Active'),
                  if (_active.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_active.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Updates'),
                  if (_updates.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_updates.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
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
          _buildPendingTab(),
          _buildActiveTab(),
          _buildUpdatesTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_loadingPending) return const Center(child: CircularProgressIndicator());
    if (_pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF86EFAC)),
            SizedBox(height: 12),
            Text('No pending approvals', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pending.length,
        itemBuilder: (_, i) => _buildPendingCard(_pending[i]),
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_loadingActive) return const Center(child: CircularProgressIndicator());
    if (_active.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('No active riders yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
            SizedBox(height: 6),
            Text('Confirm pending riders to see them here.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadActive,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _active.length,
        itemBuilder: (_, i) => _buildActiveCard(_active[i]),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> rider) {
    final name = rider['name'] as String? ?? '';
    final phone = rider['phone'] as String? ?? '';
    final vehicle = rider['vehicle_number'] as String? ?? '';
    final id = rider['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.person, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.two_wheeler, size: 15, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(vehicle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _reject(id, name),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _confirm(id, name),
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    if (_loadingUpdates) return const Center(child: CircularProgressIndicator());
    if (_updates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_off, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('No pending update requests', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadUpdates,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _updates.length,
        itemBuilder: (_, i) => _buildUpdateCard(_updates[i]),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> rider) {
    final name    = rider['name'] as String? ?? '';
    final phone   = rider['phone'] as String? ?? '';
    final vehicle = rider['vehicle_number'] as String? ?? '';
    final id      = rider['id'] as String;
    final pendingPhone   = rider['pending_phone'] as String?;
    final pendingVehicle = rider['pending_vehicle'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.edit, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              ),
            ]),
            const SizedBox(height: 12),
            if (pendingPhone != null)
              _changeRow('Phone', phone, pendingPhone),
            if (pendingVehicle != null)
              _changeRow('Vehicle', vehicle, pendingVehicle),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _handleUpdateDecision(id, name, false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _handleUpdateDecision(id, name, true),
                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _changeRow(String field, String current, String proposed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(field, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            Text(current, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B),
                decoration: TextDecoration.lineThrough)),
          ]),
        ),
        const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New $field', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            Text(proposed, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: Color(0xFF166534))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _handleUpdateDecision(String riderId, String name, bool approve) async {
    final verb = approve ? 'Approve' : 'Reject';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$verb Update Request'),
        content: Text('$verb $name\'s profile update request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: approve ? _green : Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (approve) {
        await ApiService.ownerApproveRiderUpdate(riderId);
      } else {
        await ApiService.ownerRejectRiderUpdate(riderId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Sent to admin for final approval.' : 'Request rejected.'),
            backgroundColor: approve ? _green : Colors.red,
          ),
        );
        _loadUpdates();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _requestRemoval(String riderId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Rider'),
        content: Text('Request removal of $name?\n\nAdmin will review and process the request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit Request', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.ownerRequestRiderDeletion(riderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removal request submitted. Admin will review shortly.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        _loadActive();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildActiveCard(Map<String, dynamic> rider) {
    final name = rider['name'] as String? ?? '';
    final phone = rider['phone'] as String? ?? '';
    final vehicle = rider['vehicle_number'] as String? ?? '';
    final id = rider['id'] as String;
    final deletionRequested = rider['deletion_requested'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.delivery_dining, color: Color(0xFF166534), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.two_wheeler, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(vehicle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ]),
                ]),
              ),
              deletionRequested
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: const Text('Removal\nPending',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Active',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ),
            ]),
            if (!deletionRequested) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _requestRemoval(id, name),
                  icon: const Icon(Icons.person_remove, size: 16, color: Colors.red),
                  label: const Text('Request Removal', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
