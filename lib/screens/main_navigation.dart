import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'guides_screen.dart';
import 'profile_screen.dart';

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
            builder: (context) {
              return AlertDialog(
                title: const Text('Exit App'),
                content: const Text('Are you sure you want to exit the app?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Yes'),
                  ),
                ],
              );
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
              top: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, 'HOME', 'home'),
                  _buildNavItem(1, 'EXPLORE', 'explore'),
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
          isSelected
              ? PhosphorIconsFill.books
              : PhosphorIconsRegular.books,
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
