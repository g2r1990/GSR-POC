import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class RiderRegisterScreen extends StatefulWidget {
  const RiderRegisterScreen({super.key});
  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  static const _amber = Color(0xFFD97706);

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();

  List<Map<String, dynamic>> _restaurants = [];
  String? _selectedRestaurantId;
  bool _loading = false;
  bool _loadingRestaurants = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final list = await ApiService.riderGetRestaurants();
      if (mounted) setState(() { _restaurants = list; _loadingRestaurants = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingRestaurants = false; _error = e.toString(); });
    }
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final vehicle = _vehicleCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || vehicle.isEmpty || _selectedRestaurantId == null) {
      setState(() => _error = 'Please fill in all fields and select a restaurant.');
      return;
    }
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.riderRegister(
        name: name,
        phone: phone,
        restaurantId: _selectedRestaurantId!,
        vehicleNumber: vehicle,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_phone', phone);
      if (mounted) Navigator.pushReplacementNamed(context, '/rider/pending');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('Rider Registration', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _loadingRestaurants
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(Icons.delivery_dining, size: 64, color: _amber),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Join as a Delivery Rider',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill in your details. Admin will review and approve your registration.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  _buildField('Full Name', _nameCtrl, 'Enter your full name'),
                  const SizedBox(height: 16),
                  _buildField(
                    'Phone Number',
                    _phoneCtrl,
                    '10-digit mobile number',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  const SizedBox(height: 16),
                  _buildField('Vehicle Number', _vehicleCtrl, 'e.g. MH12AB1234'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Restaurant',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    hint: const Text('Select your restaurant'),
                    value: _selectedRestaurantId,
                    items: _restaurants.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id'] as String,
                        child: Text(r['name'] as String),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedRestaurantId = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Submit Registration',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/rider/login'),
                      child: const Text('Already registered? Login', style: TextStyle(color: _amber)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
      ),
    );
  }
}
