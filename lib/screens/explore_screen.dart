import 'package:flutter/material.dart';
import 'package:megg/screens/search_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/lazy_image.dart';
import '../services/offer_service.dart';
import 'category_browse_screen.dart';
import '../widgets/loader.dart';

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final List<Map<String, dynamic>> _categories = [
    {'icon': PhosphorIconsRegular.tShirt, 'label': 'SHIRTS'},
    {'icon': PhosphorIconsRegular.pants, 'label': 'PANTS'},
    {'icon': PhosphorIconsRegular.drop, 'label': 'SKINCARE'},
  ];

  int _currentIndex = 0;

  final OfferService _offerService = OfferService();
  List<Map<String, dynamic>> _offers = [];
  bool _isLoadingOffers = true;
  String? _offersError;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % _categories.length;
            });
            _animationController.reset();
            _animationController.forward();
          }
        });
      }
    });

    _animationController.forward();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      setState(() {
        _isLoadingOffers = true;
        _offersError = null;
      });

      final offers = await _offerService.getOffers(limit: 10);

      if (mounted) {
        setState(() {
          _offers = offers;
          _isLoadingOffers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _offersError = e.toString();
          _isLoadingOffers = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AestheticAppBar(title: 'EXPLORE'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 28),
            _buildSalesSection(context),
            const SizedBox(height: 32),
            _buildFitCategories(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [
              Text(
                'OFFERS & SALES',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: _isLoadingOffers
              ? const Center(child: Loader(size: 20))
              : _offersError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsRegular.warningCircle,
                          color: Colors.grey[400],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to load offers',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _offers.isEmpty
              ? Center(
                  child: Text(
                    'No offers available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : ScrollConfiguration(
                  behavior: const _NoGlowBehavior(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _offers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      return _saleBannerCard(_offers[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _saleBannerCard(Map<String, dynamic> offer) {
    final title =
        (offer['name'] ?? offer['title'])?.toString().toUpperCase() ??
        'SPECIAL OFFER';
    final description = offer['description']?.toString() ?? '';
    final imageUrl =
        (offer['banner_image'] ?? offer['image_url'])?.toString() ??
        'https://via.placeholder.com/1000x600/F5F5F5/000000?text=OFFER';
    final discount = offer['discount_percentage']?.toString();
    final affiliateLink = offer['affiliate_link']?.toString();

    return GestureDetector(
      onTap: affiliateLink != null && affiliateLink.isNotEmpty
          ? () => _openAffiliateLink(affiliateLink)
          : null,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
          color: Colors.white,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LazyImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: Colors.grey[100],
                child: Center(
                  child: Icon(
                    PhosphorIconsRegular.image,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (discount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAffiliateLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open link'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid link'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withOpacity(0.15), width: 1),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              // Animated category icon carousel
              SizedBox(
                width: 24,
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    final category = _categories[_currentIndex];
                    final nextCategory =
                        _categories[(_currentIndex + 1) % _categories.length];

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Current item sliding out
                        Opacity(
                          opacity: 1.0 - _slideAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, -20 * _slideAnimation.value),
                            child: _buildCategoryIcon(category['icon']),
                          ),
                        ),
                        // Next item sliding in
                        Opacity(
                          opacity: _slideAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                            child: _buildCategoryIcon(nextCategory['icon']),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search styles, products...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 20,
                color: Colors.grey[600]!,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon) {
    return Icon(icon, size: 20, color: Colors.grey[600]!);
  }

  Widget _buildFitCategories(BuildContext context) {
    final categories = [
      {'name': 'Jacket', 'image': 'assets/category/jacket.jpg'},
      {'name': 'Jeans', 'image': 'assets/category/jeans.jpg'},
      {'name': 'Shoes', 'image': 'assets/category/shoes.jpg'},
      {'name': 'Skincare', 'image': 'assets/category/skin care.png'},
      {'name': 'Perfume', 'image': 'assets/category/perfume .jpg'},
      {'name': 'Shirt', 'image': 'assets/category/shirt.jpg'},
      {'name': 'Trackpants', 'image': 'assets/category/trackpants.jpg'},
      {'name': 'Hoodies', 'image': 'assets/category/hoodies .jpg'},
      {'name': 'Sweater', 'image': 'assets/category/sweater.jpg'},
      {'name': 'Sweatshirt', 'image': 'assets/category/sweatshirt.jpg'},
      {'name': 'Tshirt', 'image': 'assets/category/tshirt.jpg'},

      {'name': 'Accesories', 'image': 'assets/category/accessories.jpg'},
      {'name': 'Innerwear', 'image': 'assets/category/innerwear.jpg'},

      {'name': 'Sports Wear', 'image': 'assets/category/sports.jpg'},
      {'name': 'Office Wear', 'image': 'assets/category/formals.jpg'},

      {'name': 'Traditional', 'image': 'assets/category/traditional.jpg'},
      {
        'name': 'Daily Essentials',
        'image': 'assets/category/daily essentials .jpg',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHOP BY CATEGORY',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildBentoGrid(context, categories),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(
    BuildContext context,
    List<Map<String, dynamic>> categories,
  ) {
    return Column(
      children: [
        // Row 1: 1 tall + 2 stacked small
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildCategoryBox(context, categories[0], height: 320),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  _buildCategoryBox(context, categories[1], height: 158),
                  const SizedBox(height: 4),
                  _buildCategoryBox(context, categories[2], height: 158),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Row 2: 2 medium boxes
        Row(
          children: [
            Expanded(
              child: _buildCategoryBox(context, categories[3], height: 200),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCategoryBox(context, categories[4], height: 200),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Row 3: 2 stacked small + 1 tall
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildCategoryBox(context, categories[5], height: 158),
                  const SizedBox(height: 4),
                  _buildCategoryBox(context, categories[6], height: 158),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _buildCategoryBox(context, categories[7], height: 320),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Row 4: 3 small boxes
        Row(
          children: [
            Expanded(
              child: _buildCategoryBox(context, categories[8], height: 160),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCategoryBox(context, categories[9], height: 160),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCategoryBox(context, categories[10], height: 160),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Row 5: 1 wide
        _buildCategoryBox(context, categories[11], height: 180, isWide: true),
        const SizedBox(height: 4),
        // Row 6: 2 medium boxes
        Row(
          children: [
            Expanded(
              child: _buildCategoryBox(context, categories[12], height: 200),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCategoryBox(context, categories[13], height: 200),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Row 7: 2 medium boxes
        Row(
          children: [
            Expanded(
              child: _buildCategoryBox(context, categories[14], height: 200),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCategoryBox(context, categories[15], height: 200),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Row 8: single box for the 17th category (index 16)
        if (categories.length > 16)
          _buildCategoryBox(context, categories[16], height: 160),
      ],
    );
  }

  Widget _buildCategoryBox(
    BuildContext context,
    Map<String, dynamic> category, {
    double height = 100,
    bool isWide = false,
  }) {
    final imageUrl = category['image']?.toString() ?? '';
    final name = category['name']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryBrowseScreen(category: name),
          ),
        );
      },
      child: Container(
        height: height,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: Icon(
                      PhosphorIconsRegular.image,
                      size: 32,
                      color: Colors.grey[300],
                    ),
                  ),
                );
              },
            ),
            // Subtle gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            // Category label
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black26,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
