import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  VideoPlayerController? _videoController;
  Timer? _safetyTimer;

  bool _videoInitialized = false;
  bool _videoCompleted = false;
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
      _initializeVideo();
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

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset('assets/animatedlogo.mp4');

    try {
      await _videoController!.initialize();
      if (!mounted) return;

      await _videoController!.setVolume(0.0);
      await _videoController!.setLooping(false);
      _videoController!.addListener(_onVideoProgress);

      final duration = _videoController!.value.duration;
      if (duration != Duration.zero) {
        // Use a safety timer that is longer than the video duration
        // to prevent getting stuck if the video player fails to report progress
        _safetyTimer = Timer(duration + const Duration(seconds: 2), () {
          if (mounted && !_videoCompleted) _onVideoComplete();
        });
      }

      await _videoController!.play();

      if (mounted) {
        setState(() => _videoInitialized = true);
      }
    } catch (e) {
      debugPrint('Video initialization failed: $e');
      if (mounted) {
        setState(() => _videoInitialized = false);
        _onVideoComplete();
      }
    }
  }

  void _onVideoProgress() {
    if (!mounted ||
        _videoCompleted ||
        _videoController == null ||
        !_videoController!.value.isInitialized)
      return;

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    // Start slide slightly before video ends for smoothness
    // Reduced buffer to 200ms to ensure video plays mostly to the end
    if (!_slideStarted &&
        duration != Duration.zero &&
        position >= duration - const Duration(milliseconds: 200)) {
      _onVideoComplete();
    }
  }

  void _onVideoComplete() {
    if (!mounted || _videoCompleted) return;

    hasShown = true;
    setState(() => _videoCompleted = true);
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_videoCompleted && _appInitialized && !_slideStarted) {
      _slideStarted = true;
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _slideController.dispose();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
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
                  _onVideoComplete();
                }
              },
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    if (_videoInitialized && _videoController != null)
                      _buildVideoPlayer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.fitWidth,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }
}
