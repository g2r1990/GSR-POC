import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class RiderRegisterScreen extends StatefulWidget {
  const RiderRegisterScreen({super.key});
  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  static const _amber = Color(0xFFD97706);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Vehicle number — 4 parts
  final _vStateCtrl  = TextEditingController(); // MH   (2 letters)
  final _vRtoCtrl    = TextEditingController(); // 12   (2 digits)
  final _vSeriesCtrl = TextEditingController(); // AB   (1–3 letters)
  final _vNumCtrl    = TextEditingController(); // 1234 (4 digits)
  final _vRtoFocus    = FocusNode();
  final _vSeriesFocus = FocusNode();
  final _vNumFocus    = FocusNode();

  // Rider type
  String _riderType = 'restaurant_owned'; // 'restaurant_owned' | 'individual'

  // Restaurants
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _allRestaurants = [];
  String? _selectedRestaurantId;
  bool _loadingRestaurants = true;
  bool _showingFiltered = false;

  // Location
  bool _detectingLocation = true;
  String? _locationLabel; // e.g. "Pune District, Maharashtra"
  String? _detectedDistrict;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detectAndLoad();
  }

  Future<void> _detectAndLoad() async {
    setState(() { _detectingLocation = true; _loadingRestaurants = true; });
    String? district;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
        );
        final loc = await ApiService.getLocationFromCoords(pos.latitude, pos.longitude);
        district = loc['district'];
        final state = loc['state'];
        if (mounted) {
          setState(() {
            _detectedDistrict = district;
            if (district != null) {
              _locationLabel = state != null ? '$district, $state' : district;
            }
          });
        }
      }
    } catch (_) {}

    // Load and filter restaurants
    try {
      final all = await ApiService.riderGetRestaurants();
      List<Map<String, dynamic>> filtered = all;
      bool isFiltered = false;
      if (district != null && district.isNotEmpty) {
        final d = district.toLowerCase();
        filtered = all.where((r) {
          final rArea = (r['area'] as String? ?? '').toLowerCase();
          return rArea.contains(d) || d.contains(rArea);
        }).toList();
        if (filtered.isNotEmpty) {
          isFiltered = true;
        } else {
          filtered = all;
        }
      }
      if (mounted) {
        setState(() {
          _allRestaurants = all;
          _restaurants = filtered;
          _showingFiltered = isFiltered;
          _loadingRestaurants = false;
          _detectingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRestaurants = false;
          _detectingLocation = false;
          _error = 'Could not load restaurants. Check your connection.';
        });
      }
    }
  }

  void _showAll() {
    setState(() {
      _restaurants = _allRestaurants;
      _showingFiltered = false;
      _selectedRestaurantId = null;
    });
  }

  String get _vehicleNumber {
    final s  = _vStateCtrl.text.trim().toUpperCase();
    final r  = _vRtoCtrl.text.trim();
    final se = _vSeriesCtrl.text.trim().toUpperCase();
    final n  = _vNumCtrl.text.trim();
    return '$s$r$se$n';
  }

  Future<void> _register() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_riderType == 'restaurant_owned' && _selectedRestaurantId == null) {
      setState(() => _error = 'Please select your restaurant.');
      return;
    }

    setState(() => _loading = true);
    try {
      final phone = _phoneCtrl.text.trim();
      await ApiService.riderRegister(
        name: _nameCtrl.text.trim(),
        phone: phone,
        riderType: _riderType,
        restaurantId: _riderType == 'restaurant_owned' ? _selectedRestaurantId : null,
        vehicleNumber: _vehicleNumber,
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
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _vStateCtrl.dispose(); _vRtoCtrl.dispose();
    _vSeriesCtrl.dispose(); _vNumCtrl.dispose();
    _vRtoFocus.dispose(); _vSeriesFocus.dispose(); _vNumFocus.dispose();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Icon(Icons.delivery_dining, size: 64, color: _amber)),
              const SizedBox(height: 16),
              const Text('Join as a Delivery Rider',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
              const SizedBox(height: 6),
              const Text('Fill in your details. Admin will review and approve your registration.',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),

              // Location chip
              _buildLocationChip(),
              const SizedBox(height: 20),

              // Rider type
              const Text('Rider Type',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(children: [
                _typeChip('restaurant_owned', Icons.store, 'Restaurant-Owned'),
                const SizedBox(width: 10),
                _typeChip('individual', Icons.person, 'Independent'),
              ]),
              const SizedBox(height: 6),
              Text(
                _riderType == 'restaurant_owned'
                    ? 'Linked to one restaurant. Owner approves first, then admin.'
                    : 'Works independently. Admin approves directly.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),

              // Full name
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecor('Full Name', 'Enter your full name'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().length < 2) return 'Enter a valid name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone with +91
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecor('Phone Number', '10-digit number').copyWith(
                  prefixText: '+91  ',
                  prefixStyle: const TextStyle(
                      color: Color(0xFF1C1C1E), fontWeight: FontWeight.w600, fontSize: 15),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone number is required';
                  if (v.trim().length != 10) return 'Enter a valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Vehicle number — 4 blocks
              const Text('Vehicle Number',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _buildVehicleRow(),
              const SizedBox(height: 4),
              const Text('Format: State · RTO · Series · Number  (e.g. MH · 12 · AB · 1234)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),

              // Restaurant dropdown (restaurant_owned only)
              if (_riderType == 'restaurant_owned') _buildRestaurantSection(),

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
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Registration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final active = _riderType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _riderType = value;
        if (value == 'individual') _selectedRestaurantId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _amber : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _amber : const Color(0xFFD1D5DB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? Colors.white : const Color(0xFF78716C)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF374151))),
        ]),
      ),
    );
  }

  Widget _buildLocationChip() {
    if (_detectingLocation) {
      return Row(children: const [
        SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _amber)),
        SizedBox(width: 8),
        Text('Detecting your location…', style: TextStyle(fontSize: 13, color: Color(0xFF78716C))),
      ]);
    }
    if (_locationLabel != null) {
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on, size: 14, color: Color(0xFF166534)),
            const SizedBox(width: 4),
            Text(_locationLabel!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _detectAndLoad,
          child: const Text('Re-detect', style: TextStyle(fontSize: 12, color: _amber, decoration: TextDecoration.underline)),
        ),
      ]);
    }
    return Row(children: [
      const Icon(Icons.location_off, size: 14, color: Color(0xFF94A3B8)),
      const SizedBox(width: 6),
      const Text('Location not detected', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _detectAndLoad,
        child: const Text('Try again', style: TextStyle(fontSize: 12, color: _amber, decoration: TextDecoration.underline)),
      ),
    ]);
  }

  Widget _buildVehicleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // State — 2 letters
        Expanded(flex: 2, child: _vehicleField(
          ctrl: _vStateCtrl, hint: 'MH', label: 'State',
          maxLen: 2, alpha: true,
          onFilled: () => FocusScope.of(context).requestFocus(_vRtoFocus),
          validator: (v) => (v == null || v.length != 2) ? '2 letters' : null,
        )),
        const Padding(padding: EdgeInsets.only(top: 18, left: 4, right: 4),
            child: Text('·', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        // RTO — 2 digits
        Expanded(flex: 2, child: _vehicleField(
          ctrl: _vRtoCtrl, hint: '12', label: 'RTO',
          maxLen: 2, alpha: false, focusNode: _vRtoFocus,
          onFilled: () => FocusScope.of(context).requestFocus(_vSeriesFocus),
          validator: (v) => (v == null || v.length != 2) ? '2 digits' : null,
        )),
        const Padding(padding: EdgeInsets.only(top: 18, left: 4, right: 4),
            child: Text('·', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        // Series — 1–3 letters
        Expanded(flex: 3, child: _vehicleField(
          ctrl: _vSeriesCtrl, hint: 'AB', label: 'Series',
          maxLen: 3, alpha: true, focusNode: _vSeriesFocus,
          onFilled: () => FocusScope.of(context).requestFocus(_vNumFocus),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        )),
        const Padding(padding: EdgeInsets.only(top: 18, left: 4, right: 4),
            child: Text('·', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        // Number — 4 digits
        Expanded(flex: 3, child: _vehicleField(
          ctrl: _vNumCtrl, hint: '1234', label: 'Number',
          maxLen: 4, alpha: false, focusNode: _vNumFocus,
          validator: (v) => (v == null || v.length != 4) ? '4 digits' : null,
        )),
      ],
    );
  }

  Widget _vehicleField({
    required TextEditingController ctrl,
    required String hint,
    required String label,
    required int maxLen,
    required bool alpha,
    FocusNode? focusNode,
    VoidCallback? onFilled,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focusNode,
      maxLength: maxLen,
      textCapitalization: alpha ? TextCapitalization.characters : TextCapitalization.none,
      keyboardType: alpha ? TextInputType.text : TextInputType.number,
      inputFormatters: [
        if (alpha) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]'))
        else FilteringTextInputFormatter.digitsOnly,
        if (alpha) _UpperCaseFormatter(),
      ],
      textAlign: TextAlign.center,
      onChanged: (v) { if (v.length == maxLen && onFilled != null) onFilled(); },
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        labelStyle: const TextStyle(fontSize: 11),
      ),
      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
    );
  }

  Widget _buildRestaurantSection() {
    if (_loadingRestaurants) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _amber)),
            SizedBox(width: 10),
            Text('Loading restaurants…', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showingFiltered && _locationLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text('Showing ${_restaurants.length} restaurant(s) near $_locationLabel',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showAll,
                child: const Text('Show all', style: TextStyle(fontSize: 12, color: _amber, decoration: TextDecoration.underline)),
              ),
            ]),
          ),
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
            final area = r['area'] as String? ?? '';
            return DropdownMenuItem<String>(
              value: r['id'] as String,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r['name'] as String, style: const TextStyle(fontSize: 14)),
                  if (area.isNotEmpty)
                    Text(area, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() { _selectedRestaurantId = v; _error = null; }),
          validator: (v) => v == null ? 'Please select a restaurant' : null,
          isExpanded: true,
        ),
      ],
    );
  }

  InputDecoration _inputDecor(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    return next.copyWith(text: next.text.toUpperCase(),
        selection: next.selection);
  }
}
