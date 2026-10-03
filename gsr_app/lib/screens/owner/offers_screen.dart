import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';

class OwnerOffersScreen extends StatefulWidget {
  const OwnerOffersScreen({super.key});

  @override
  State<OwnerOffersScreen> createState() => _OwnerOffersScreenState();
}

class _OwnerOffersScreenState extends State<OwnerOffersScreen>
    with TickerProviderStateMixin {
  static const _purple = Color(0xFF7C3AED);

  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _showAddSheet({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddOfferSheet(
        initialData: initialData,
        onCreated: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  bool _isExpired(String? iso) {
    if (iso == null) return false;
    try {
      final dt = DateTime.parse('${iso}Z');
      return dt.isBefore(DateTime.now().toUtc());
    } catch (_) {
      return false;
    }
  }

  String _formatDatetime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse('${iso}Z').toLocal();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = dt.hour > 12
          ? dt.hour - 12
          : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month]} ${dt.year}, $h:$m $ampm IST';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> get _activeOffers =>
      _offers.where((o) => !_isExpired(o['valid_until'] as String?)).toList();

  List<Map<String, dynamic>> get _historyOffers =>
      _offers.where((o) => _isExpired(o['valid_until'] as String?)).toList();

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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Active (${_loading ? '–' : _activeOffers.length})'),
            Tab(text: 'History (${_loading ? '–' : _historyOffers.length})'),
          ],
        ),
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildActiveTab() {
    final offers = _activeOffers;
    if (offers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_offer_outlined, size: 64, color: Color(0xFFD8B4FE)),
                SizedBox(height: 16),
                Text('No active offers',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917))),
                SizedBox(height: 8),
                Text('Tap + New Offer to push a deal to customers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF78716C))),
              ]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: offers.length,
        itemBuilder: (ctx, i) => _OfferCard(
          offer: offers[i],
          formatDatetime: _formatDatetime,
          onDelete: () => _delete(offers[i]['id'] as String),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final offers = _historyOffers;
    if (offers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: 64, color: Color(0xFFD8B4FE)),
                SizedBox(height: 16),
                Text('No expired offers yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917))),
                SizedBox(height: 8),
                Text('Expired offers appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF78716C))),
              ]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: offers.length,
        itemBuilder: (ctx, i) => _OfferCard(
          offer: offers[i],
          expired: true,
          formatDatetime: _formatDatetime,
          onRepost: () => _showAddSheet(initialData: offers[i]),
        ),
      ),
    );
  }
}

// ── Offer card ─────────────────────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  static const _purple = Color(0xFF7C3AED);
  final Map<String, dynamic> offer;
  final bool expired;
  final String Function(String?) formatDatetime;
  final VoidCallback? onDelete;
  final VoidCallback? onRepost;

  const _OfferCard({
    required this.offer,
    required this.formatDatetime,
    this.onDelete,
    this.expired = false,
    this.onRepost,
  });

  String _typeLabel() {
    final t = offer['offer_type'] as String? ?? 'order';
    final itemName = offer['menu_item_name'] as String? ?? '';
    final buyQty = offer['buy_qty'];
    final freeQty = offer['free_qty'];
    switch (t) {
      case 'item':
        return itemName.isNotEmpty ? 'Item: $itemName' : 'Specific Item';
      case 'bogo':
        if (buyQty != null && freeQty != null) {
          return 'Buy $buyQty Get $freeQty Free${itemName.isNotEmpty ? ' · $itemName' : ''}';
        }
        return 'Buy X Get Y Free';
      default:
        return 'Order-wide';
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount = offer['discount_pct'];
    final validDatetime = formatDatetime(offer['valid_until'] as String?);
    final offerType = offer['offer_type'] as String? ?? 'order';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: expired ? const Color(0xFFE5E7EB) : const Color(0xFFEDE9FE)),
      ),
      color: expired ? const Color(0xFFF9FAFB) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: expired ? const Color(0xFFF3F4F6) : const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                offerType == 'bogo' ? Icons.redeem
                    : offerType == 'item' ? Icons.restaurant_menu
                    : Icons.local_offer,
                color: expired ? const Color(0xFF9CA3AF) : _purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offer['title'] as String? ?? '',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: expired ? const Color(0xFF6B7280) : const Color(0xFF1C1917))),
                if ((offer['description'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(offer['description'] as String,
                      style: TextStyle(
                          fontSize: 13,
                          color: expired ? const Color(0xFF9CA3AF) : const Color(0xFF78716C))),
                ],
              ]),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _Badge(
              label: _typeLabel(),
              bg: expired ? const Color(0xFFF3F4F6) : const Color(0xFFEDE9FE),
              fg: expired ? const Color(0xFF9CA3AF) : _purple,
            ),
            if (discount != null && offerType != 'bogo')
              _Badge(
                label: '${discount.toString()}% OFF',
                bg: expired ? const Color(0xFFF3F4F6) : const Color(0xFFF0FDF4),
                fg: expired ? const Color(0xFF9CA3AF) : const Color(0xFF166534),
              ),
            if (validDatetime.isNotEmpty)
              _Badge(
                label: 'Valid till $validDatetime',
                bg: expired ? const Color(0xFFF3F4F6) : const Color(0xFFFEF3C7),
                fg: expired ? const Color(0xFF9CA3AF) : const Color(0xFF92400E),
              ),
            if (expired)
              _Badge(label: 'Expired', bg: const Color(0xFFFEE2E2), fg: const Color(0xFFDC2626)),
          ]),
          if (onRepost != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRepost,
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Re-post this offer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  side: const BorderSide(color: _purple),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ]),
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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ── Add / Re-post offer sheet ──────────────────────────────────────────────────

