import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/offer_service.dart';
import '../../utils/validators.dart';
import '../../services/cart_service.dart';
import 'order_confirm_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver {
  static const _amber = Color(0xFFD97706);

  // Restaurant capabilities (loaded from API at init)
  bool _allowsTakeaway = false;
  bool _providesCutlery = false;
  bool _codEnabled = false;
  double _gstRate = 5.0;
  double _cutleryFee = 0.0;
  int _cancellationWindowMins = 1;

  // Order options
  String _orderType = 'delivery';   // 'delivery' | 'takeaway'
  String _paymentMethod = 'online'; // 'online'   | 'cod'
  String? _spiceLevel;              // null | 'less_spicy' | 'medium_spicy' | 'spicy'
  bool _cutleryRequested = false;
  double _riderTip = 0.0;

  late final String _idempotencyKey;

  // Offer
  bool get _offerApplied =>
      OfferService.hasOffer &&
      OfferService.restaurantId == CartService.restaurantId;

  final _formKey = GlobalKey<FormState>();
  final _nameCtr    = TextEditingController();
  final _phoneCtr   = TextEditingController();
  final _addressCtr = TextEditingController();
  final _instrCtr   = TextEditingController();
  final _tipCtr     = TextEditingController(text: '0');

  bool _placing = false;
  bool _detectingAddress = false;
  String? _error;
  String _customerArea = '';
  bool _shouldPopOnResume = false;
  double? _deliveryLat;
  double? _deliveryLng;

  // ── Billing ──────────────────────────────────────────────────────────────

  double get _foodTotal => CartService.total;

  double get _discountAmount {
    if (!_offerApplied) return 0;
    final type = OfferService.offerType;
    if (type == 'item') {
      final mid = OfferService.menuItemId;
      if (mid == null) return 0;
      final matched = CartService.items
          .where((i) => i.itemId == mid)
          .fold<double>(0, (s, i) => s + i.price * i.qty);
      return double.parse(
          (matched * OfferService.discountPct / 100).toStringAsFixed(2));
    }
    if (type == 'bogo') {
      final mid = OfferService.menuItemId;
      final buyQty = OfferService.buyQty;
      if (mid == null || buyQty <= 0) return 0;
      final matched = CartService.items.where((i) => i.itemId == mid).toList();
      if (matched.isEmpty) return 0;
      final item = matched.first;
      if (item.qty < buyQty) return 0;
      return double.parse(
          (OfferService.freeQty * item.price).toStringAsFixed(2));
    }
    return double.parse(
        (_foodTotal * OfferService.discountPct / 100).toStringAsFixed(2));
  }

  double get _taxableAmount  => _foodTotal - _discountAmount;
  double get _gstAmount      => _orderType == 'delivery'
      ? double.parse((_taxableAmount * _gstRate / 100).toStringAsFixed(2))
      : 0.0;
  double get _deliveryFee    => _orderType == 'delivery' ? 20.0 : 0.0;
  double get _cutleryFeeAmt  => (_cutleryRequested && _providesCutlery) ? _cutleryFee : 0.0;
  double get _effectiveTip   => (_paymentMethod == 'cod' || _orderType == 'takeaway') ? 0.0 : _riderTip;
  double get _customerPays   =>
      _taxableAmount + _gstAmount + _deliveryFee + _cutleryFeeAmt + _effectiveTip;

  String _offerBannerText() {
    final type = OfferService.offerType;
    final title = OfferService.title;
    if (type == 'bogo') {
      return 'Buy ${OfferService.buyQty} Get ${OfferService.freeQty} Free applied! $title';
    }
    if (type == 'item') {
      return '${OfferService.discountPct.toStringAsFixed(0)}% off on ${OfferService.menuItemName}';
    }
    return '${OfferService.discountPct.toStringAsFixed(0)}% off applied! $title';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _idempotencyKey = _uuid();
    _prefillFromOnboarding();
    _loadRestaurantInfo();
  }

  String _uuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }

  Future<void> _loadRestaurantInfo() async {
    final rid = CartService.restaurantId ?? '';
    if (rid.isEmpty) return;
    try {
      final data = await ApiService.getRestaurantMenu(rid);
      final info = data['restaurant'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _allowsTakeaway      = info['allows_takeaway']          as bool?   ?? false;
          _providesCutlery     = info['provides_cutlery']         as bool?   ?? false;
          _codEnabled          = info['cod_enabled']              as bool?   ?? false;
          _gstRate             = (info['gst_rate']                as num?)?.toDouble() ?? 5.0;
          _cutleryFee          = (info['cutlery_fee']             as num?)?.toDouble() ?? 0.0;
          _cancellationWindowMins = info['cancellation_window_mins'] as int? ?? 1;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _shouldPopOnResume = true;
    } else if (state == AppLifecycleState.resumed && _shouldPopOnResume) {
      _shouldPopOnResume = false;
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/customer/home', (_) => false);
    }
  }

  Future<void> _prefillFromOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final name    = prefs.getString('customer_name')    ?? '';
    final phone   = prefs.getString('customer_phone')   ?? '';
    final saved   = prefs.getString('customer_address') ?? '';
    final area    = prefs.getString('customer_area')    ?? '';
    if (mounted && name.isNotEmpty)  _nameCtr.text  = name;
    if (mounted && phone.isNotEmpty) _phoneCtr.text  = phone;
    if (mounted && area.isNotEmpty)  setState(() => _customerArea = area);
    if (saved.isNotEmpty) {
      if (mounted) _addressCtr.text = saved;
    } else {
      final district = prefs.getString('customer_district') ?? '';
      final state    = prefs.getString('customer_state')    ?? '';
      final pincode  = prefs.getString('customer_pincode')  ?? '';
      final parts    = [area, district, state, pincode].where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty && mounted) _addressCtr.text = parts.join(', ');
      _detectAddress();
    }
  }

  Future<void> _detectAddress() async {
    if (mounted) setState(() => _detectingAddress = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detectingAddress = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      _deliveryLat = pos.latitude;
      _deliveryLng = pos.longitude;
      final addr = await ApiService.getFullAddressFromCoords(pos.latitude, pos.longitude);
      if (addr != null && addr.isNotEmpty && mounted) {
        _addressCtr.text = addr;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_address', addr);
      }
    } catch (_) {}
    if (mounted) setState(() => _detectingAddress = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameCtr.dispose();
    _phoneCtr.dispose();
    _addressCtr.dispose();
    _instrCtr.dispose();
    _tipCtr.dispose();
    super.dispose();
  }

  // ── Place order ───────────────────────────────────────────────────────────

  Future<void> _place() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _placing = true; _error = null; });

    try {
      // Re-check accepting orders
      final rid = CartService.restaurantId ?? '';
      if (rid.isNotEmpty) {
        try {
          final data = await ApiService.getRestaurantMenu(rid);
          final info = data['restaurant'] as Map<String, dynamic>? ?? {};
          if (!(info['is_accepting_orders'] as bool? ?? true)) {
            if (mounted) setState(() {
              _placing = false;
              _error = 'This restaurant is currently not accepting orders.';
            });
            return;
          }
        } catch (_) {}
      }

      final capturedDiscount  = _discountAmount;
      final capturedOfferCode = _offerApplied && OfferService.offerCode.isNotEmpty
          ? OfferService.offerCode : '';

      final payload = <String, dynamic>{
        'restaurant_id':    CartService.restaurantId,
        'customer_name':    _nameCtr.text.trim(),
        'customer_phone':   _phoneCtr.text.trim(),
        'order_type':       _orderType,
        'payment_method':   _paymentMethod,
        'items':            CartService.toOrderItems(),
        'customer_area':    _customerArea.isNotEmpty ? _customerArea : null,
        'idempotency_key':  _idempotencyKey,
        'cutlery_requested': _cutleryRequested,
        'rider_tip':        _effectiveTip,
        'discount_amount':  capturedDiscount,
        if (_spiceLevel != null) 'spice_level': _spiceLevel,
        if (_instrCtr.text.trim().isNotEmpty) 'special_instructions': _instrCtr.text.trim(),
        if (capturedOfferCode.isNotEmpty) 'offer_code': capturedOfferCode,
      };

      if (_orderType == 'delivery') {
        payload['delivery_address'] = _addressCtr.text.trim();
        if (_deliveryLat != null) payload['delivery_lat'] = _deliveryLat;
        if (_deliveryLng != null) payload['delivery_lng'] = _deliveryLng;
      }

      final result = await ApiService.placeOrder(payload);
      CartService.clear();
      OfferService.clear();

      final orderId = result['order_id'] as String;
      final shortId = result['short_id'] as String;
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString('active_orders') ?? '[]';
      List<dynamic> list;
      try { list = jsonDecode(raw) as List<dynamic>; } catch (_) { list = []; }
      list.add({'order_id': orderId, 'short_id': shortId});
      await prefs.setString('active_orders', jsonEncode(list));

      if (capturedOfferCode.isNotEmpty) {
        final usedRaw = prefs.getString('used_offer_codes') ?? '[]';
        List<dynamic> used;
        try { used = jsonDecode(usedRaw) as List<dynamic>; } catch (_) { used = []; }
        if (!used.contains(capturedOfferCode)) {
          used.add(capturedOfferCode);
          await prefs.setString('used_offer_codes', jsonEncode(used));
        }
        final mapRaw = prefs.getString('order_offer_map') ?? '{}';
        Map<String, dynamic> offerMap;
        try { offerMap = jsonDecode(mapRaw) as Map<String, dynamic>; } catch (_) { offerMap = {}; }
        offerMap[orderId] = capturedOfferCode;
        await prefs.setString('order_offer_map', jsonEncode(offerMap));
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OrderConfirmScreen(
            orderId: orderId,
            shortId: shortId,
            total: (result['customer_pays'] as num?)?.toDouble() ??
                   (result['total']         as num).toDouble(),
            deliveryFee: _deliveryFee,
            gst: _gstAmount,
            createdAt: result['created_at'] as String?,
            offerCode: capturedOfferCode,
            discountAmount: capturedDiscount,
            orderType: _orderType,
            paymentMethod: _paymentMethod,
            pickupCode: result['pickup_code'] as String?,
            cancellationWindowMins: _cancellationWindowMins,
          ),
        ),
        (r) => r.isFirst,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showTip = _paymentMethod == 'online' && _orderType == 'delivery';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Checkout'),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFFDE68A), width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12))),
                    ]),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _placing ? null : _place,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _placing
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          '${_orderType == "takeaway" ? "Place Takeaway" : "Place Order"}  •  ₹${_customerPays.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Offer banner ─────────────────────────────────────────
                if (_offerApplied) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEDE9FE)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_offer, color: Color(0xFF7C3AED), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_offerBannerText(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6D28D9), fontWeight: FontWeight.w500))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Order type ───────────────────────────────────────────
                if (_allowsTakeaway) ...[
                  _SectionHeader('Order Type'),
                  _ChipRow(
                    options: const [
                      _ChipOption('delivery',  Icons.delivery_dining,      'Delivery'),
                      _ChipOption('takeaway',  Icons.shopping_bag_outlined, 'Takeaway'),
                    ],
                    selected: _orderType,
                    onSelect: (v) => setState(() {
                      _orderType = v;
                      if (v == 'takeaway') { _riderTip = 0; _tipCtr.text = '0'; }
                    }),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Items ────────────────────────────────────────────────
                _SectionHeader('Items Ordered'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: Scrollbar(
                      thumbVisibility: CartService.items.length > 3,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        shrinkWrap: true,
                        children: CartService.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(child: Text('${item.qty}× ${item.name}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                            Text('₹${(item.price * item.qty).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF78716C))),
                          ]),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Food preferences ─────────────────────────────────────
                _SectionHeader('Food Preferences'),
                const Text('Spice Level',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78716C))),
                const SizedBox(height: 8),
                _ChipRow(
                  options: const [
                    _ChipOption('less_spicy',   Icons.whatshot_outlined,       'Mild'),
                    _ChipOption('medium_spicy', Icons.whatshot,                'Medium'),
                    _ChipOption('spicy',        Icons.local_fire_department,   'Spicy'),
                  ],
                  selected: _spiceLevel,
                  onSelect: (v) => setState(() => _spiceLevel = (_spiceLevel == v) ? null : v),
                ),
                const SizedBox(height: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Special Instructions (optional)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78716C))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _instrCtr,
                    maxLines: 2,
                    decoration: _inputDec('Any requests for the restaurant…'),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Cutlery ──────────────────────────────────────────────
                if (_providesCutlery) ...[
                  _SectionHeader('Extras'),
                  _ToggleRow(
                    icon: Icons.restaurant,
                    label: 'Cutlery',
                    sublabel: _cutleryFee > 0
                        ? '+ ₹${_cutleryFee.toStringAsFixed(0)}'
                        : 'Free',
                    value: _cutleryRequested,
                    onChanged: (v) => setState(() => _cutleryRequested = v),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Payment method ───────────────────────────────────────
                if (_codEnabled) ...[
                  _SectionHeader('Payment Method'),
                  _ChipRow(
                    options: const [
                      _ChipOption('online', Icons.payment, 'Online / UPI'),
                      _ChipOption('cod',    Icons.money,   'Cash on Delivery'),
                    ],
                    selected: _paymentMethod,
                    onSelect: (v) => setState(() {
                      _paymentMethod = v;
                      if (v == 'cod') { _riderTip = 0; _tipCtr.text = '0'; }
                    }),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Rider tip ────────────────────────────────────────────
                if (showTip) ...[
                  _SectionHeader('Rider Tip (Optional)'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.volunteer_activism, size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Tip your rider',
                          style: TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _tipCtr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?')),
                          ],
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFD97706), width: 2)),
                          ),
                          onChanged: (v) => setState(() => _riderTip = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Bill summary ─────────────────────────────────────────
                _SectionHeader('Bill Summary'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(children: [
                    if (_offerApplied && _discountAmount > 0) ...[
                      _BillRow(label: 'Item Subtotal', value: '₹${_foodTotal.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      _BillRow(
                        label: 'Offer${OfferService.offerCode.isNotEmpty ? " (${OfferService.offerCode})" : ""}',
                        value: '-₹${_discountAmount.toStringAsFixed(0)}',
                        valueColor: const Color(0xFF166534),
                      ),
                      const Divider(height: 16),
                    ],
                    _BillRow(label: 'Food Total', value: '₹${_taxableAmount.toStringAsFixed(0)}', bold: true),
                    const SizedBox(height: 8),
                    _BillRow(
                      label: _orderType == 'delivery'
                          ? 'GST (${_gstRate.toStringAsFixed(0)}%)'
                          : 'GST',
                      value: '₹${_gstAmount.toStringAsFixed(2)}',
                      sublabel: _orderType == 'takeaway' ? 'No GST on takeaway' : null,
                    ),
                    const SizedBox(height: 8),
                    _BillRow(
                      label: 'Delivery Fee',
                      value: '₹${_deliveryFee.toStringAsFixed(0)}',
                      sublabel: _orderType == 'takeaway' ? 'Free for takeaway' : null,
                    ),
                    if (_cutleryFeeAmt > 0) ...[
                      const SizedBox(height: 8),
                      _BillRow(label: 'Cutlery', value: '₹${_cutleryFeeAmt.toStringAsFixed(0)}'),
                    ],
                    if (_effectiveTip > 0) ...[
                      const SizedBox(height: 8),
                      _BillRow(label: 'Rider Tip', value: '₹${_effectiveTip.toStringAsFixed(0)}'),
                    ],
                    const Divider(height: 20),
                    _BillRow(
                      label: 'To Pay',
                      value: '₹${_customerPays.toStringAsFixed(0)}',
                      bold: true,
                      valueColor: _amber,
                    ),
                    if (_paymentMethod == 'cod') ...[
                      const SizedBox(height: 6),
                      const Row(children: [
                        Icon(Icons.info_outline, size: 12, color: Color(0xFF78716C)),
                        SizedBox(width: 4),
                        Text('Cash on Delivery — pay rider at your door',
                            style: TextStyle(fontSize: 11, color: Color(0xFF78716C))),
                      ]),
                    ],
                    if (_orderType == 'takeaway') ...[
                      const SizedBox(height: 6),
                      const Row(children: [
                        Icon(Icons.info_outline, size: 12, color: Color(0xFF78716C)),
                        SizedBox(width: 4),
                        Text('Takeaway — collect from restaurant with your pickup code',
                            style: TextStyle(fontSize: 11, color: Color(0xFF78716C))),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Your details ─────────────────────────────────────────
                _SectionHeader('Your Details'),
                if (_customerArea.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.place_outlined, color: Color(0xFF166634), size: 16),
                      const SizedBox(width: 8),
                      const Text('Area: ', style: TextStyle(fontSize: 12, color: Color(0xFF166634), fontWeight: FontWeight.w600)),
                      Text(_customerArea, style: const TextStyle(fontSize: 13, color: Color(0xFF1C1917), fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                _Field(label: 'Your Name', hint: 'Full name', controller: _nameCtr, validator: Validators.personName),
                const SizedBox(height: 12),
                _Field(
                  label: 'Mobile Number',
                  hint: '10-digit number',
                  controller: _phoneCtr,
                  keyboardType: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validators.mobile,
                ),

                // ── Delivery address (delivery only) ─────────────────────
                if (_orderType == 'delivery') ...[
                  const SizedBox(height: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Delivery Address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const Spacer(),
                      _detectingAddress
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)))
                          : GestureDetector(
                              onTap: _detectAddress,
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.my_location, size: 14, color: Color(0xFFD97706)),
                                SizedBox(width: 4),
                                Text('Detect', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                              ]),
                            ),
                    ]),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressCtr,
                      maxLines: 3,
                      validator: Validators.address,
                      decoration: _inputDec('Full delivery address'),
                    ),
                  ]),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD97706), width: 2)),
    errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
  );
}

