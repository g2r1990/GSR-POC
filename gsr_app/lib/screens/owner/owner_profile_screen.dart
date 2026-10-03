import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  static const _teal = Color(0xFF0891B2);

  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _editing = false;
  bool _submitting = false;

  // Edit form controllers
  final _formKey = GlobalKey<FormState>();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _restaurantNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _foodType = 'veg';

  static const _foodTypes = ['veg', 'non-veg', 'both'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _restaurantNameCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await ApiService.getOwnerProfile();
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load profile.'; _loading = false; });
    }
  }

  void _startEdit() {
    final p = _profile!;
    final r = p['restaurant'] as Map<String, dynamic>?;
    _ownerNameCtrl.text = p['name'] as String? ?? '';
    _emailCtrl.text = p['email'] as String? ?? '';
    _restaurantNameCtrl.text = r?['name'] as String? ?? '';
    _areaCtrl.text = r?['area'] as String? ?? '';
    _addressCtrl.text = r?['address'] as String? ?? '';
    _foodType = r?['food_type'] as String? ?? 'veg';
    setState(() => _editing = true);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.submitOwnerProfileUpdate({
        'owner_name': _ownerNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'restaurant_name': _restaurantNameCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'food_type': _foodType,
      });
      await _load();
      if (mounted) {
        setState(() { _editing = false; _submitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update request submitted — pending admin review.'),
            backgroundColor: Color(0xFF0891B2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message),
              backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelPendingUpdate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
            'Cancel your pending profile update request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Request',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.cancelOwnerProfileUpdate();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update request cancelled.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message),
              backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFE),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text('My Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_loading && _profile != null && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Request Update',
              onPressed: _startEdit,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!,
                        style:
                            const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : _editing
                  ? _EditForm()
                  : _ProfileView(),
    );
  }

  Widget _ProfileView() {
    final p = _profile!;
    final r = p['restaurant'] as Map<String, dynamic>?;
    final pending = p['pending_update'] as Map<String, dynamic>?;
    final submittedAt = p['pending_update_submitted_at'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Pending update badge ────────────────────────────────────────
        if (pending != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF97316), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFF97316), size: 18),
                  const SizedBox(width: 8),
                  const Text('Update Pending Admin Review',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9A3412))),
                ]),
                if (submittedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Submitted ${_fmtDate(submittedAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFEA580C)),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelPendingUpdate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                    child: const Text('Cancel Request'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Owner details ─────────────────────────────────────────────────
        _SectionCard(
          title: 'Owner Details',
          icon: Icons.person_outline,
          color: _teal,
          children: [
            _InfoRow('Name', p['name'] as String? ?? '—'),
            _InfoRow('Mobile', p['mobile'] as String? ?? '—'),
            _InfoRow('Email',
                (p['email'] as String?)?.isNotEmpty == true
                    ? p['email'] as String
                    : '—'),
            _InfoRow('GSTIN',
                (p['gstin'] as String?)?.isNotEmpty == true
                    ? p['gstin'] as String
                    : '—'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Restaurant details ────────────────────────────────────────────
        if (r != null)
          _SectionCard(
            title: 'Restaurant Details',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFF059669),
            children: [
              _InfoRow('Name', r['name'] as String? ?? '—'),
              _InfoRow('Area', r['area'] as String? ?? '—'),
              _InfoRow('Address', r['address'] as String? ?? '—'),
              _InfoRow('Pincode', r['pincode'] as String? ?? '—'),
              _InfoRow('State', r['state'] as String? ?? '—'),
              _InfoRow('Food Type', r['food_type'] as String? ?? '—'),
              _InfoRow('Restaurant Code',
                  r['restaurant_code'] as String? ?? '—'),
            ],
          ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _startEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Request Profile Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Any updates require admin approval before they take effect.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _EditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0EA5E9)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Color(0xFF0369A1), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Changes will be reviewed and applied by admin.',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Owner Name'),
            TextFormField(
              controller: _ownerNameCtrl,
              validator: Validators.personName,
              decoration: _inputDec('Full name'),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Email'),
            TextFormField(
              controller: _emailCtrl,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDec('email@example.com'),
            ),
            const SizedBox(height: 20),

            const Text('Restaurant Details',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669))),
            const Divider(height: 16),

            _FieldLabel('Restaurant Name'),
            TextFormField(
              controller: _restaurantNameCtrl,
              validator: Validators.businessName,
              decoration: _inputDec('e.g. Noor Bhoj'),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Area'),
            TextFormField(
              controller: _areaCtrl,
              validator: Validators.area,
              decoration: _inputDec('e.g. Osmanpura'),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Address'),
            TextFormField(
              controller: _addressCtrl,
              validator: Validators.address,
              maxLines: 2,
              decoration: _inputDec('Full restaurant address'),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Food Type'),
            DropdownButtonFormField<String>(
              value: _foodType,
              items: _foodTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t[0].toUpperCase() + t.substring(1),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _foodType = v ?? _foodType),
              decoration: _inputDec(''),
            ),
            const SizedBox(height: 28),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _editing = false),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit for Review'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _teal, width: 2)),
      );
}

Widget _FieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
    );

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ]),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
