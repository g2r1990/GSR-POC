import 'package:flutter/material.dart';
import '../app_flavor.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _full = 'BossBite';
  static const _amber = Color(0xFFD97706);

  String _typed = '';
  bool _showCursor = true;
  int _charIdx = 0;

  late AnimationController _cursorCtrl;

  @override
  void initState() {
    super.initState();
    // Blinking cursor animation
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (mounted) setState(() => _showCursor = _cursorCtrl.value < 0.5);
      });
    _cursorCtrl.repeat();

    // Start typing after initial pause
    Future.delayed(const Duration(milliseconds: 600), _typeNext);
  }

  void _typeNext() {
    if (!mounted) return;
    if (_charIdx < _full.length) {
      setState(() {
        _typed = _full.substring(0, _charIdx + 1);
        _charIdx++;
      });
      Future.delayed(const Duration(milliseconds: 130), _typeNext);
    } else {
      // Fully typed — navigate after short pause
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _navigate();
      });
    }
  }

  void _navigate() {
    String route;
    if (isAdminApp) {
      route = '/admin/login';
    } else if (isOwnerApp) {
      route = '/owner/landing';
    } else {
      route = '/customer/root';
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _amber,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _typed,
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: _showCursor ? '|' : ' ',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w100,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AnimatedOpacity(
              opacity: _charIdx == _full.length ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: const Text(
                'Your Restaurant, Your Rule',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