// ── Support widgets ───────────────────────────────────────────────────────────

class _ChipOption {
  final String value;
  final IconData icon;
  final String label;
  const _ChipOption(this.value, this.icon, this.label);
}

class _ChipRow extends StatelessWidget {
  final List<_ChipOption> options;
  final String? selected;
  final void Function(String) onSelect;

  const _ChipRow({required this.options, required this.selected, required this.onSelect});

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final active = selected == opt.value;
        return GestureDetector(
          onTap: () => onSelect(opt.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? _amber : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _amber : const Color(0xFFD1D5DB)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(opt.icon, size: 16, color: active ? Colors.white : const Color(0xFF78716C)),
              const SizedBox(width: 6),
              Text(opt.label, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF374151))),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.icon, required this.label, required this.sublabel,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFFD97706)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          Text(sublabel, style: const TextStyle(fontSize: 11, color: Color(0xFF78716C))),
        ]),
        const Spacer(),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFFD97706)),
      ]),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final String? sublabel;
  final bool bold;
  final Color? valueColor;

  const _BillRow({required this.label, required this.value, this.sublabel, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF374151))),
              if (sublabel != null)
                Text(sublabel!, style: const TextStyle(fontSize: 11, color: Color(0xFFA8A29E))),
            ],
          ),
        ),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? const Color(0xFF374151))),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final int? maxLines;

  const _Field({
    required this.label, required this.hint, required this.controller,
    this.keyboardType, this.formatters, this.validator, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD97706), width: 2)),
          errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
        ),
      ),
    ]);
  }
}
