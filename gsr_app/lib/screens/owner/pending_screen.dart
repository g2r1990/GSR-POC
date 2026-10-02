import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OwnerPendingScreen extends StatefulWidget {
  final String mobile;
  const OwnerPendingScreen({super.key, required this.mobile});

  @override
  State<OwnerPendingScreen> createState() => _OwnerPendingScreenState();
}

class _OwnerPendingScreenState extends State<OwnerPendingScreen> {
  static const _green = Color(0xFF166534);

  Map<String, dynamic>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final s = await ApiService.ownerStatus(widget.mobile);
      if (mounted) setState(() { _status = s; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = _status?['status'] == 'rejected';
    final reason = _status?['rejection_reason'] as String?;
    final code = _status?['restaurant_code'] as String?;
    final restaurantName = _status?['restaurant_name'] as String?;

    return Scaffold(
      backgroundColor: isRejected ? const Color(0xFFFFF7F7) : const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: isRejected ? const Color(0xFFDC2626) : _green,
        foregroundColor: Colors.white,
        title: Text(isRejected ? 'Application Status' : 'Application Submitted'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Status icon
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: isRejected
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(44),
                        ),
                        child: Icon(
                          isRejected
                              ? Icons.cancel_outlined
                              : Icons.hourglass_top_rounded,
                          size: 48,
                          color: isRejected
                              ? const Color(0xFFDC2626)
                              : _green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      isRejected
                          ? 'Application Not Approved'
                          : 'Application Under Review',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isRejected
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isRejected
                          ? 'Our team has reviewed your application and could not approve it at this time.'
                          : 'Our team is reviewing your restaurant details. You'll be notified once approved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
                    ),

                    const SizedBox(height: 32),

                    // Details card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isRejected
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (restaurantName != null) ...[
                            _DetailRow(
                                icon: Icons.store,
                                label: 'Restaurant',
                                value: restaurantName),
                            const Divider(height: 20),
                          ],
                          if (code != null) ...[
                            _DetailRow(
                                icon: Icons.tag,
                                label: 'Reference ID',
                                value: code),
                            const SizedBox(height: 4),
                            const Text(
                              'Use this ID when contacting the BossBite team',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                            const Divider(height: 20),
                          ],
                          _DetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Registered Mobile',
                              value: widget.mobile),
                          if (!isRejected) ...[
                            const Divider(height: 20),
                            _DetailRow(
                                icon: Icons.schedule,
                                label: 'Expected Timeline',
                                value: '24–48 business hours'),
                          ],
                          if (isRejected && reason != null) ...[
                            const Divider(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 18, color: Color(0xFFDC2626)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Reason',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFDC2626))),
                                      const SizedBox(height: 2),
                                      Text(reason,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF374151),
                                              height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Contact BB team
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.support_agent,
                            color: _green, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Need help?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _green)),
                              Text('Contact BossBite Team',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    // Retry login (check again)
                    TextButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        _fetchStatus();
                      },
                      child: const Text('Refresh Status',
                          style: TextStyle(color: _green)),
                    ),

                    if (isRejected)
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, '/owner/register'),
                        child: const Text('Submit a New Application',
                            style: TextStyle(color: Color(0xFF6B7280))),
                      ),

                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                          context, '/owner/login'),
                      child: const Text('Back to Login',
                          style: TextStyle(color: Color(0xFF9CA3AF))),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF6B7280)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF))),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1C1917))),
        ]),
      ),
    ]);
  }
}
