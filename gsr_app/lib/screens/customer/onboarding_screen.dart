import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'otp_screen.dart';

class CustomerOnboardingScreen extends StatefulWidget {
  const CustomerOnboardingScreen({super.key});

  @override
  State<CustomerOnboardingScreen> createState() =>
      _CustomerOnboardingScreenState();
}

class _CustomerOnboardingScreenState extends State<CustomerOnboardingScreen> {
  static const _amber = Color(0xFFD97706);

  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _pincodeCtr = TextEditingController();

  String? _district, _state, _country;
  bool _detecting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoDetect();
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _phoneCtr.dispose();
    _pincodeCtr.dispose();
    super.dispose();
  }

  Future<void> _autoDetect() async {
    setState(() { _detecting = true; _district = null; _state = null; _country = null; });
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
      final loc =
          await ApiService.getLocationFromCoords(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _pincodeCtr.text = loc['pincode'] ?? '';
          _district = loc['district'];
          _state = loc['state'];
          _country = loc['country'];
          _detecting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = await ApiService.customerSendOtp(_phoneCtr.text.trim());
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CustomerOtpScreen(
          mobile: _phoneCtr.text.trim(),
          name: _nameCtr.text.trim(),
          pincode: _pincodeCtr.text.trim(),
          district: _district,
          state: _state,
          country: _country,
          devOtp: result['dev_otp'] as String?,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send OTP. Check your connection.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.restaurant_menu, size: 64, color: _amber),
                const SizedBox(height: 14),
                const Text(
                  'Welcome to BossBite',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quick setup — takes 30 seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
                ),

                const SizedBox(height: 36),
                _sectionHeader('About You'),
                const SizedBox(height: 12),

                _label('Full Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtr,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDec('e.g. Rahul Sharma'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 14),

                _label('Mobile Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtr,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  decoration: _inputDec('10-digit number').copyWith(counterText: ''),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length < 10) return 'Enter 10 digits';
                    return null;
                  },
                ),

                const SizedBox(height: 28),
                Row(
                  children: [
                    _sectionHeader('Your Location'),
                    const SizedBox(width: 10),
                    if (_detecting)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _amber),
                      )
                    else
                      GestureDetector(
                        onTap: _autoDetect,
                        child: const Text(
                          'Re-detect',
                          style: TextStyle(
                            fontSize: 12,
                            color: _amber,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                _label('Pincode'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pincodeCtr,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: _inputDec('6-digit pincode').copyWith(
                    counterText: '',
                    suffixIcon: _detecting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _amber),
                            ),
                          )
                        : _pincodeCtr.text.isNotEmpty
                            ? const Icon(Icons.location_on,
                                color: Color(0xFF166534), size: 20)
                            : null,
                  ),
                ),

                if (_district != null || _state != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    if (_district != null)
                      Expanded(
                          child: _InfoBox(label: 'District', value: _district!)),
                    if (_district != null && _state != null)
                      const SizedBox(width: 8),
                    if (_state != null)
                      Expanded(child: _InfoBox(label: 'State', value: _state!)),
                  ]),
                  if (_country != null) ...[
                    const SizedBox(height: 8),
                    _InfoBox(label: 'Country', value: _country!),
                  ],
                ],

                if (!_detecting && _district == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Location not detected — you can enter pincode manually',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFFA8A29E)),
                    ),
                  ),

                const SizedBox(height: 36),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Get Started',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your details are saved on this device only and used for delivery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFFA8A29E)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF92400E),
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
            borderSide: const BorderSide(color: _amber, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
      );
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF166534))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1917))),
      ]),
    );
  }
}
