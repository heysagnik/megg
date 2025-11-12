import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/aesthetic_app_bar.dart';
import 'category_reels_screen.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  static final List<Map<String, dynamic>> _guideCategories = [
    {
      'name': 'Office fit',
      'icon': PhosphorIconsRegular.briefcase,
      'color': const Color(0xFF1a1a1a),
    },
    {
      'name': 'Layering outfit',
      'icon': PhosphorIconsRegular.stack,
      'color': const Color(0xFF2c2c2c),
    },
    {
      'name': 'Winter fit',
      'icon': PhosphorIconsRegular.snowflake,
      'color': const Color(0xFF3d5a80),
    },
    {
      'name': 'Festive fit',
      'icon': PhosphorIconsRegular.confetti,
      'color': const Color(0xFFc1121f),
    },
    {
      'name': 'Travel fit',
      'icon': PhosphorIconsRegular.airplaneTilt,
      'color': const Color(0xFF06a77d),
    },
    {
      'name': 'Personality development',
      'icon': PhosphorIconsRegular.user,
      'color': const Color(0xFF6a4c93),
    },
    {
      'name': 'Date fit',
      'icon': PhosphorIconsRegular.heart,
      'color': const Color(0xFFe63946),
    },
    {
      'name': 'Colour combo',
      'icon': PhosphorIconsRegular.palette,
      'color': const Color(0xFFf77f00),
    },
    {
      'name': 'College fit',
      'icon': PhosphorIconsRegular.graduationCap,
      'color': const Color(0xFF457b9d),
    },
    {
      'name': 'Party fit',
      'icon': PhosphorIconsRegular.sparkle,
      'color': const Color(0xFFd62828),
    },
    {
      'name': 'Airport look',
      'icon': PhosphorIconsRegular.airplane,
      'color': const Color(0xFF003049),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(title: 'GUIDES'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _guideCategories.length,
          itemBuilder: (context, index) {
            final category = _guideCategories[index];
            return _GuideCard(
              name: category['name'] as String,
              icon: category['icon'] as IconData,
              color: category['color'] as Color,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryReelsScreen(
                      category: category['name'] as String,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GuideCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const Spacer(),
              Text(
                name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.play,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'WATCH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
