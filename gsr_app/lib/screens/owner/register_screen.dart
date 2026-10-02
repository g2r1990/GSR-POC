import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import 'pending_screen.dart';

class OwnerRegisterScreen extends StatefulWidget {
  const OwnerRegisterScreen({super.key});

  @override
  State<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends State<OwnerRegisterScreen> {
  static const _green = Color(0xFF166534);
  static const _greenLight = Color(0xFF059669);

  final _formKey = GlobalKey<FormState>();

  // Owner details
  final _nameCtr = TextEditingController();
  final _mobileCtr = TextEditingController();
  final _passCtr = TextEditingController();
  final _confirmPassCtr = TextEditingController();
  bool _obscurePass = true;

  // Restaurant details
  final _restNameCtr = TextEditingController();
  final _addressCtr = TextEditingController();
  final _areaCtr = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _gstinCtr = TextEditingController();
  String _foodType = 'both';

  bool _detecting = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _autoDetectLocation();
  }

  @override
  void dispose() {
    for (final c in [_nameCtr, _mobileCtr, _passCtr, _confirmPassCtr,
        _restNameCtr, _addressCtr, _areaCtr, _pincodeCtrl, _stateCtrl, _gstinCtr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _detecting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detecting = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final loc = await ApiService.getLocationFromCoords(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          if (loc['pincode'] != null) _pincodeCtrl.text = loc['pincode']!;
          if (loc['state'] != null) _stateCtrl.text = loc['state']!;
          _detecting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await ApiService.ownerRegister(
        name: _nameCtr.text.trim(),
        mobile: _mobileCtr.text.trim(),
        password: _passCtr.text,
        restaurantName: _restNameCtr.text.trim(),
        address: _addressCtr.text.trim(),
        area: _areaCtr.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        foodType: _foodType,
        gstin: _gstinCtr.text.trim().isEmpty ? null : _gstinCtr.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OwnerPendingScreen(mobile: _mobileCtr.text.trim()),
      ));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Register Your Restaurant'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _sectionHeader('Owner Details'),
              _field(label: 'Your Full Name', hint: 'As on ID proof', controller: _nameCtr,
                  validator: Validators.personName),
              const SizedBox(height: 12),
              _field(
                label: 'Mobile Number',
                hint: '10-digit number',
                controller: _mobileCtr,
                keyboard: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.mobile,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Password',
                hint: 'Min 8 chars with letters & numbers',
                controller: _passCtr,
                obscure: _obscurePass,
                onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                validator: Validators.password,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Confirm Password',
                hint: 'Re-enter password',
                controller: _confirmPassCtr,
                obscure: _obscurePass,
                validator: (v) => Validators.confirmPassword(v, _passCtr.text),
              ),

              const SizedBox(height: 28),
              _sectionHeader('Restaurant Details'),
              _field(label: 'Restaurant Name', hint: 'As displayed to customers',
                  controller: _restNameCtr,
                  validator: Validators.businessName),
              const SizedBox(height: 12),
              _field(label: 'Full Address', hint: 'Building, street, landmark',
                  controller: _addressCtr, maxLines: 3,
                  validator: Validators.address),
              const SizedBox(height: 12),
              _field(label: 'Area / Locality', hint: 'e.g. Osmanpura, Cidco',
                  controller: _areaCtr,
                  validator: Validators.area),
              const SizedBox(height: 16),

              // Food type selector
              const Text('Food Type',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Row(children: [
                _FoodChip(label: 'Veg', value: 'veg', selected: _foodType,
                    onTap: (v) => setState(() => _foodType = v)),
                const SizedBox(width: 8),
                _FoodChip(label: 'Non-Veg', value: 'nonveg', selected: _foodType,
                    onTap: (v) => setState(() => _foodType = v)),
                const SizedBox(width: 8),
                _FoodChip(label: 'Both', value: 'both', selected: _foodType,
                    onTap: (v) => setState(() => _foodType = v)),
              ]),

              const SizedBox(height: 28),
              Row(children: [
                _sectionHeader('Location'),
                const SizedBox(width: 10),
                if (_detecting)
                  const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _greenLight))
                else
                  GestureDetector(
                    onTap: _autoDetectLocation,
                    child: const Text('Re-detect',
                        style: TextStyle(fontSize: 12, color: _greenLight,
                            decoration: TextDecoration.underline)),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _field(
                    label: 'Pincode',
                    hint: '6-digit',
                    controller: _pincodeCtrl,
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: Validators.pincode,
                    suffix: _pincodeCtrl.text.isNotEmpty
                        ? const Icon(Icons.location_on,
                            color: _greenLight, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    label: 'State',
                    hint: 'e.g. Maharashtra',
                    controller: _stateCtrl,
                    validator: Validators.state,
                  ),
                ),
              ]),

              const SizedBox(height: 28),
              _sectionHeader('Legal (Optional for now)'),
              _field(
                label: 'GSTIN',
                hint: '15-character GST number (if available)',
                controller: _gstinCtr,
                validator: Validators.gstin,
              ),
              const SizedBox(height: 8),
              const Text(
                'You can add your GSTIN, FSSAI license, and other documents after approval.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFDC2626), fontSize: 12))),
                  ]),
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Application',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "By registering, you agree to BossBite's Partner Terms of Service.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: _green)),
  );

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int? maxLines = 1,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    Widget? suffix,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLines: obscure ? 1 : maxLines,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF94A3B8), size: 20),
                  onPressed: onToggleObscure,
                )
              : (suffix != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix) : null),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _green, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
        ),
      ),
    ]);
  }
}

class _FoodChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  const _FoodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF166534) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF166534)
                  : const Color(0xFFBBF7D0)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF374151),
            )),
      ),
    );
  }
}
