import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import 'welcome_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _lottieController;
  Timer? _safetyTimer;

  bool _animationCompleted = false;
  bool _slideStarted = false;
  bool _isAuthenticated = false;
  bool _showSplash = true;
  bool _appInitialized = false;

  static bool hasShown = false;

  @override
  void initState() {
    super.initState();
    _initializeUI();
    _initApp();
    if (!hasShown) {
      _initializeLottie();
    }
  }

  Future<void> _initApp() async {
    try {
      await CacheService().init();

      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('Failed to load .env: $e');
      }

      await Firebase.initializeApp();

      await Supabase.initialize(
        url: ApiConfig.supabaseUrl,
        anonKey: ApiConfig.supabaseAnonKey,
      );

      AuthService().setupAuthListener();
      await FCMService().initialize();
      await NotificationService().initialize();

      if (mounted) {
        _checkAuth();
        setState(() => _appInitialized = true);
        if (hasShown) {
          setState(() => _showSplash = false);
        } else {
          _tryNavigate();
        }
      }
    } catch (e) {
      debugPrint('App initialization failed: $e');
      if (mounted) {
        setState(() => _appInitialized = true);
        if (hasShown) {
          setState(() => _showSplash = false);
        } else {
          _tryNavigate();
        }
      }
    }
  }

  void _checkAuth() {
    final session = Supabase.instance.client.auth.currentSession;
    if (mounted) {
      setState(() {
        _isAuthenticated = session != null;
      });
    }
  }

  void _initializeUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showSplash = false;
          });
        }
        // Reset system UI style for the next screen
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        );
      }
    });
  }

  void _initializeLottie() {
    _lottieController = AnimationController(vsync: this);

    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });
  }

  void _onAnimationComplete() {
    if (!mounted || _animationCompleted) return;

    hasShown = true;
    setState(() => _animationCompleted = true);
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_animationCompleted && _appInitialized && !_slideStarted) {
      _slideStarted = true;
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _slideController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If splash is done, just show the app content directly
    if (!_showSplash) {
      return _isAuthenticated ? const MainNavigation() : const WelcomeScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The App Content (Rendered behind the splash)
          if (_appInitialized)
            Positioned.fill(
              child: _isAuthenticated
                  ? const MainNavigation()
                  : const WelcomeScreen(),
            ),

          // The Splash Overlay
          SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                // Detect swipe up to dismiss
                if (details.primaryVelocity! < -500) {
                  _onAnimationComplete();
                }
              },
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    _buildLottieAnimation(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottieAnimation() {
    return Center(
      child: Lottie.asset(
        'assets/animation.json',
        controller: _lottieController,
        onLoaded: (composition) {
          _lottieController
            ..duration = composition.duration
            ..forward();

          // Safety timer in case animation doesn't complete
          _safetyTimer =
              Timer(composition.duration + const Duration(seconds: 1), () {
            if (mounted && !_animationCompleted) _onAnimationComplete();
          });
        },
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.8,
      ),
    );
  }
}