class _AddOfferSheet extends StatefulWidget {
  final VoidCallback onCreated;
  final Map<String, dynamic>? initialData;
  const _AddOfferSheet({required this.onCreated, this.initialData});

  @override
  State<_AddOfferSheet> createState() => _AddOfferSheetState();
}

class _AddOfferSheetState extends State<_AddOfferSheet> {
  static const _purple = Color(0xFF7C3AED);
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discCtrl = TextEditingController();
  final _buyQtyCtrl = TextEditingController();
  final _freeQtyCtrl = TextEditingController();

  DateTime? _validUntil;
  TimeOfDay? _validTime;
  bool _saving = false;
  String? _error;

  String _offerType = 'order';
  List<Map<String, dynamic>> _menuItems = [];
  String? _selectedMenuItemId;
  String? _selectedMenuItemName;

  // Auto-title state
  bool _applyingAutoTitle = false;
  String _lastAutoTitle = '';

  List<Map<String, dynamic>> _templates = [];
  static const _prefsKey = 'owner_offer_templates_v2';

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _discCtrl.addListener(_applyAutoTitle);
    _buyQtyCtrl.addListener(_applyAutoTitle);
    _freeQtyCtrl.addListener(_applyAutoTitle);
    _loadMenu();
    _loadTemplates();
    final d = widget.initialData;
    if (d != null) {
      _titleCtrl.text = d['title'] as String? ?? '';
      _lastAutoTitle = _titleCtrl.text;
      _descCtrl.text = d['description'] as String? ?? '';
      _offerType = (d['offer_type'] as String?) ?? 'order';
      final disc = d['discount_pct'];
      if (disc != null) _discCtrl.text = disc.toString();
      final buyQ = d['buy_qty'];
      if (buyQ != null) _buyQtyCtrl.text = buyQ.toString();
      final freeQ = d['free_qty'];
      if (freeQ != null) _freeQtyCtrl.text = freeQ.toString();
      _selectedMenuItemId = d['menu_item_id'] as String?;
      _selectedMenuItemName = d['menu_item_name'] as String?;
    }
  }

  // ── Auto-title ───────────────────────────────────────────────────────────────

  String _computeAutoTitle() {
    switch (_offerType) {
      case 'item':
        final name = _selectedMenuItemName ?? '';
        final disc = double.tryParse(_discCtrl.text.trim()) ?? 0;
        if (name.isEmpty || disc <= 0) return '';
        return '${disc.toStringAsFixed(0)}% off on $name';
      case 'bogo':
        final name = _selectedMenuItemName ?? '';
        final bq = int.tryParse(_buyQtyCtrl.text.trim()) ?? 0;
        final fq = int.tryParse(_freeQtyCtrl.text.trim()) ?? 0;
        if (name.isEmpty || bq <= 0 || fq <= 0) return '';
        return 'Buy $bq Get $fq Free · $name';
      case 'order':
        final disc = double.tryParse(_discCtrl.text.trim()) ?? 0;
        if (disc <= 0) return '';
        return '${disc.toStringAsFixed(0)}% off on your order';
      default:
        return '';
    }
  }

  void _applyAutoTitle() {
    if (_applyingAutoTitle) return;
    final auto = _computeAutoTitle();
    if (auto.isEmpty) return;
    if (_titleCtrl.text.isEmpty || _titleCtrl.text == _lastAutoTitle) {
      _applyingAutoTitle = true;
      _titleCtrl.text = auto;
      _titleCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: auto.length));
      _applyingAutoTitle = false;
      _lastAutoTitle = auto;
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadMenu() async {
    try {
      final items = await ApiService.getMenu();
      if (mounted) setState(() => _menuItems = items);
    } catch (_) {}
  }

  Future<void> _loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && mounted) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        setState(() => _templates = list);
      }
    } catch (_) {}
  }

  Future<void> _saveTemplate(Map<String, dynamic> payload) async {
    try {
      final template = {
        'title': payload['title'],
        if (payload['description'] != null) 'description': payload['description'],
        'offer_type': payload['offer_type'],
        if (payload['discount_pct'] != null) 'discount_pct': payload['discount_pct'],
        if (payload['menu_item_id'] != null) 'menu_item_id': payload['menu_item_id'],
        if (payload['menu_item_name'] != null) 'menu_item_name': payload['menu_item_name'],
        if (payload['buy_qty'] != null) 'buy_qty': payload['buy_qty'],
        if (payload['free_qty'] != null) 'free_qty': payload['free_qty'],
      };
      final updated = [
        template,
        ..._templates.where((t) => t['title'] != template['title']),
      ].take(5).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(updated));
    } catch (_) {}
  }

  void _applyTemplate(Map<String, dynamic> t) {
    setState(() {
      _offerType = (t['offer_type'] as String?) ?? 'order';
      _discCtrl.text = t['discount_pct'] != null ? t['discount_pct'].toString() : '';
      _buyQtyCtrl.text = t['buy_qty'] != null ? t['buy_qty'].toString() : '';
      _freeQtyCtrl.text = t['free_qty'] != null ? t['free_qty'].toString() : '';
      _selectedMenuItemId = t['menu_item_id'] as String?;
      _selectedMenuItemName = t['menu_item_name'] as String?;
    });
    // Re-apply title from template (override auto-title)
    final title = t['title'] as String? ?? '';
    _lastAutoTitle = '';
    _titleCtrl.text = title;
    _lastAutoTitle = title;
    _descCtrl.text = t['description'] as String? ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discCtrl.dispose();
    _buyQtyCtrl.dispose();
    _freeQtyCtrl.dispose();
    super.dispose();
  }

  // ── Date/time picker ─────────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
      helpText: 'Select expiry time (IST)',
    );
    setState(() {
      _validUntil = pickedDate;
      _validTime = pickedTime;
    });
  }

  String _formatValidUntil() {
    if (_validUntil == null) return 'Valid until * — tap to set';
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
    return DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc();
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_offerType != 'order' && _selectedMenuItemId == null) {
      setState(() => _error = 'Please select a menu item for this offer type.');
      return;
    }
    if (_offerType == 'bogo') {
      final bq = int.tryParse(_buyQtyCtrl.text.trim()) ?? 0;
      final fq = int.tryParse(_freeQtyCtrl.text.trim()) ?? 0;
      if (bq <= 0 || fq <= 0) {
        setState(() => _error = 'Buy qty and Free qty must both be at least 1.');
        return;
      }
    }
    if (_validUntil == null) {
      setState(() => _error = 'Please set a valid until date for this offer.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final utcDt = _combinedUtc();
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'offer_type': _offerType,
        if (_offerType != 'bogo' && _discCtrl.text.trim().isNotEmpty)
          'discount_pct': double.tryParse(_discCtrl.text.trim()),
        if (_offerType != 'order') ...{
          'menu_item_id': _selectedMenuItemId,
          'menu_item_name': _selectedMenuItemName,
        },
        if (_offerType == 'bogo') ...{
          'buy_qty': int.tryParse(_buyQtyCtrl.text.trim()),
          'free_qty': int.tryParse(_freeQtyCtrl.text.trim()),
        },
        if (utcDt != null) 'valid_until': utcDt.toIso8601String(),
      };
      await ApiService.createOffer(payload);
      await _saveTemplate(payload);
      widget.onCreated();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Connection error.'; _saving = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.initialData != null ? 'Re-post Offer' : 'New Offer',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917))),
            const SizedBox(height: 16),

            // ── Past templates ─────────────────────────────────────────
            if (_templates.isNotEmpty) ...[
              const Text('Reuse a Past Offer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _templates.map((t) {
                    final disc = t['discount_pct'];
                    final bq = t['buy_qty'];
                    final fq = t['free_qty'];
                    final label = (bq != null && fq != null)
                        ? '${t['title']} (B$bq G$fq)'
                        : disc != null
                            ? '${t['title']} ($disc% off)'
                            : t['title'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _applyTemplate(t),
                        backgroundColor: const Color(0xFFF5F3FF),
                        side: const BorderSide(color: Color(0xFFEDE9FE)),
                        avatar: const Icon(Icons.history,
                            size: 16, color: Color(0xFF7C3AED)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Offer type selector ────────────────────────────────────
            const Text('Offer Type',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            _OfferTypeSelector(
              value: _offerType,
              onChanged: (v) {
                setState(() { _offerType = v; _error = null; });
                _applyAutoTitle();
              },
            ),
            const SizedBox(height: 16),

            // ── Menu item dropdown (item / bogo) ───────────────────────
            if (_offerType != 'order') ...[
              const Text('Menu Item *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _menuItems.any((m) => m['id'] == _selectedMenuItemId)
                    ? _selectedMenuItemId
                    : null,
                decoration: _dropdownDecor('Select a menu item'),
                items: _menuItems.map((m) => DropdownMenuItem<String?>(
                  value: m['id'] as String?,
                  child: Text(m['name'] as String? ?? '',
                      overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedMenuItemId = val;
                    if (val != null) {
                      final item = _menuItems
                          .firstWhere((m) => m['id'] == val, orElse: () => {});
                      _selectedMenuItemName = item['name'] as String?;
                    } else {
                      _selectedMenuItemName = null;
                    }
                  });
                  _applyAutoTitle();
                },
              ),
              const SizedBox(height: 12),
            ],

            // ── BOGO qty fields ────────────────────────────────────────
            if (_offerType == 'bogo') ...[
              Row(children: [
                Expanded(
                  child: _SheetField(
                    label: 'Buy Qty *',
                    hint: 'e.g. 2',
                    controller: _buyQtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter ≥1';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SheetField(
                    label: 'Free Qty *',
                    hint: 'e.g. 1',
                    controller: _freeQtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter ≥1';
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Discount % (order / item) ──────────────────────────────
            if (_offerType != 'bogo') ...[
              _SheetField(
                label: _offerType == 'item'
                    ? 'Discount % on this item *'
                    : 'Discount % *',
                hint: 'e.g. 20',
                controller: _discCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0 || n > 100) return 'Enter 1–100';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // ── Offer title ────────────────────────────────────────────
            _SheetField(
              label: 'Offer Title *',
              hint: 'Auto-filled — you can edit it',
              controller: _titleCtrl,
              validator: Validators.offerTitle,
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Description (optional)',
              hint: 'What does this offer include?',
              controller: _descCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // ── Valid until (mandatory) ────────────────────────────────
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _validUntil == null
                      ? const Color(0xFFFFF1F2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _validUntil == null
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFEDE9FE)),
                ),
                child: Row(children: [
                  Icon(Icons.schedule,
                      color: _validUntil == null
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF7C3AED),
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatValidUntil(),
                      style: TextStyle(
                          fontSize: 14,
                          color: _validUntil == null
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF1C1917)),
                    ),
                  ),
                  if (_validUntil != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _validUntil = null;
                        _validTime = null;
                      }),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF94A3B8)),
                    ),
                ]),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        widget.initialData != null ? 'Re-post Offer' : 'Publish Offer',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecor(String hint) => InputDecoration(
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
            borderSide: const BorderSide(color: _purple, width: 2)),
      );
}

// ── Offer type selector ────────────────────────────────────────────────────────

class _OfferTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  static const _types = [
    ('order', Icons.shopping_cart_outlined, 'Whole Order'),
    ('item', Icons.restaurant_menu, 'Specific Item'),
    ('bogo', Icons.redeem, 'Buy X Get Y'),
  ];

  const _OfferTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _types.map((t) {
        final selected = value == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(t.$1),
            child: Container(
              margin: EdgeInsets.only(right: t.$1 == 'bogo' ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF7C3AED) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFEDE9FE)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.$2,
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFF6B7280)),
                const SizedBox(height: 4),
                Text(t.$3,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF6B7280))),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Sheet field ────────────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _SheetField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFDC2626), width: 2)),
        ),
      ),
    ]);
  }
}
