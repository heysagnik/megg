import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/auth_service.dart';

class LoginRequiredDialog extends StatefulWidget {
  const LoginRequiredDialog({super.key});

  @override
  State<LoginRequiredDialog> createState() => _LoginRequiredDialogState();
}

class _LoginRequiredDialogState extends State<LoginRequiredDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // Sharp corners per design system
        ),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.heart, // Minimal icon
                    size: 32,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'JOIN THE COMMUNITY',
                    style: TextStyle(
                      fontFamily: 'FuturaCyrillicBook',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.5, // Wide letter spacing for headers
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to save your favorite items and create your personal collection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'FuturaCyrillicBook',
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                      letterSpacing: 0.3, // Tight spacing for body
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48, // Fixed height for touch targets
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await AuthService().signInWithGoogle();
                        } catch (e) {
                          // Handle error
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero, // Sharp corners
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsBold.googleLogo,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'CONTINUE WITH GOOGLE',
                            style: TextStyle(
                              fontFamily: 'FuturaCyrillicBook',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'MAYBE LATER',
                      style: TextStyle(
                        fontFamily: 'FuturaCyrillicBook',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
