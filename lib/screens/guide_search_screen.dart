import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../models/reel.dart';
import '../services/reel_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/lazy_image.dart';
import '../widgets/skeleton_loaders.dart';
import 'category_reels_screen.dart';

/// Instagram-style search screen for Guides section
class GuideSearchScreen extends StatefulWidget {
  const GuideSearchScreen({super.key});

  @override
  State<GuideSearchScreen> createState() => _GuideSearchScreenState();
}

class _GuideSearchScreenState extends State<GuideSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ReelService _reelService = ReelService();
  
  Timer? _debounce;
  String _searchQuery = '';
  List<Map<String, dynamic>> _suggestions = [];
  List<Reel> _searchResults = [];
  bool _isLoadingResults = false;
  String? _searchedCategory;

  // Guide category data (same as guides_screen.dart)
  static final List<Map<String, dynamic>> _allGuideCategories = [
    {'name': 'Office', 'key': 'office_fit'},
    {'name': 'Date', 'key': 'date_fit'},
    {'name': 'College', 'key': 'college_fit'},
    {'name': 'Party', 'key': 'party_fit'},
    {'name': 'Color-combo', 'key': 'color_combo'},
    {'name': 'Personality development', 'key': 'personality_development'},
    {'name': 'Old money', 'key': 'old_money'},
    {'name': 'Streetwear', 'key': 'street_wear'},
    {'name': 'Wedding', 'key': 'wedding_fit'},
    {'name': 'Winter', 'key': 'winter_fit'},
    {'name': 'Layering', 'key': 'layering_fit'},
    {'name': 'Travel', 'key': 'travel_fit'},
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
    'travel_fit': [
      'Travel Outfit', 'Travel Look', 'Airport Look', 'Airport Outfit', 'Vacation Fit',
      'Vacation Outfit', 'Trip Outfit', 'Holiday Look', 'Journey Fit', 'Getaway Outfit',
      'Travel Aesthetic', 'Airport Aesthetic', 'Wander Look', 'Explorer Fit', 'travel', 'airport', 'vacation',
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _updateSuggestions(query);
    });
    setState(() {
      _searchQuery = query.trim();

      _searchResults = [];
      _searchedCategory = null;
    });
  }

  void _updateSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    final List<Map<String, dynamic>> matches = [];

    // Search through all keywords
    for (final category in _allGuideCategories) {
      final key = category['key'] as String;
      final categoryName = category['name'] as String;
      final keywords = _searchKeywords[key] ?? [];

      // Check if category name matches
      if (categoryName.toLowerCase().contains(lowerQuery)) {
        matches.add({
          'keyword': categoryName,
          'category': categoryName,
          'key': key,
        });
      }

      // Check keywords
      for (final keyword in keywords) {
        if (keyword.toLowerCase().contains(lowerQuery)) {
          // Avoid duplicates
          if (!matches.any((m) => m['keyword'] == keyword)) {
            matches.add({
              'keyword': keyword,
              'category': categoryName,
              'key': key,
            });
          }
        }
      }
    }

    // Limit suggestions
    setState(() {
      _suggestions = matches.take(10).toList();
    });
  }

  Future<void> _performSearch(String categoryKey, String categoryName) async {
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoadingResults = true;
      _searchedCategory = categoryName;
      _suggestions = [];
    });

    try {
      final reels = await _reelService.getReelsByCategory(categoryName);
      if (mounted) {
        setState(() {
          _searchResults = reels;
          _isLoadingResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoadingResults = false;
        });
      }
    }
  }

  void _openReel(int index) {
    if (_searchedCategory != null && index < _searchResults.length) {
      final reelId = _searchResults[index].id;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryReelsScreen(
            category: _searchedCategory!,
            initialReelId: reelId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(
        title: 'SEARCH GUIDES',
        showBackButton: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoadingResults
                ? _buildLoadingGrid()
                : _searchResults.isNotEmpty
                    ? _buildResultsGrid()
                    : _suggestions.isNotEmpty
                        ? _buildSuggestionsList()
                        : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
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
                focusNode: _focusNode,
                style: const TextStyle(
                  fontFamily: 'FuturaCyrillicBook',
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  hintText: 'SEARCH STYLE GUIDES',
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
                onChanged: _onSearchChanged,
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
                    _suggestions = [];
                    _searchResults = [];
                    _searchedCategory = null;
                  });
                },
                splashRadius: 20,
                padding: const EdgeInsets.all(8),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final keyword = suggestion['keyword'] as String;
        final category = suggestion['category'] as String;
        final key = suggestion['key'] as String;

        return InkWell(
          onTap: () {
            _searchController.text = keyword;
            _performSearch(key, category);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keyword,
                        style: const TextStyle(
                          fontFamily: 'FuturaCyrillicBook',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'in $category',
                        style: TextStyle(
                          fontFamily: 'FuturaCyrillicBook',
                          fontSize: 11,
                          color: Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.arrowUpLeft,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Text(
                '${_searchResults.length} REELS',
                style: TextStyle(
                  fontFamily: 'FuturaCyrillicBook',
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (_searchedCategory != null)
                Text(
                  _searchedCategory!.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'FuturaCyrillicBook',
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // Instagram-style grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final reel = _searchResults[index];
              return _buildReelThumbnail(reel, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelThumbnail(Reel reel, int index) {
    return GestureDetector(
      onTap: () => _openReel(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image
          LazyImage(
            imageUrl: reel.thumbnailUrl.isNotEmpty 
                ? reel.thumbnailUrl 
                : reel.videoUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorWidget: Container(
              color: Colors.grey[200],
              child: Icon(
                PhosphorIconsRegular.videoCamera,
                color: Colors.grey[400],
                size: 24,
              ),
            ),
          ),
          // Reel indicator
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              PhosphorIconsFill.play,
              color: Colors.white,
              size: 16,
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          // Views count
          Positioned(
            bottom: 8,
            left: 8,
            child: Row(
              children: [
                Icon(
                  PhosphorIconsFill.play,
                  color: Colors.white,
                  size: 12,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatViews(reel.views),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return const ShimmerBox();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Search for style guides'
                : 'No guides found for "$_searchQuery"',
            style: TextStyle(
              fontFamily: 'FuturaCyrillicBook',
              fontSize: 14,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try: Office, Party, Date, Wedding',
            style: TextStyle(
              fontFamily: 'FuturaCyrillicBook',
              fontSize: 12,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
