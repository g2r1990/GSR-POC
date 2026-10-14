import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});
  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  static const _amber = Color(0xFFD97706);

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _devOtp;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  Future<void> _prefillPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('rider_phone') ?? '';
    if (phone.isNotEmpty && mounted) {
      _phoneCtrl.text = phone;
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.riderSendOtp(phone);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _devOtp = data['dev_otp'] as String?;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.riderVerifyOtp(phone, otp);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_token', data['token'] as String);
      await prefs.setString('rider_id', data['rider_id'] as String);
      await prefs.setString('rider_name', data['name'] as String);
      await prefs.setString('rider_restaurant_id', data['restaurant_id'] as String);
      await prefs.setString('rider_restaurant_name', data['restaurant_name'] as String);
      await prefs.setString('rider_phone', phone);
      if (mounted) Navigator.pushReplacementNamed(context, '/rider/home');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delivery_dining, size: 72, color: _amber),
                const SizedBox(height: 20),
                const Text(
                  'Rider Login',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'BossBite Delivery Partner',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  readOnly: _otpSent,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      hintText: '------',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                    ),
                  ),
                  if (_devOtp != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.developer_mode, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'Dev OTP: $_devOtp',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _amber,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _otpSent ? 'Verify OTP & Login' : 'Send OTP',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _otpSent = false;
                      _otpCtrl.clear();
                      _devOtp = null;
                      _error = null;
                    }),
                    child: const Text('Change Number', style: TextStyle(color: _amber)),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/rider/register'),
                  child: const Text('New rider? Register here', style: TextStyle(color: _amber)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
