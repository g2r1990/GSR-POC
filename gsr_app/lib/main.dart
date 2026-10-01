import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/role_selector.dart';
import 'screens/admin/login_screen.dart';
import 'screens/admin/kyc_dashboard.dart';
import 'screens/owner/register_screen.dart';
import 'screens/customer/home_screen.dart';

void main() {
  runApp(const GsrApp());
}

class GsrApp extends StatelessWidget {
  const GsrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GSR Inspection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E40AF)),
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
        '/owner/register': (ctx) => const OwnerRegisterScreen(),
        '/customer/home': (ctx) => const CustomerHomeScreen(),
      },
    );
  }
}
