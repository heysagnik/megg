import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/offline_banner.dart';
import 'category_reels_screen.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
  ];

  // Search keywords for each guide category
  static const Map<String, List<String>> _searchKeywords = {
    'date_fit': [
      'Date Outfit', 'Date Look', 'Date Wear', 'Outing Outfit', 'Casual Date Outfit',
      'Romantic Look', 'Date Aesthetic', 'Date Night Fit', 'Date Night Look', 'Soft Boy Look',
      'Chill Date Fit', 'Dinner Date Outfit', 'Coffee Date Outfit', 'Movie Date Outfit',
      'Lunch Date Look', 'brunch date', 'date',
    ],
    'college_fit': [
      'College Outfit', 'College Look', 'Casual Outfit', 'Campus Outfit', 'Campus Look',
      'Everyday College Wear', 'College Aesthetic', 'Campus Aesthetic', 'Student Fit',
      'Student Look', 'Youth Fit', 'Casual Day Fit', 'Daily Wear', 'Minimal College Fit',
      'Chill Fit', 'college',
    ],
    'office_fit': [
      'Office Outfit', 'Work Outfit', 'Workwear', 'Formal Wear', 'Business Attire',
      'Corporate Look', 'Office Look', 'Work Look', 'Business Casual', 'Semi-Formal Look',
      'Work Aesthetic', 'Office Aesthetic', 'Corporate Fit', 'Workday Fit', 'office', 'formal',
    ],
    'winter_fit': [
      'Winter Outfit', 'Winter Look', 'Cold Weather Outfit', 'Cold Weather Look', 'Winter Wear',
      'Winter Style', 'Winter Aesthetic', 'Cozy Fit', 'Cozy Look', 'Layered Fit', 'Layered Look',
      'Winter Vibes Fit', 'Outerwear Look', 'Seasonal Fit', 'Chilly Weather Outfit', 'winter', 'cold',
    ],
    'party_fit': [
      'Party Outfit', 'Party Look', 'Party Wear', 'Night Out Outfit', 'Night Out Look',
      'Club Outfit', 'Club Look', 'Party Aesthetic', 'Nightlife Fit', 'Evening Fit',
      'Party Vibes Look', 'Glam Fit', 'Glam Look', 'Birthday Party Outfit', 'Celebration Look',
      'Event Outfit', 'party', 'club', 'night out',
    ],
    'layering_fit': [
      'Layered Outfit', 'Layered Look', 'Layering Outfit', 'Layering Look', 'Multi-Layer Outfit',
      'Layered Aesthetic', 'Layering Aesthetic', 'Layered Streetwear', 'Layering Vibes',
      'Winter Layers', 'Cold Weather Layers', 'Fall/Winter Layered Fit', 'Outerwear Look',
      'Styled Layers', 'Layered Fashion', 'layering', 'layers',
    ],
    'old_money': [
      'Classic Style', 'Timeless Fashion', 'Elite Style', 'Vintage Luxury', 'Heritage Look',
      'Old Money Aesthetic', 'Quiet Luxury', 'Soft Luxury', 'Rich Aesthetic', 'Preppy Aesthetic',
      'European Summer Look', 'Chic Minimalism', 'Refined Style', 'Sophisticated Look',
      'Elegant Fit', 'Prestige Style', 'Classy Fit', 'Royal Aesthetic', 'Elite Fit', 'Opulent Look',
      'old money', 'luxury', 'elegant', 'classy',
    ],
    'street_wear': [
      'Urban Wear', 'Casual Street Style', 'City Wear', 'Street Style Outfit', 'Casual Street Outfit',
      'Street Aesthetic', 'Urban Aesthetic', 'Skater Fit', 'Hip-Hop Fit', 'Street Vibes',
      'Oversized Fit', 'Street Casual', 'Street Fashion', 'Graphic Tee Look', 'Hoodie & Sneaker Look',
      'Cool Casual Fit', 'Urban Edge', 'City Street Fit', 'Street Culture Look', 'streetwear', 'urban', 'street',
    ],
    'color_combo': [
      'Color Pairing', 'Color Match', 'Color Coordination', 'Color Mix', 'Matching Colors',
      'Color Palette', 'Outfit Palette', 'Style Palette', 'Color Vibes', 'Palette Look',
      'Mix & Match', 'Coordinated Outfit', 'Color Harmony', 'Chic Colors', 'Vibrant Combos',
      'Muted Combos', 'Classic Pairing', 'color', 'combo', 'palette',
    ],
    'personality_development': [
      'Self Improvement', 'Personal Growth', 'Self Development', 'Character Development',
      'Personal Enhancement', 'Self Transformation', 'Glow-Up Journey', 'Upgrade Yourself',
      'Better You Journey', 'Mindset Growth', 'Soft Skills Development', 'Professional Development',
      'Personal Skill Building', 'Behavioural Development', 'Self-Management Skills',
      'Becoming Your Best Self', 'Level Up Journey', 'Growth Mindset Path', 'personality', 'development', 'growth',
    ],
    'wedding_fit': [
      'Wedding Outfit', 'Wedding Look', 'Wedding Wear', 'Ceremony Outfit', 'Marriage Outfit',
      'Wedding Aesthetic', 'Shaadi Fit', 'Shaadi Look', 'Festive Fit', 'Festive Look',
      'Celebration Fit', 'Reception Outfit', 'Engagement Outfit', 'Sangeet Look', 'Haldi Look',
      'Mehendi Fit', 'wedding', 'shaadi', 'festive',
    ],
  };

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.isEmpty) {
      return _allGuideCategories;
    }

    final query = _searchQuery.toLowerCase();
    return _allGuideCategories.where((category) {
      // Check if category name matches
      if (category['name'].toString().toLowerCase().contains(query)) {
        return true;
      }

      // Check if any keyword matches
      final key = category['key'] as String;
      final keywords = _searchKeywords[key];
      if (keywords != null) {
        return keywords.any((keyword) => keyword.toLowerCase().contains(query));
      }

      return false;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _filteredCategories;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(title: 'GUIDES'),
      body: Column(
        children: [
          // Offline banner
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        fontFamily: 'FuturaCyrillicBook',
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'SEARCH GUIDES',
                        hintStyle: TextStyle(
                          fontFamily: 'FuturaCyrillicBook',
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: Colors.grey[500],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isCollapsed: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        PhosphorIconsRegular.x,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      splashRadius: 20,
                      padding: const EdgeInsets.all(8),
                    ),
                ],
              ),
            ),
          ),


          // Grid or empty state
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsRegular.magnifyingGlass, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No guides found for "$_searchQuery"',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
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
