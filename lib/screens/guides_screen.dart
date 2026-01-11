import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/offline_banner.dart';
import 'category_reels_screen.dart';
import 'guide_search_screen.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  // Updated guide categories with new titles
  static final List<Map<String, dynamic>> _allGuideCategories = [
    {'name': 'Office', 'key': 'office_fit', 'image': 'assets/guides/formal.jpg'},
    {'name': 'Date', 'key': 'date_fit', 'image': 'assets/guides/date.jpg'},
    {'name': 'College', 'key': 'college_fit', 'image': 'assets/guides/college.jpg'},
    {'name': 'Party', 'key': 'party_fit', 'image': 'assets/guides/party fit.jpg'},
    {'name': 'Color-combo', 'key': 'color_combo', 'image': 'assets/guides/color combo.jpg'},
    {'name': 'Personality development', 'key': 'personality_development', 'image': 'assets/guides/personality dev.jpg'},
    {'name': 'Old money', 'key': 'old_money', 'image': 'assets/guides/formal.jpg'},
    {'name': 'Streetwear', 'key': 'street_wear', 'image': 'assets/guides/college.jpg'},
    {'name': 'Wedding', 'key': 'wedding_fit', 'image': 'assets/guides/festive.jpg'},
    {'name': 'Winter', 'key': 'winter_fit', 'image': 'assets/guides/winter.jpg'},
    {'name': 'Layering', 'key': 'layering_fit', 'image': 'assets/guides/layering fit.jpg'},
    {'name': 'Travel', 'key': 'travel_fit', 'image': 'assets/guides/airport.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(title: 'GUIDES'),
      body: Column(
        children: [
          // Offline banner
          const OfflineBanner(),
          
          // Tappable search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuideSearchScreen(),
                  ),
                );
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.black.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SEARCH GUIDES',
                      style: TextStyle(
                        fontFamily: 'FuturaCyrillicBook',
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _allGuideCategories.length,
              itemBuilder: (context, index) {
                final category = _allGuideCategories[index];
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
          ),
        ],
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
