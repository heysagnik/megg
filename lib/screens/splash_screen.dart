import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
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

  bool _videoInitialized = false;
  bool _videoCompleted = false;
  bool _slideStarted = false;
  bool _isAuthenticated = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _initializeUI();
    _initializeVideo();
  }

  void _checkAuth() {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _isAuthenticated = session != null;
    });
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
        setState(() {
          _showSplash = false;
        });
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
      await _videoController!.setVolume(0.0);
      await _videoController!.setLooping(false);
      _videoController!.addListener(_onVideoProgress);

      final duration = _videoController!.value.duration;
      if (duration != Duration.zero) {
        Timer(duration + const Duration(milliseconds: 100), () {
          if (!_videoCompleted) _onVideoComplete();
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
    if (_videoCompleted || _videoController == null) return;

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    // Start slide slightly before video ends for smoothness
    if (!_slideStarted &&
        duration != Duration.zero &&
        position >= duration - const Duration(milliseconds: 500)) {
      _onVideoComplete();
    }
  }

  void _onVideoComplete() {
    if (_videoCompleted) return;

    setState(() => _videoCompleted = true);

    if (!_slideStarted) {
      _slideStarted = true;
      _slideController.forward();
    }
  }

  @override
  void dispose() {
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
          Positioned.fill(
            child: _isAuthenticated
                ? const MainNavigation()
                : const WelcomeScreen(),
          ),

          // The Splash Overlay
          SlideTransition(
            position: _slideAnimation,
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
