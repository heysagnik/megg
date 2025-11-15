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
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  VideoPlayerController? _videoController;

  bool _videoInitialized = false;
  bool _videoCompleted = false;
  bool _fadeStarted = false;

  @override
  void initState() {
    super.initState();
    _initializeUI();
    _initializeVideo();
  }

  void _initializeUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
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

    if (!_fadeStarted && position >= const Duration(milliseconds: 2000)) {
      _fadeStarted = true;
      _fadeController.forward();
    }

    if (duration != Duration.zero &&
        position >= duration - const Duration(milliseconds: 80)) {
      _onVideoComplete();
    }
  }

  void _onVideoComplete() {
    if (_videoCompleted) return;

    setState(() => _videoCompleted = true);

    if (!_fadeStarted) {
      _fadeStarted = true;
      _fadeController.forward();
    }
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    final isAuthenticated =
        Supabase.instance.client.auth.currentSession != null;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isAuthenticated ? const MainNavigation() : const WelcomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_videoInitialized && _videoController != null)
            _buildVideoPlayer(),
          if (_fadeStarted) _buildTransitionOverlay(),
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

  Widget _buildTransitionOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Container(
            color: Colors.white.withOpacity(_fadeAnimation.value),
          );
        },
      ),
    );
  }
}
