import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/aesthetic_app_bar.dart';
import 'category_reels_screen.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  static final List<Map<String, dynamic>> _guideCategories = [
    {'name': 'Office fit', 'image': 'assets/guides/formal.jpg'},
    {'name': 'Layering outfit', 'image': 'assets/guides/layering fit.jpg'},
    {'name': 'Winter fit', 'image': 'assets/guides/winter.jpg'},
    {'name': 'Wedding fit', 'image': 'assets/guides/festive.jpg'},
    {'name': 'Travel fit', 'image': 'assets/guides/date.jpg'},
    {
      'name': 'Personality development',
      'image': 'assets/guides/personality dev.jpg',
    },
    {'name': 'Date fit', 'image': 'assets/guides/date.jpg'},
    {'name': 'Colour combo', 'image': 'assets/guides/color combo.jpg'},
    {'name': 'College fit', 'image': 'assets/guides/college.jpg'},
    {'name': 'Party fit', 'image': 'assets/guides/party fit.jpg'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(title: 'GUIDES'),
      body: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _guideCategories.length,
        itemBuilder: (context, index) {
          final category = _guideCategories[index];
          return _GuideCard(
            name: category['name'] as String,
            imagePath: category['image'] as String,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CategoryReelsScreen(category: category['name'] as String),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String name;
  final String imagePath;
  final VoidCallback onTap;

  const _GuideCard({
    required this.name,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          //borderRadius: BorderRadius.circular(5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagePath, fit: BoxFit.cover),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'FuturaCyrillicBook',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsFill.play,
                            color: Colors.white.withOpacity(0.85),
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'WATCH',
                            style: TextStyle(
                              fontFamily: 'FuturaCyrillicBook',
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 8,
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
            ],
          ),
        ),
      ),
    );
  }
}
