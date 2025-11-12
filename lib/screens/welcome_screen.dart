import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_navigation.dart';
import '../services/auth_service.dart';
import '../widgets/loader.dart';

// Disable glow/overscroll to align with Zara/MEGG minimalism
class NoGlowBehavior extends ScrollBehavior {
  const NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();
  final ScrollController _leftController = ScrollController();
  final ScrollController _centerController = ScrollController();
  final ScrollController _rightController = ScrollController();

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription? _authSubscription;

  final List<String> productImages = const [
    'https://images.unsplash.com/photo-1600185365926-3a2ce3cdb9eb?w=400',
    'https://images.unsplash.com/photo-1539533113208-f6df8cc8b543?w=400',
    'https://images.unsplash.com/photo-1588099768523-f4e6a5679d88?w=400',
    'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400',
    'https://images.unsplash.com/photo-1556906781-9a412961c28c?w=400',
    'https://images.unsplash.com/photo-1585487000143-3b6380f1dc6e?w=400',
    'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=400',
    'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=400',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400',
    'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400',
    'https://images.unsplash.com/photo-1560769629-975ec94e6a86?w=400',
    'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=400',
  ];

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startColumnAutoScroll(
        _leftController,
        reverse: false,
        duration: const Duration(seconds: 180),
      );
      _startColumnAutoScroll(
        _rightController,
        reverse: false,
        duration: const Duration(seconds: 180),
      );
      _startColumnAutoScroll(
        _centerController,
        reverse: true,
        duration: const Duration(seconds: 240),
      );
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

  Future<void> _startColumnAutoScroll(
    ScrollController controller, {
    required bool reverse,
    required Duration duration,
  }) async {
    while (mounted) {
      if (!controller.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final maxScroll = controller.position.maxScrollExtent;
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }
      try {
        if (reverse) {
          // Scroll from max to 0; ensure starting near max
          if (controller.offset <= 0.0) controller.jumpTo(maxScroll);
          await controller.animateTo(
            0.0,
            duration: duration,
            curve: Curves.linear,
          );
        } else {
          // Scroll from 0 to max; ensure starting near 0
          if (controller.offset >= maxScroll) controller.jumpTo(0.0);
          await controller.animateTo(
            maxScroll,
            duration: duration,
            curve: Curves.linear,
          );
        }
      } catch (_) {
        // ignore; controller might be disposed/interrupted mid-animation
      }
      // Loop will continue while mounted
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _leftController.dispose();
    _centerController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Product Grid
            Expanded(child: _buildProductGrid()),

            // Bottom Section with branding and auth buttons
            _buildBottomSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    const double gap = 12.0; // Design system medium spacing

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildColumnList(
                  controller: _leftController,
                  isCenter: false,
                  start: 0,
                  gap: gap,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: _buildColumnList(
                  controller: _centerController,
                  isCenter: true,
                  start: 1,
                  gap: gap,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: _buildColumnList(
                  controller: _rightController,
                  isCenter: false,
                  start: 2,
                  gap: gap,
                ),
              ),
            ],
          ),
        ),

        // Removed SKIP overlay for a cleaner, distraction-free hero

        // Bottom gradient fade to white (for legibility)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.0), Colors.white],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnList({
    required ScrollController controller,
    required bool isCenter,
    required int start,
    required double gap,
  }) {
    const double smallH = 140;
    final double tallH = smallH * 2 + gap;
    return ScrollConfiguration(
      behavior: const NoGlowBehavior(),
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 200,
        itemBuilder: (context, i) {
          final img = _imgAt(start + i);
          final h = isCenter ? tallH : smallH;
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: _productCard(img, height: h),
          );
        },
      ),
    );
  }

  String _imgAt(int index) => productImages[index % productImages.length];

  Widget _productCard(String imageUrl, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFEFEF), Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand Name
          const Text(
            'MEGG',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w300,
              letterSpacing: 12,
              color: Colors.black,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),

          // Tagline
          Text(
            'Fashion Sale Alerts',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
              color: Colors.black.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 40),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: _isLoading
                  ? const Loader(size: 20)
                  : Image.network(
                      'https://www.google.com/favicon.ico',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.g_mobiledata,
                          size: 24,
                          color: Colors.black,
                        );
                      },
                    ),
              label: Text(
                _isLoading ? 'SIGNING IN...' : 'CONTINUE WITH GOOGLE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                  color: _isLoading ? Colors.grey : Colors.black,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _isLoading ? Colors.grey : Colors.black,
                  width: 1,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MainNavigation(),
                      ),
                    );
                  },
            child: Text(
              'SKIP FOR NOW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
                color: _isLoading ? Colors.grey : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
