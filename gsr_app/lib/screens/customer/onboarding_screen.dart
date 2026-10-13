import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phone_number_hint/phone_number_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
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
  final _emailCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _pincodeCtr = TextEditingController();

  String? _district, _state, _country, _area;
  bool _detecting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoDetect();
    _requestPhoneHint();
  }

  Future<void> _requestPhoneHint() async {
    try {
      final hint = await PhoneNumberHint.requestHint();
      if (hint != null && _phoneCtr.text.isEmpty) {
        // Strip country code (+91) and keep last 10 digits
        final digits = hint.replaceAll(RegExp(r'\D'), '');
        _phoneCtr.text = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _emailCtr.dispose();
    _phoneCtr.dispose();
    _pincodeCtr.dispose();
    super.dispose();
  }

  Future<void> _autoDetect() async {
    setState(() { _detecting = true; _district = null; _state = null; _country = null; _area = null; });
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
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
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
          _area = loc['area'];
          _detecting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_area == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Area not detected. Tap Re-detect to enable location — it is required for registration.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ApiService.customerSendOtp(_phoneCtr.text.trim());
      if (!mounted) return;
      final isExisting = result['status'] == 'existing_user';
      if (isExisting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone already registered — enter the OTP to sign in.'),
            backgroundColor: Color(0xFF1D4ED8),
            duration: Duration(seconds: 4),
          ),
        );
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CustomerOtpScreen(
          mobile: _phoneCtr.text.trim(),
          name: _nameCtr.text.trim(),
          email: _emailCtr.text.trim(),
          pincode: _pincodeCtr.text.trim(),
          district: _district,
          state: _state,
          country: _country,
          area: _area,
          devOtp: result['dev_otp'] as String?,
          isLogin: isExisting,
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
                Image.asset('assets/icon/bossbite_logo.png',
                    width: 72, height: 72),
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
                  validator: Validators.personName,
                ),
                const SizedBox(height: 14),

                _label('Email Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtr,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _inputDec('you@example.com'),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Email is required';
                    return Validators.email(v);
                  },
                ),
                const SizedBox(height: 14),

                _label('Mobile Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtr,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  decoration: _inputDec('10-digit number').copyWith(
                    counterText: '',
                    prefixText: _country == 'India' ? '+91 ' : null,
                    prefixStyle: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  validator: Validators.mobile,
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
                  validator: Validators.pincode,
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
                  if (_area != null) ...[
                    const SizedBox(height: 8),
                    _InfoBox(label: 'Area', value: _area!),
                  ],
                  if (_country != null) ...[
                    const SizedBox(height: 8),
                    _InfoBox(label: 'Country', value: _country!),
                  ],
                ],

                if (!_detecting && _area == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Area not detected — tap Re-detect to enable location (required for registration)',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
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
