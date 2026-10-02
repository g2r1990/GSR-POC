import 'package:flutter/material.dart';

class OwnerLandingScreen extends StatelessWidget {
  const OwnerLandingScreen({super.key});

  static const _green = Color(0xFF166534);
  static const _greenLight = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.restaurant_menu,
                      size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'BossBite',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: _green,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Restaurant Partner Portal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF374151)),
              ),
              const Spacer(),

              // Info cards
              _InfoCard(
                icon: Icons.how_to_reg_outlined,
                title: 'New partner?',
                subtitle: 'Register your restaurant. Our team will verify your details and go live within 24–48 hrs.',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.verified_outlined,
                title: 'What we check',
                subtitle: 'GSTIN · Food safety license · Restaurant photos · Owner documents',
              ),
              const Spacer(),

              // Register button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/owner/register'),
                  icon: const Icon(Icons.store_mall_directory_outlined),
                  label: const Text('Register Your Restaurant',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Login button
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/owner/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Already registered? Sign In',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'BossBite Tech Team  ·  Official Partner App',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF166534), size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1917))),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}
