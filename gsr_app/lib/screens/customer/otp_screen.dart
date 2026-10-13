import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../services/api_service.dart';

class CustomerOtpScreen extends StatefulWidget {
  final String mobile;
  final String name;
  final String email;
  final String pincode;
  final String? district;
  final String? state;
  final String? country;
  final String? area;
  final String? devOtp;
  final bool isLogin;

  const CustomerOtpScreen({
    super.key,
    required this.mobile,
    required this.name,
    required this.email,
    required this.pincode,
    this.district,
    this.state,
    this.country,
    this.area,
    this.devOtp,
    this.isLogin = false,
  });

  @override
  State<CustomerOtpScreen> createState() => _CustomerOtpScreenState();
}

class _CustomerOtpScreenState extends State<CustomerOtpScreen> {
  static const _amber = Color(0xFFD97706);

  final List<TextEditingController> _ctrs =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  String? _error;
  int _cooldown = 60;
  Timer? _timer;
  StreamSubscription<String?>? _smsSub;
  String? _devOtp;

  @override
  void initState() {
    super.initState();
    _devOtp = widget.devOtp;
    _startTimer();
    _startSmsListener();
  }

  void _startSmsListener() {
    SmsAutoFill().listenForCode();
    _smsSub = SmsAutoFill().code.listen((code) {
      if (!mounted || code == null || code.length != 6) return;
      for (int i = 0; i < 6; i++) {
        _ctrs[i].text = code[i];
      }
      _verify();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smsSub?.cancel();
    SmsAutoFill().unregisterListener();
    for (final c in _ctrs) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _cooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _resend() async {
    setState(() { _error = null; _devOtp = null; });
    for (final c in _ctrs) c.clear();
    _foci[0].requestFocus();
    try {
      final result = await ApiService.customerSendOtp(widget.mobile);
      if (mounted) {
        setState(() => _devOtp = result['dev_otp'] as String?);
      }
      _startTimer();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not resend. Check your connection.');
    }
  }

  Future<void> _verify() async {
    final otp = _ctrs.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final deviceId = await ApiService.getOrCreateDeviceId();
      final result = await ApiService.customerVerifyOtp(
        widget.mobile, otp, deviceId,
        email: widget.email,
        name: widget.name,
      );
      // Server returns name/email — prefer server values (existing user may have stored data)
      final serverName = (result['name'] as String? ?? '').trim();
      final serverEmail = (result['email'] as String? ?? '').trim();
      final savedName = serverName.isNotEmpty ? serverName : widget.name;
      final savedEmail = serverEmail.isNotEmpty ? serverEmail : widget.email;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_name', savedName);
      await prefs.setString('customer_phone', widget.mobile);
      if (savedEmail.isNotEmpty) {
        await prefs.setString('customer_email', savedEmail);
      }
      // Always save location prefs when auto-detected data is available
      {
        if (widget.pincode.isNotEmpty) {
          await prefs.setString('customer_pincode', widget.pincode);
        }
        if (widget.district != null) {
          await prefs.setString('customer_district', widget.district!);
        }
        if (widget.state != null) {
          await prefs.setString('customer_state', widget.state!);
        }
        if (widget.country != null) {
          await prefs.setString('customer_country', widget.country!);
        }
        if (widget.area != null) {
          await prefs.setString('customer_area', widget.area!);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/customer/home', (_) => false);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _onDigit(int idx, String val) {
    if (val.isNotEmpty && idx < 5) {
      _foci[idx + 1].requestFocus();
    } else if (val.isEmpty && idx > 0) {
      _foci[idx - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Verify Mobile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sms_outlined, size: 64, color: _amber),
              const SizedBox(height: 20),
              const Text(
                'Enter the OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917)),
              ),
              const SizedBox(height: 8),
              Text(
                'A 6-digit code was sent to +91 ${widget.mobile}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF78716C)),
              ),

              // Dev-mode OTP banner (shown when SMS is not configured)
              if (_devOtp != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'DEV MODE — Your OTP: $_devOtp',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E)),
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // 6-box OTP grid
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => _OtpBox(
                    controller: _ctrs[i],
                    focusNode: _foci[i],
                    onChanged: (v) => _onDigit(i, v),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: 13)),
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: _cooldown > 0
                    ? Text(
                        'Resend OTP in ${_cooldown}s',
                        style: const TextStyle(
                            color: Color(0xFF78716C), fontSize: 13),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend OTP',
                            style:
                                TextStyle(color: _amber, fontSize: 13)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1917)),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFFDE68A), width: 2)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFFDE68A), width: 2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFD97706), width: 2)),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
