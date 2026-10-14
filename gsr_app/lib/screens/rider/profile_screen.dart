import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});
  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  static const _amber = Color(0xFFD97706);
  static const _amberLight = Color(0xFFFFF7ED);

  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  // Edit form state
  bool _editing = false;
  final _phoneCtrl = TextEditingController();
  final _vStateCtrl = TextEditingController();
  final _vRtoCtrl = TextEditingController();
  final _vSeriesCtrl = TextEditingController();
  final _vNumCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _vStateCtrl.dispose();
    _vRtoCtrl.dispose();
    _vSeriesCtrl.dispose();
    _vNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.riderGetProfile();
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String get _vehicleNumber {
    final s  = _vStateCtrl.text.trim().toUpperCase();
    final r  = _vRtoCtrl.text.trim();
    final se = _vSeriesCtrl.text.trim().toUpperCase();
    final n  = _vNumCtrl.text.trim();
    if (s.isEmpty && r.isEmpty && se.isEmpty && n.isEmpty) return '';
    return '$s$r$se$n';
  }

  void _startEdit() {
    setState(() => _editing = true);
    _phoneCtrl.clear();
    _vStateCtrl.clear();
    _vRtoCtrl.clear();
    _vSeriesCtrl.clear();
    _vNumCtrl.clear();
  }

  void _cancelEdit() => setState(() => _editing = false);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final newPhone   = _phoneCtrl.text.trim();
    final newVehicle = _vehicleNumber;
    if (newPhone.isEmpty && newVehicle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one field to update.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.riderSubmitUpdateRequest(
        newPhone: newPhone.isNotEmpty ? '91$newPhone' : null,
        newVehicle: newVehicle.isNotEmpty ? newVehicle : null,
      );
      if (mounted) {
        setState(() { _editing = false; _submitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update request submitted. Awaiting owner review.'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Cancel your pending update request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.riderCancelUpdateRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled.'), backgroundColor: Colors.orange),
        );
        _load();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _amberLight,
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentInfo(),
                      const SizedBox(height: 16),
                      if (!_editing) _buildActions(),
                      if (_editing) _buildEditForm(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentInfo() {
    final p = _profile!;
    final updateStatus = p['update_status'] as String?;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.delivery_dining, color: _amber, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] as String? ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  if (updateStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        updateStatus == 'pending_owner' ? 'Update: Awaiting Owner' : 'Update: Awaiting Admin',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                ]),
              ),
            ]),
            const Divider(height: 24),
            _infoRow(Icons.phone, 'Phone', p['phone'] as String? ?? ''),
            const SizedBox(height: 10),
            _infoRow(Icons.two_wheeler, 'Vehicle', p['vehicle_number'] as String? ?? ''),
            if (updateStatus != null) ...[
              const Divider(height: 24),
              const Text('Pending Changes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              const SizedBox(height: 8),
              if (p['pending_phone'] != null)
                _infoRow(Icons.phone_forwarded, 'New Phone', p['pending_phone'] as String,
                    color: Colors.orange.shade700),
              if (p['pending_vehicle'] != null)
                _infoRow(Icons.car_repair, 'New Vehicle', p['pending_vehicle'] as String,
                    color: Colors.orange.shade700),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 18, color: color ?? const Color(0xFF94A3B8)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? const Color(0xFF0F172A))),
      ]),
    ]);
  }

  Widget _buildActions() {
    final hasRequest = _profile?['update_status'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasRequest)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _amber,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startEdit,
            icon: const Icon(Icons.edit),
            label: const Text('Request Profile Update', style: TextStyle(fontSize: 15)),
          ),
        if (hasRequest)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _cancelRequest,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Pending Request', style: TextStyle(fontSize: 15)),
          ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request Update',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Leave a field blank to keep it unchanged.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 20),

              // Phone field
              const Text('New Phone Number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  prefixText: '+91  ',
                  hintText: '10-digit number',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return null;
                  if (s.length != 10) return 'Enter 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Vehicle number
              const Text('New Vehicle Number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('e.g. MH 12 AB 1234',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _vStateCtrl,
                    maxLength: 2,
                    decoration: InputDecoration(
                      labelText: 'ST',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      _UpperCaseFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _vRtoCtrl,
                    maxLength: 2,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'RTO',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _vSeriesCtrl,
                    maxLength: 3,
                    decoration: InputDecoration(
                      labelText: 'Series',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      _UpperCaseFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _vNumCtrl,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Number',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _cancelEdit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _amber,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase(), selection: next.selection);
}
