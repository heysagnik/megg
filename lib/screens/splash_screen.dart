import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../services/startup_service.dart';
import '../services/wishlist_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_download_service.dart';
import '../services/reel_service.dart';
import '../services/deep_link_service.dart';
import 'welcome_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static bool _hasShownInSession = false;
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

    if (SplashScreen._hasShownInSession) {
      _showSplash = false;
      _animationCompleted = true;
      _initAppQuick();
    } else {
      _initializeUI();
      _initApp();
      _initializeLottie();
    }
  }

  Future<void> _initAppQuick() async {
    if (!SplashScreen._servicesInitialized) {
      await _initApp();
    } else {
      await _checkAuth();
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
      if (!SplashScreen._servicesInitialized) {
        // Local-only services first (always work)
        await CacheService().init();
        await ConnectivityService().init();
        await OfflineDownloadService().init();
        
        // Firebase with timeout - don't block on network issues
        try {
          await Firebase.initializeApp().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[Splash] Firebase timeout - continuing offline');
              return Firebase.app();
            },
          );
        } catch (e) {
          debugPrint('[Splash] Firebase init failed: $e');
        }

        // Auth can work from cache if offline
        await AuthService().init();
        await WishlistService().init();
        
        // Initialize offline sync for reel likes
        ReelService().initOfflineSync();
        
        // Prefetch with timeout - optional, don't block
        try {
          await StartupService().prefetchData().timeout(
            const Duration(seconds: 3),
            onTimeout: () => debugPrint('[Splash] Prefetch timeout'),
          );
        } catch (e) {
          debugPrint('[Splash] Prefetch failed: $e');
        }

        // FCM/Notifications - catch errors, don't block
        try {
          await FCMService().initialize().timeout(
            const Duration(seconds: 3),
            onTimeout: () => debugPrint('[Splash] FCM timeout'),
          );
          await NotificationService().initialize();
        } catch (e) {
          debugPrint('[Splash] Notification init failed: $e');
        }

        SplashScreen._servicesInitialized = true;
      }

      if (mounted) {
        await _checkAuth();
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
        await _checkAuth();
        setState(() => _appInitialized = true);
        if (SplashScreen._hasShownInSession) {
          setState(() => _showSplash = false);
        } else {
          _tryNavigate();
        }
      }
    }
  }

  Future<void> _checkAuth() async {
    final isAuth = AuthService().isAuthenticated;
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
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
        // App is now ready for deep link navigation
        DeepLinkService().setAppReady();
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
    if (!_showSplash) {
      return _isAuthenticated ? const MainNavigation() : const WelcomeScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_appInitialized)
            Positioned.fill(
              child: _isAuthenticated
                  ? const MainNavigation()
                  : const WelcomeScreen(),
            ),

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
