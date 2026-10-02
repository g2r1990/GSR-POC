import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import 'order_confirm_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _amber = Color(0xFFD97706);
  static const _deliveryFee = 20.0;

  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _addressCtr = TextEditingController();
  final _notesCtr = TextEditingController();

  bool _placing = false;
  bool _detectingAddress = false;
  String? _error;

  double get _itemTotal => CartService.total;
  double get _gst => double.parse((_itemTotal * 0.05).toStringAsFixed(2));
  double get _grandTotal => _itemTotal + _deliveryFee + _gst;

  @override
  void initState() {
    super.initState();
    _prefillFromOnboarding();
  }

  Future<void> _prefillFromOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('customer_name') ?? '';
    final phone = prefs.getString('customer_phone') ?? '';
    final savedAddress = prefs.getString('customer_address') ?? '';
    if (mounted && name.isNotEmpty) _nameCtr.text = name;
    if (mounted && phone.isNotEmpty) _phoneCtr.text = phone;
    if (savedAddress.isNotEmpty) {
      if (mounted) _addressCtr.text = savedAddress;
    } else {
      // Compose a basic address from stored location data
      final district = prefs.getString('customer_district') ?? '';
      final state = prefs.getString('customer_state') ?? '';
      final pincode = prefs.getString('customer_pincode') ?? '';
      final parts = [district, state, pincode].where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty && mounted) _addressCtr.text = parts.join(', ');
      // Then try GPS for a more precise address
      _detectAddress();
    }
  }

  Future<void> _detectAddress() async {
    if (mounted) setState(() => _detectingAddress = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detectingAddress = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      final address =
          await ApiService.getFullAddressFromCoords(pos.latitude, pos.longitude);
      if (address != null && address.isNotEmpty && mounted) {
        _addressCtr.text = address;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_address', address);
      }
    } catch (_) {}
    if (mounted) setState(() => _detectingAddress = false);
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _phoneCtr.dispose();
    _addressCtr.dispose();
    _notesCtr.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _placing = true; _error = null; });

    try {
      final result = await ApiService.placeOrder({
        'restaurant_id': CartService.restaurantId,
        'customer_name': _nameCtr.text.trim(),
        'customer_phone': _phoneCtr.text.trim(),
        'delivery_address': _addressCtr.text.trim(),
        'notes': _notesCtr.text.trim().isEmpty ? null : _notesCtr.text.trim(),
        'items': CartService.toOrderItems(),
      });

      CartService.clear();

      // Persist active order so home screen can show "Track Order" banner
      final orderId = result['order_id'] as String;
      final shortId = result['short_id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_order_id', orderId);
      await prefs.setString('active_order_short_id', shortId);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OrderConfirmScreen(
            orderId: orderId,
            shortId: shortId,
            total: (result['total'] as num).toDouble(),
            deliveryFee: _deliveryFee,
            gst: _gst,
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

  @override
  Widget build(BuildContext context) {
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
                      const Icon(Icons.error_outline,
                          color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFFDC2626), fontSize: 12))),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _placing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          'Place Order  •  ₹${_grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
              // Items ordered
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
                          Expanded(
                              child: Text('${item.qty}× ${item.name}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF374151)))),
                          Text(
                              '₹${(item.price * item.qty).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF78716C))),
                        ]),
                      )).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bill Summary (Zomato-style breakdown)
              _SectionHeader('Bill Summary'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(children: [
                  _BillRow(
                    label: 'Item total',
                    value: '₹${_itemTotal.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _BillRow(
                    label: 'Delivery fee',
                    value: '₹${_deliveryFee.toStringAsFixed(0)}',
                    sublabel: 'Flat rate for POC',
                  ),
                  const SizedBox(height: 8),
                  _BillRow(
                    label: 'GST (5%)',
                    value: '₹${_gst.toStringAsFixed(2)}',
                    sublabel: 'Govt. taxes on food',
                  ),
                  const Divider(height: 20),
                  _BillRow(
                    label: 'To Pay',
                    value: '₹${_grandTotal.toStringAsFixed(0)}',
                    bold: true,
                    valueColor: _amber,
                  ),
                ]),
              ),

              const SizedBox(height: 24),
              _SectionHeader('Delivery Details'),

              _Field(
                label: 'Your Name',
                hint: 'Full name',
                controller: _nameCtr,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Mobile Number',
                hint: '10-digit number',
                controller: _phoneCtr,
                keyboardType: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 10) return 'Enter 10 digits';
                  return null;
                },
              ),
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                    hintText: 'Full delivery address',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFFDE68A))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFFDE68A))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFD97706), width: 2)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFDC2626))),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _Field(
                label: 'Special Instructions (optional)',
                hint: 'Any requests for the restaurant',
                controller: _notesCtr,
                maxLines: 2,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final String? sublabel;
  final bool bold;
  final Color? valueColor;

  const _BillRow({
    required this.label,
    required this.value,
    this.sublabel,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: bold ? 14 : 13,
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal,
                      color: const Color(0xFF374151))),
              if (sublabel != null)
                Text(sublabel!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFA8A29E))),
            ],
          ),
        ),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
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
      child: Text(text,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E))),
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
          hintStyle:
              const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFDE68A))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFDE68A))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFD97706), width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
        ),
      ),
    ]);
  }
}
