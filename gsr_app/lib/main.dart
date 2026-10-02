import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/role_selector.dart';
import 'screens/admin/login_screen.dart';
import 'screens/admin/kyc_dashboard.dart';
import 'screens/owner/landing_screen.dart';
import 'screens/owner/register_screen.dart';
import 'screens/owner/login_screen.dart';
import 'screens/customer/home_screen.dart';
import 'screens/customer/onboarding_screen.dart';
import 'screens/customer/profile_screen.dart';

void main() {
  runApp(const BossBiteApp());
}

class BossBiteApp extends StatelessWidget {
  const BossBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BossBite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD97706)),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/roles': (ctx) => const RoleSelectorScreen(),
        '/admin/login': (ctx) => const AdminLoginScreen(),
        '/admin/dashboard': (ctx) => const AdminDashboardScreen(),
        '/owner/landing': (ctx) => const OwnerLandingScreen(),
        '/owner/register': (ctx) => const OwnerRegisterScreen(),
        '/owner/login': (ctx) => const OwnerLoginScreen(),
        '/customer/root': (ctx) => const _CustomerRootScreen(),
        '/customer/onboarding': (ctx) => const CustomerOnboardingScreen(),
        '/customer/home': (ctx) => const CustomerHomeScreen(),
        '/customer/profile': (ctx) => const CustomerProfileScreen(),
      },
    );
  }
}

// Checks if customer has completed onboarding; routes accordingly.
class _CustomerRootScreen extends StatefulWidget {
  const _CustomerRootScreen();
  @override
  State<_CustomerRootScreen> createState() => _CustomerRootScreenState();
}

class _CustomerRootScreenState extends State<_CustomerRootScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('customer_name') ?? '';
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      name.isEmpty ? '/customer/onboarding' : '/customer/home',
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFFFFF7ED),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706)),
        ),
      );
}
