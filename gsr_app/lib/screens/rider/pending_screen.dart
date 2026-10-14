import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class RiderPendingScreen extends StatefulWidget {
  const RiderPendingScreen({super.key});
  @override
  State<RiderPendingScreen> createState() => _RiderPendingScreenState();
}

class _RiderPendingScreenState extends State<RiderPendingScreen> {
  static const _amber = Color(0xFFD97706);

  Timer? _timer;
  String _status = 'pending_admin';
  String _name = '';
  bool _loading = true;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _phone = prefs.getString('rider_phone');
    if (_phone == null || _phone!.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/rider/register');
      return;
    }
    await _checkStatus();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_phone == null) return;
    try {
      final data = await ApiService.riderCheckStatus(_phone!);
      final status = data['approval_status'] as String? ?? 'pending_admin';
      final name = data['name'] as String? ?? '';
      if (mounted) setState(() { _status = status; _name = name; _loading = false; });
      if (status == 'active') {
        _timer?.cancel();
        if (mounted) Navigator.pushReplacementNamed(context, '/rider/login');
      } else if (status == 'rejected') {
        _timer?.cancel();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _statusTitle => switch (_status) {
        'pending_admin' => 'Pending Admin Review',
        'pending_owner' => 'Pending Owner Confirmation',
        'rejected' => 'Registration Rejected',
        _ => 'Checking status…',
      };

  String get _statusDetail => switch (_status) {
        'pending_admin' =>
          'Our admin team is reviewing your registration. This usually takes a few hours.',
        'pending_owner' =>
          'The restaurant owner is confirming your details. Almost there!',
        'rejected' =>
          'Unfortunately your registration was not approved. Please contact support.',
        _ => '',
      };

  IconData get _statusIcon => switch (_status) {
        'rejected' => Icons.cancel_outlined,
        'pending_owner' => Icons.store_outlined,
        _ => Icons.hourglass_empty_outlined,
      };

  Color get _statusColor => switch (_status) {
        'rejected' => Colors.red,
        'pending_owner' => Colors.blue,
        _ => _amber,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_statusIcon, size: 80, color: _statusColor),
                    const SizedBox(height: 24),
                    Text(
                      _name.isNotEmpty ? 'Hi, $_name!' : 'Registration Submitted',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusTitle,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _statusColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusDetail,
                      style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_status != 'rejected') ...[
                      const Text(
                        'This page checks automatically every 10 seconds.',
                        style: TextStyle(fontSize: 12, color: Colors.black38),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _checkStatus,
                        child: const Text('Check Now', style: TextStyle(color: _amber)),
                      ),
                    ],
                    if (_status == 'rejected') ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _amber),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('rider_phone');
                            if (mounted) Navigator.pushReplacementNamed(context, '/rider/register');
                          },
                          child: const Text('Register Again', style: TextStyle(color: _amber)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
