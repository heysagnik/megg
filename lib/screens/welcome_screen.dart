import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_navigation.dart';
import '../services/auth_service.dart';
import '../widgets/loader.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAuthListener();
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Video is already muted, so no action needed during calls
    // It will keep playing silently
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/intro.mp4')
      ..initialize()
          .then((_) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController.setLooping(true);
            _videoController.setVolume(0.0); // Mute the video
            _videoController.play();
          })
          .catchError((error) {
            debugPrint('Error initializing video: $error');
          });
  }

  void _setupAuthListener() {
    _authSubscription = _authService.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedIn && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final launched = await _authService.signInWithGoogle();

      if (!mounted) return;

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('COMPLETE SIGN-IN IN THE BROWSER'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.black,
          ),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        children: [
          // Background Video
          if (_isVideoInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(color: Colors.black), // Placeholder while loading
          // Glassy Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.2), // Slight tint
            ),
          ),

          // Center Logo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MEGG',
                  style: TextStyle(
                    fontFamily: 'FuturaCyrillicBook',
                    fontSize: 80,
                    color: Colors.white,
                    letterSpacing: 4.0,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'by Meghansh Gupta',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 2.0,
                    wordSpacing: 6,
                    fontWeight: FontWeight.w400,
                    // optionally match the logo font:
                    fontFamily: 'FuturaCyrillicBook',
                  ),
                ),
              ],
            ),
          ),

          // Error Message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50]!.withOpacity(0.9),
                  border: Border.all(color: Colors.red[300]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Button with Glassy Effect
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                height: 60,
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                // ClipRRect ensures the blur doesn't leak outside the button area
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Stack(
                    children: [
                      // The Blur Effect
                      BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(color: Colors.white.withOpacity(0.1)),
                      ),
                      // The Button Content
                      SizedBox.expand(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.15),
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: BorderSide(color: Colors.white30, width: 1),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const Loader(size: 20, color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Make sure you add a Google logo image at assets/google_logo.png
                                    Image.network(
                                      'https://www.google.com/favicon.ico',
                                      width: 20,
                                      height: 20,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.g_mobiledata,
                                              size: 24,
                                              color: Colors.black,
                                            );
                                          },
                                    ),

                                    const SizedBox(width: 12),
                                    const Text(
                                      'CONTINUE WITH GOOGLE',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Skip Button
          Positioned(
            top: -10,
            right: -10,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const MainNavigation(),
                              ),
                            );
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'SKIP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: Color(0xFFEFEFEF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
