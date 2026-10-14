import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/cart_service.dart';
import 'services/route_observer.dart';
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
import 'screens/customer/order_history_screen.dart';
import 'screens/rider/register_screen.dart';
import 'screens/rider/pending_screen.dart';
import 'screens/rider/login_screen.dart';
import 'screens/rider/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CartService.load();
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
      navigatorObservers: [appRouteObserver],
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
        '/customer/orders': (ctx) => const CustomerOrderHistoryScreen(),
        '/rider/root': (ctx) => const _RiderRootScreen(),
        '/rider/register': (ctx) => const RiderRegisterScreen(),
        '/rider/pending': (ctx) => const RiderPendingScreen(),
        '/rider/login': (ctx) => const RiderLoginScreen(),
        '/rider/home': (ctx) => const RiderHomeScreen(),
      },
    );
  }
}

// Routes rider to the right screen based on their stored state.
class _RiderRootScreen extends StatefulWidget {
  const _RiderRootScreen();
  @override
  State<_RiderRootScreen> createState() => _RiderRootScreenState();
}

class _RiderRootScreenState extends State<_RiderRootScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('rider_token') ?? '';
    if (token.isNotEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/rider/home');
      return;
    }
    final phone = prefs.getString('rider_phone') ?? '';
    if (phone.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/rider/register');
      return;
    }
    try {
      final data = await ApiService.riderCheckStatus(phone);
      final status = data['approval_status'] as String? ?? 'pending_admin';
      if (!mounted) return;
      if (status == 'active') {
        Navigator.pushReplacementNamed(context, '/rider/login');
      } else {
        Navigator.pushReplacementNamed(context, '/rider/pending');
      }
    } catch (_) {
      if (mounted) Navigator.pushReplacementNamed(context, '/rider/register');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFFFFF7ED),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
      );
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

    // Not onboarded yet → straight to onboarding
    if (name.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/customer/onboarding');
      return;
    }

    // Onboarded → silent device integrity check
    final phone = prefs.getString('customer_phone') ?? '';
    final deviceId = prefs.getString('device_uuid') ?? '';

    if (phone.isNotEmpty && deviceId.isNotEmpty) {
      // device_uuid exists → this user went through the new OTP+device flow
      final ok = await ApiService.customerCheckDevice(phone, deviceId);
      if (!ok) {
        // Device mismatch or not registered → clear profile and re-onboard
        await prefs.clear();
        if (mounted) Navigator.pushReplacementNamed(context, '/customer/onboarding');
        return;
      }
    }
    // device_uuid absent → old install pre-device-binding; let through gracefully.
    // They will be bound on next OTP verification.

    if (mounted) Navigator.pushReplacementNamed(context, '/customer/home');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFFFFF7ED),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706)),
        ),
      );
}
