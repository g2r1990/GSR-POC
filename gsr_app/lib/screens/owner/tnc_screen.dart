import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class TncScreen extends StatefulWidget {
  final String ownerName;
  final String ownerId;

  const TncScreen({
    super.key,
    required this.ownerName,
    required this.ownerId,
  });

  @override
  State<TncScreen> createState() => _TncScreenState();
}

class _TncScreenState extends State<TncScreen> {
  bool _agreed = false;
  bool _saving = false;
  bool _scrolledToBottom = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrolledToBottom) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 48) {
      setState(() => _scrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_agreed) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tnc_accepted_${widget.ownerId}', true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OwnerDashboardScreen(ownerName: widget.ownerName),
        ),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BossBite Restaurant Partner Agreement',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A))),
                        SizedBox(height: 4),
                        Text('Effective from date of registration',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                        Divider(height: 24),
                        _TncSection(
                          title: '1. Restaurant Information',
                          body:
                              'You agree that all restaurant details provided during registration are accurate, current, and complete. Any changes must be updated promptly.',
                        ),
                        _TncSection(
                          title: '2. Menu & Pricing',
                          body:
                              'You are responsible for maintaining accurate menu items and prices. BossBite is not liable for orders placed based on incorrect information.',
                        ),
                        _TncSection(
                          title: '3. Order Fulfilment',
                          body:
                              'You agree to accept or decline orders within 15 minutes. Accepted orders must be fulfilled as described. Repeated cancellations may result in account suspension.',
                        ),
                        _TncSection(
                          title: '4. Food Safety',
                          body:
                              'You are solely responsible for the quality, hygiene, and safety of food prepared and delivered. All applicable FSSAI regulations must be followed.',
                        ),
                        _TncSection(
                          title: '5. Service Availability',
                          body:
                              'Keep your restaurant availability status accurate. Customers rely on the live toggle to know if you are open. Misleading statuses harm platform trust.',
                        ),
                        _TncSection(
                          title: '6. Platform Use',
                          body:
                              'This POC platform is provided as-is for the Chhatrapati Sambhajinagar pilot. BossBite reserves the right to suspend access for misuse or violation of these terms.',
                        ),
                        _TncSection(
                          title: '7. Data',
                          body:
                              'Customer order data is visible to you only for fulfilment purposes. You must not use it for marketing or share it with third parties.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          'By clicking "I Agree" you confirm that you have read, understood, and agree to all the above terms.',
                          style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                if (!_scrolledToBottom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.arrow_downward,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      const Text('Scroll to the end to enable',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                    ]),
                  ),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: _scrolledToBottom
                      ? (v) => setState(() => _agreed = v ?? false)
                      : null,
                  title: Text(
                    'I have read and agree to the Terms & Conditions',
                    style: TextStyle(
                        fontSize: 14,
                        color: _scrolledToBottom
                            ? const Color(0xFF374151)
                            : const Color(0xFF94A3B8)),
                  ),
                  activeColor: const Color(0xFF166534),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_agreed && !_saving) ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFBBF7D0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('I Agree — Continue',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TncSection extends StatelessWidget {
  final String title;
  final String body;
  const _TncSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF166534))),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151), height: 1.5)),
        ],
      ),
    );
  }
}
