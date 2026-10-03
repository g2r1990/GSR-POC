import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  static const _amber = Color(0xFFD97706);

  String _name = '';
  String _phone = '';
  String _pincode = '';
  String _district = '';
  String _state = '';
  String _area = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _name = prefs.getString('customer_name') ?? '';
        _phone = prefs.getString('customer_phone') ?? '';
        _pincode = prefs.getString('customer_pincode') ?? '';
        _district = prefs.getString('customer_district') ?? '';
        _state = prefs.getString('customer_state') ?? '';
        _area = prefs.getString('customer_area') ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'B';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        title: const Text('My Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header — amber banner with avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              color: _amber,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _amber),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _name.isNotEmpty ? _name : 'BossBite User',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  if (_phone.isNotEmpty)
                    Text(
                      '+91 $_phone',
                      style: const TextStyle(
                          fontSize: 15, color: Colors.white70),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Account Details'),
                  const SizedBox(height: 10),
                  _Card(children: [
                    _Row(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: _name.isNotEmpty ? _name : '—'),
                    const _Divider(),
                    _Row(
                        icon: Icons.phone_outlined,
                        label: 'Mobile',
                        value:
                            _phone.isNotEmpty ? '+91 $_phone' : '—'),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Delivery Location'),
                  const SizedBox(height: 10),
                  _Card(children: [
                    _Row(
                        icon: Icons.pin_drop_outlined,
                        label: 'Pincode',
                        value: _pincode.isNotEmpty ? _pincode : '—'),
                    if (_district.isNotEmpty) ...[
                      const _Divider(),
                      _Row(
                          icon: Icons.location_city_outlined,
                          label: 'District',
                          value: _district),
                    ],
                    if (_state.isNotEmpty) ...[
                      const _Divider(),
                      _Row(
                          icon: Icons.map_outlined,
                          label: 'State',
                          value: _state),
                    ],
                    if (_area.isNotEmpty) ...[
                      const _Divider(),
                      _Row(
                          icon: Icons.place_outlined,
                          label: 'Area',
                          value: _area),
                    ],
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('App'),
                  const SizedBox(height: 10),
                  _Card(children: [
                    ListTile(
                      leading:
                          const Icon(Icons.info_outline, color: _amber, size: 22),
                      title: const Text('Version',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151))),
                      trailing: const Text('1.0 · Sprint 9',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF78716C))),
                      dense: true,
                    ),
                    const _Divider(),
                    ListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: Color(0xFFDC2626), size: 22),
                      title: const Text('Clear My Data',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFDC2626))),
                      dense: true,
                      onTap: () => _confirmClear(context),
                    ),
                  ]),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Data?'),
        content: const Text(
            'This will remove your profile from this device. You will be asked to set up again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/customer/root');
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
            letterSpacing: 0.8),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: const Color(0xFFD97706), size: 22),
        title: Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF78716C))),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1917))),
        dense: true,
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 56, color: Color(0xFFFDE68A));
}
