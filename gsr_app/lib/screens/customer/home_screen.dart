import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'restaurant_list_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _amber = Color(0xFFD97706);
  static const _amberDark = Color(0xFFB45309);

  final _pincodeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final pincode = _pincodeCtrl.text.trim();
    if (pincode.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit pincode.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final restaurants = await ApiService.searchRestaurants(pincode);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantListScreen(
            pincode: pincode,
            restaurants: restaurants,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not connect. Check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('GSR Food'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.restaurant_menu, size: 72, color: _amber),
              const SizedBox(height: 16),
              const Text(
                'Find Restaurants Near You',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your pincode to discover local restaurants',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _pincodeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Color(0xFF1C1917),
                ),
                decoration: InputDecoration(
                  hintText: '431003',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD6D3D1),
                    letterSpacing: 8,
                    fontWeight: FontWeight.normal,
                    fontSize: 28,
                  ),
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFDE68A), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _amber, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _amber.withAlpha(128),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Find Restaurants',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 48),
              const _TipCard(
                icon: Icons.search,
                text: 'Search by pincode to see all active restaurants in your area.',
              ),
              const SizedBox(height: 12),
              const _TipCard(
                icon: Icons.visibility,
                text: 'Browse the menu before ordering — no login required.',
              ),
              const SizedBox(height: 12),
              const _TipCard(
                icon: Icons.payments_outlined,
                text: 'Pay by cash or UPI (PhonePe / Google Pay) on delivery.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF44403C)),
            ),
          ),
        ],
      ),
    );
  }
}
