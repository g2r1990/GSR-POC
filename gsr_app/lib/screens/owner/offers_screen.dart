import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';

class OwnerOffersScreen extends StatefulWidget {
  const OwnerOffersScreen({super.key});

  @override
  State<OwnerOffersScreen> createState() => _OwnerOffersScreenState();
}

class _OwnerOffersScreenState extends State<OwnerOffersScreen> {
  static const _purple = Color(0xFF7C3AED);

  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final offers = await ApiService.getOwnerOffers();
      if (mounted) setState(() { _offers = offers; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load offers.'; _loading = false; });
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Offer'),
        content: const Text('This offer will be removed for all customers. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteOffer(id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddOfferSheet(
        onCreated: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        title: const Text('My Offers'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Offer',
            onPressed: _showAddSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Offer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : _offers.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.local_offer_outlined,
                            size: 64, color: Color(0xFFD8B4FE)),
                        const SizedBox(height: 16),
                        const Text('No offers yet',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1917))),
                        const SizedBox(height: 8),
                        const Text('Tap + New Offer to push a deal to customers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF78716C))),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _offers.length,
                        itemBuilder: (ctx, i) {
                          final o = _offers[i];
                          final validUntil = _formatDate(o['valid_until'] as String?);
                          final discount = o['discount_pct'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFEDE9FE)),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F3FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_offer,
                                      color: _purple, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(o['title'] as String? ?? '',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1C1917))),
                                      if ((o['description'] as String?)?.isNotEmpty == true) ...[
                                        const SizedBox(height: 3),
                                        Text(o['description'] as String,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF78716C))),
                                      ],
                                      const SizedBox(height: 6),
                                      Wrap(spacing: 6, children: [
                                        if (discount != null)
                                          _Badge(
                                            label: '${discount.toString()}% OFF',
                                            bg: const Color(0xFFF0FDF4),
                                            fg: const Color(0xFF166534),
                                          ),
                                        if (validUntil.isNotEmpty)
                                          _Badge(
                                            label: 'Valid till $validUntil',
                                            bg: const Color(0xFFFEF3C7),
                                            fg: const Color(0xFF92400E),
                                          ),
                                      ]),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Color(0xFFDC2626)),
                                  onPressed: () => _delete(o['id'] as String),
                                  tooltip: 'Delete',
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _AddOfferSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _AddOfferSheet({required this.onCreated});

  @override
  State<_AddOfferSheet> createState() => _AddOfferSheetState();
}

class _AddOfferSheetState extends State<_AddOfferSheet> {
  static const _purple = Color(0xFF7C3AED);
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discCtrl = TextEditingController();
  DateTime? _validUntil;
  TimeOfDay? _validTime;
  bool _saving = false;
  String? _error;

  // Menu items for the optional item picker
  List<Map<String, dynamic>> _menuItems = [];
  String? _selectedMenuItemId;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final items = await ApiService.getMenu();
      if (mounted) setState(() => _menuItems = items);
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      helpText: 'Select time (IST)',
    );
    setState(() {
      _validUntil = pickedDate;
      _validTime = pickedTime;
    });
  }

  String _formatValidUntil() {
    if (_validUntil == null) return 'Valid until (optional) — tap to set';
    final d = _validUntil!;
    final dateStr = '${d.day} ${_months[d.month]} ${d.year}';
    if (_validTime == null) return 'Valid until: $dateStr';
    final h = _validTime!.hourOfPeriod == 0 ? 12 : _validTime!.hourOfPeriod;
    final m = _validTime!.minute.toString().padLeft(2, '0');
    final ampm = _validTime!.period == DayPeriod.am ? 'AM' : 'PM';
    return 'Valid until: $dateStr at $h:$m $ampm IST';
  }

  DateTime? _combinedUtc() {
    if (_validUntil == null) return null;
    final d = _validUntil!;
    final t = _validTime ?? const TimeOfDay(hour: 23, minute: 59);
    // Device is in IST; toUtc() converts correctly.
    return DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final utcDt = _combinedUtc();
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_discCtrl.text.trim().isNotEmpty)
          'discount_pct': double.tryParse(_discCtrl.text.trim()),
        if (utcDt != null)
          'valid_until': utcDt.toIso8601String(),
      };
      await ApiService.createOffer(payload);
      widget.onCreated();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Connection error.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('New Offer',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917))),
            const SizedBox(height: 4),
            const Text(
              'Restaurant: your registered restaurant (multi-branch coming soon)',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),

            // Optional: link to a menu item
            if (_menuItems.isNotEmpty) ...[
              const Text('Menu Item (optional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _selectedMenuItemId,
                decoration: InputDecoration(
                  hintText: 'Select an item to highlight',
                  hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFEDE9FE))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFEDE9FE))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _purple, width: 2)),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('None — general offer')),
                  ..._menuItems.map((m) => DropdownMenuItem<String?>(
                        value: m['id'] as String?,
                        child: Text(
                          '${m['name']} — ₹${(m['price'] as num?)?.toStringAsFixed(0) ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedMenuItemId = val);
                  if (val != null) {
                    final item = _menuItems
                        .firstWhere((m) => m['id'] == val,
                            orElse: () => {});
                    final name = item['name'] as String? ?? '';
                    final disc = _discCtrl.text.trim();
                    if (name.isNotEmpty && _titleCtrl.text.trim().isEmpty) {
                      _titleCtrl.text = disc.isNotEmpty
                          ? '$disc% off on $name'
                          : 'Special offer on $name';
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            _SheetField(
              label: 'Offer Title *',
              hint: 'e.g. 20% off on all biryanis',
              controller: _titleCtrl,
              validator: Validators.offerTitle,
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Description (optional)',
              hint: 'Extra details for customers',
              controller: _descCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Discount % (optional)',
              hint: 'e.g. 20',
              controller: _discCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: Validators.discountPct,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                ),
                child: Row(children: [
                  const Icon(Icons.event, size: 18, color: _purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatValidUntil(),
                      style: TextStyle(
                          fontSize: 13,
                          color: _validUntil != null
                              ? const Color(0xFF1C1917)
                              : const Color(0xFF94A3B8)),
                    ),
                  ),
                  if (_validUntil != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _validUntil = null;
                        _validTime = null;
                      }),
                      child: const Icon(Icons.close, size: 18,
                          color: Color(0xFF94A3B8)),
                    ),
                ]),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFDC2626), fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Publish Offer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final int maxLines;

  const _SheetField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.formatters,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEDE9FE))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEDE9FE))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
        ),
      ),
    ]);
  }
}
