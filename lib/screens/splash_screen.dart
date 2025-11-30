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

  // Track if splash was shown in this app session (resets when app is killed)
  static bool _hasShownInSession = false;
  // Track if services are already initialized in current session
  static bool _servicesInitialized = false;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;
  AnimationController? _lottieController;
  Timer? _safetyTimer;

  bool _animationCompleted = false;
  bool _slideStarted = false;
  bool _isAuthenticated = false;
  bool _showSplash = true;
  bool _appInitialized = false;

  @override
  void initState() {
    super.initState();

    // If splash was already shown in this session (returning from background)
    if (SplashScreen._hasShownInSession) {
      _showSplash = false;
      _animationCompleted = true;
      _initAppQuick();
    } else {
      // Fresh app launch - show splash
      _initializeUI();
      _initApp();
      _initializeLottie();
    }
  }

  // Quick initialization when returning from background
  Future<void> _initAppQuick() async {
    if (!SplashScreen._servicesInitialized) {
      await _initApp();
    } else {
      _checkAuth();
      if (mounted) {
        setState(() {
          _appInitialized = true;
          _showSplash = false;
        });
      }
    }
  }

  Future<void> _initApp() async {
    try {
      // Only initialize services if not already done
      if (!SplashScreen._servicesInitialized) {
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

        SplashScreen._servicesInitialized = true;
      }

      if (mounted) {
        _checkAuth();
        setState(() => _appInitialized = true);
        if (SplashScreen._hasShownInSession) {
          setState(() => _showSplash = false);
        } else {
          _tryNavigate();
        }
      }
    } catch (e) {
      debugPrint('App initialization failed: $e');
      if (mounted) {
        _checkAuth();
        setState(() => _appInitialized = true);
        if (SplashScreen._hasShownInSession) {
          setState(() => _showSplash = false);
        } else {
          _tryNavigate();
        }
      }
    }
  }

  void _checkAuth() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (mounted) {
        setState(() {
          _isAuthenticated = session != null;
        });
      }
    } catch (e) {
      _isAuthenticated = false;
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
            parent: _slideController!,
            curve: Curves.easeInOutCubic,
          ),
        );

    _slideController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showSplash = false;
          });
        }
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

    _lottieController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });
  }

  void _onAnimationComplete() {
    if (!mounted || _animationCompleted) return;

    SplashScreen._hasShownInSession = true;
    setState(() => _animationCompleted = true);
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_animationCompleted && _appInitialized && !_slideStarted) {
      _slideStarted = true;
      _slideController?.forward();
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _slideController?.dispose();
    _lottieController?.dispose();
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
          if (_slideAnimation != null)
            SlideTransition(
              position: _slideAnimation!,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! < -500) {
                    _onAnimationComplete();
                  }
                },
                child: Container(
                  color: Colors.black,
                  child: Stack(children: [_buildLottieAnimation()]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLottieAnimation() {
    if (_lottieController == null) return const SizedBox.shrink();

    return Center(
      child: Lottie.asset(
        'assets/animation.json',
        controller: _lottieController,
        onLoaded: (composition) {
          _lottieController!
            ..duration = composition.duration
            ..forward();

          _safetyTimer = Timer(
            composition.duration + const Duration(seconds: 1),
            () {
              if (mounted && !_animationCompleted) _onAnimationComplete();
            },
          );
        },
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.8,
      ),
    );
  }
}
