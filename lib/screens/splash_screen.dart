import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_screen.dart';
import 'main_navigation.dart';
import '../services/api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool? _healthOk;
  bool _minTimeElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Subtle animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Fade in animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Subtle scale animation for refined entrance
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Start animation
    _controller.forward();

    // Fire-and-forget server health check
    _checkHealth();

    // Minimum display duration before we allow navigation
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _minTimeElapsed = true;
      });
      _tryNavigate();
    });
  }

  Future<void> _checkHealth() async {
    try {
      final res = await ApiClient().get('/health');
      final status = (res['status']?.toString().toLowerCase()) ?? '';
      final ok =
          res['success'] == true || status == 'ok' || status == 'healthy';
      if (!mounted) return;
      setState(() {
        _healthOk = ok;
      });
      _tryNavigate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _healthOk = false;
      });
    }
  }

  void _tryNavigate() {
    if (!mounted || _navigated) return;
    if (_minTimeElapsed && _healthOk == true) {
      _navigated = true;
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              isAuthenticated ? const MainNavigation() : const WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _retryHealthCheck() {
    setState(() {
      _healthOk = null; // clear state to hide error
    });
    _checkHealth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand name with design system specs
                const Text(
                  'MEGG',
                  style: TextStyle(
                    fontFamily: 'FuturaCyrillicBook',
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 12,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                // Minimal divider line (Zara style)
                Container(
                  width: 60,
                  height: 1,
                  color: Colors.black.withOpacity(0.3),
                ),
                const SizedBox(height: 24),

                // Tagline with refined typography
                Text(
                  'FASHION SALE ALERTS',
                  style: TextStyle(
                    fontFamily: 'FuturaCyrillicBook',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.5,
                    color: Colors.black.withOpacity(0.6),
                    height: 1.0,
                  ),
                ),
                if (_healthOk == false) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'UNABLE TO CONNECT',
                    style: TextStyle(
                      fontFamily: 'FuturaCyrillicBook',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                      color: Colors.black,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _retryHealthCheck,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      side: BorderSide(
                        color: Colors.black.withOpacity(0.6),
                        width: 1,
                      ),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text(
                      'RETRY',
                      style: TextStyle(
                        fontFamily: 'FuturaCyrillicBook',
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
