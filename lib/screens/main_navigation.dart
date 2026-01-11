import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'guides_screen.dart';
import 'profile_screen.dart';
import 'ai_camera_screen.dart';
import '../models/product.dart';
import '../models/reel.dart';
import '../services/wishlist_service.dart';
import '../services/reel_service.dart';
import '../services/auth_service.dart';
// import '../services/offline_download_service.dart'; // OFFLINE FEATURE DISABLED
// import '../widgets/offline_mode_dialog.dart'; // OFFLINE FEATURE DISABLED
// import '../widgets/download_progress_sheet.dart'; // OFFLINE FEATURE DISABLED

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const GuidesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _prefetchProfileData();
    // _checkOfflinePrompt(); // OFFLINE FEATURE DISABLED
  }

  /* OFFLINE FEATURE DISABLED
  Future<void> _checkOfflinePrompt() async {
    ...
  }
  */

  /// Prefetch wishlist and liked reels data in background
  void _prefetchProfileData() {
    if (!AuthService().isAuthenticated) return;

    // Fire and forget - these will populate cache
    WishlistService().getWishlist().catchError((_) => <Product>[]);
    ReelService().getLikedReels().catchError((_) => <Reel>[]);
  }

  void _openAICamera() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AICameraScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }

        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (context) {
              return _ExitSignupDialog();
            },
          );

          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.black.withOpacity(0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _buildNavItem(0, 'HOME', 'home'),
                  _buildNavItem(1, 'EXPLORE', 'explore'),
                  _buildAIButton(),
                  _buildNavItem(2, 'GUIDES', 'guides'),
                  _buildNavItem(3, 'PROFILE', 'profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIButton() {
    return Expanded(
      child: GestureDetector(
        onTap: _openAICamera,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Elevated AI button with refined styling
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCameraAi,
                    color: Colors.white,
                    size: 24.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, String iconType) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 22, child: _buildIcon(iconType, isSelected)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? Colors.black : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String iconType, bool isSelected) {
    final color = isSelected ? Colors.black : Colors.grey[600]!;

    switch (iconType) {
      case 'home':
        return Icon(
          isSelected ? PhosphorIconsFill.house : PhosphorIconsRegular.house,
          size: 22,
          color: color,
        );
      case 'explore':
        return Icon(
          isSelected ? PhosphorIconsFill.compass : PhosphorIconsRegular.compass,
          size: 22,
          color: color,
        );
      case 'guides':
        return Icon(
          isSelected ? PhosphorIconsFill.books : PhosphorIconsRegular.books,
          size: 22,
          color: color,
        );
      case 'profile':
        return Icon(
          isSelected ? PhosphorIconsFill.user : PhosphorIconsRegular.user,
          size: 22,
          color: color,
        );
      default:
        return const SizedBox();
    }
  }
}

class _ExitSignupDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService().isAuthenticated;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAuthenticated ? 'EXIT APP' : 'WAIT!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAuthenticated
                    ? 'Are you sure you want to exit?'
                    : 'Sign up to save your progress and get personalized recommendations before you go!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  letterSpacing: 0.3,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 32),
              if (!isAuthenticated) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        // Close dialog first
                        Navigator.of(context).pop(false);
                        // Trigger sign in
                        await AuthService().signInWithGoogle();
                      } catch (e) {
                        debugPrint('Sign in error from exit dialog: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsBold.googleLogo, size: 18),
                        SizedBox(width: 12),
                        Text(
                          'CONTINUE WITH GOOGLE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isAuthenticated) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text(
                          'EXIT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'EXIT APP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
