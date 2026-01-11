import 'package:flutter/material.dart';
import 'package:megg/screens/search_screen.dart';
import 'package:megg/screens/notifications_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/color_combo.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/lazy_image.dart';
import '../widgets/skeleton_loaders.dart';
import '../services/trending_service.dart';
import '../services/product_service.dart';
import '../services/outfit_service.dart';
import '../services/wishlist_service.dart';
import '../services/cache_service.dart';
import '../services/color_combo_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'product_screen.dart';
import 'search_results_screen.dart';
import 'color_combo_list_screen.dart';
import 'outfit_products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TrendingService _trendingService = TrendingService();
  final ProductService _productService = ProductService();
  final OutfitService _outfitService = OutfitService();
  final WishlistService _wishlistService = WishlistService();
  final CacheService _cacheService = CacheService();
  final ColorComboService _colorComboService = ColorComboService();

  List<Product> _trendingProducts = [];
  List<Product> _newArrivals = [];
  List<Map<String, dynamic>> _dailyOutfits = [];
  List<Product> _recentlyViewedProducts = [];

  bool _isLoadingTrending = true;
  bool _isLoadingNew = true;
  bool _isLoadingOutfits = true;

  String? _trendingError;
  String? _newArrivalsError;
  String? _dailyOutfitsError;

  late final PageController _outfitPageController;
  Timer? _outfitAutoTimer;
  int _currentOutfitPage = 0;

  // Product interactions
  final Map<String, PageController> _trendingPageControllers = {};
  final Map<String, PageController> _newArrivalsPageControllers = {};
  final Map<String, PageController> _recentlyViewedPageControllers = {};
  final Set<String> _homeWishlist = {};

  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _limit = 10;

  @override
  void initState() {
    super.initState();
    _outfitPageController = PageController(initialPage: _currentOutfitPage);
    _scrollController.addListener(_scrollListener);
    _loadHomeData();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreNewArrivals();
      }
    }
  }

  Future<void> _loadHomeData({bool forceRefresh = false}) async {
    await Future.wait([
      _loadDailyOutfits(forceRefresh: forceRefresh),
      _loadTrendingProducts(forceRefresh: forceRefresh),
      _loadNewArrivals(forceRefresh: forceRefresh),
      _loadWishlist(),
      _loadRecentlyViewed(),
    ]);

    _prefetchColorCombos();
  }

  void _prefetchColorCombos() {
    final groups = ['formal', 'casual', 'winter', 'layering'];
    for (final group in groups) {
      _colorComboService.getColorCombos(group: group).catchError((_) => <ColorCombo>[]);
    }
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      debugPrint('[Home] Loading recently viewed...');
      final recentlyViewedMaps = await _cacheService
          .getRecentlyViewedProducts();
      
      debugPrint('[Home] Got ${recentlyViewedMaps.length} recently viewed maps');

      if (!mounted) return;

      final products = recentlyViewedMaps
          .map((map) {
            try {
              return Product.fromJson(map);
            } catch (e) {
              debugPrint('[Home] Error parsing product: $e');
              return null;
            }
          })
          .whereType<Product>()
          .toList();

      debugPrint('[Home] Parsed ${products.length} recently viewed products');
      
      setState(() {
        _recentlyViewedProducts = products;
      });

      // Initialize page controllers
      for (final p in products) {
        _recentlyViewedPageControllers.putIfAbsent(
          p.id,
          () => PageController(),
        );
      }
    } catch (e) {
      debugPrint('[Home] Error loading recently viewed: $e');
    }
  }

  Future<void> _loadWishlist() async {
    try {
      // Use fast cached wishlist IDs instead of full products
      final wishlistIds = await _wishlistService.getWishlistIds();
      if (!mounted) return;

      setState(() {
        _homeWishlist.clear();
        _homeWishlist.addAll(wishlistIds);
      });
    } catch (e) {
      // Silently fail - user might not be authenticated
      // Try to get cached IDs even on error
      try {
        final cachedIds = await _wishlistService.getWishlistIds();
        if (mounted) {
          setState(() {
            _homeWishlist.clear();
            _homeWishlist.addAll(cachedIds);
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _homeWishlist.clear();
          });
        }
      }
    }
  }

  Future<void> _loadDailyOutfits({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoadingOutfits = true;
        _dailyOutfitsError = null;
      });

      final outfits =
          await _outfitService.getDailyOutfits(forceRefresh: forceRefresh);

      if (!mounted) return;

      setState(() {
        _dailyOutfits = outfits;
        _isLoadingOutfits = false;
        _currentOutfitPage = 0;
      });

      if (_outfitPageController.hasClients) {
        _outfitPageController.jumpToPage(0);
      }

      if (outfits.length > 1) {
        _startOutfitCarousel();
      } else {
        _stopOutfitCarousel();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingOutfits = false;
        _dailyOutfitsError = e.toString().replaceAll('Exception: ', '');
        // Don't clear existing data on error if we have it
        if (_dailyOutfits.isEmpty) {
          _dailyOutfits = [];
        }
      });
      _stopOutfitCarousel();
    }
  }

  void _startOutfitCarousel() {
    _outfitAutoTimer?.cancel();
    if (_dailyOutfits.length <= 1) return;

    _outfitAutoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_outfitPageController.hasClients) return;

      final nextPage = (_currentOutfitPage + 1) % _dailyOutfits.length;

      _outfitPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopOutfitCarousel() {
    _outfitAutoTimer?.cancel();
    _outfitAutoTimer = null;
  }

  Future<void> _handleWishlistToggle(String productId) async {
    final wasInWishlist = _homeWishlist.contains(productId);

    // Optimistically update UI
    setState(() {
      if (wasInWishlist) {
        _homeWishlist.remove(productId);
      } else {
        _homeWishlist.add(productId);
      }
    });

    try {
      if (wasInWishlist) {
        await _wishlistService.removeFromWishlist(productId);
      } else {
        await _wishlistService.addToWishlist(productId);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (wasInWishlist) {
            _homeWishlist.add(productId);
          } else {
            _homeWishlist.remove(productId);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasInWishlist
                  ? 'Failed to remove from wishlist'
                  : 'Failed to add to wishlist',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadTrendingProducts({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoadingTrending = true;
        _trendingError = null;
      });

      final products = await _trendingService.getTrendingProducts(
        limit: 10,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      setState(() {
        _trendingProducts = products;
        _isLoadingTrending = false;
      });

      // Initialize page controllers for swipeable images
      for (final p in products) {
        _trendingPageControllers.putIfAbsent(p.id, () => PageController());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingTrending = false;
        _trendingError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadNewArrivals({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoadingNew = true;
        _newArrivalsError = null;
        if (forceRefresh) _page = 1;
      });

      final products = await _productService.getProducts(
        page: 1,
        limit: _limit,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      setState(() {
        _newArrivals = products;
        _isLoadingNew = false;
        _hasMore = products.length >= _limit;
      });

      for (final p in products) {
        _newArrivalsPageControllers.putIfAbsent(p.id, () => PageController());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingNew = false;
        _newArrivalsError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadMoreNewArrivals() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final products = await _productService.getProducts(
        page: nextPage,
        limit: _limit,
      );

      if (!mounted) return;

      setState(() {
        _newArrivals.addAll(products);
        _page = nextPage;
        _hasMore = products.length >= _limit;
        _isLoadingMore = false;
      });

      for (final p in products) {
        _newArrivalsPageControllers.putIfAbsent(p.id, () => PageController());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _stopOutfitCarousel();
    _outfitPageController.dispose();
    _scrollController.dispose();

    // Dispose all product page controllers
    for (var controller in _trendingPageControllers.values) {
      controller.dispose();
    }
    for (var controller in _newArrivalsPageControllers.values) {
      controller.dispose();
    }
    for (var controller in _recentlyViewedPageControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double outfitHeight = (size.height * 0.55).clamp(480.0, 600.0);
    final int gridCrossAxisCount = (size.width / 180).floor().clamp(2, 4);

    return Scaffold(
      appBar: AestheticAppBar(
        title: 'MEGG',
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.bell, size: 20),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
          splashRadius: 20,
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _isLoadingOutfits && _dailyOutfits.isEmpty
                ? OutfitCarouselSkeleton(height: outfitHeight)
                : _shouldShowDailyOutfits()
                    ? _buildDailyOutfitSection(context, height: outfitHeight)
                    : const SizedBox.shrink(),
          ),
          if (_shouldShowDailyOutfits() || (_isLoadingOutfits && _dailyOutfits.isEmpty))
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          
          SliverToBoxAdapter(child: _buildCategorySection(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          
          // Recently Viewed Section
          if (_shouldShowRecentlyViewed()) ...[
            SliverToBoxAdapter(
              child: _buildRecentlyViewedSection(context),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
          
          // Trending Products Section with skeleton
          SliverToBoxAdapter(
            child: _isLoadingTrending && _trendingProducts.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SectionHeaderSkeleton(),
                      SizedBox(height: 16),
                      ProductScrollSkeleton(),
                    ],
                  )
                : _shouldShowTrending()
                    ? _buildFeaturedProducts(context)
                    : const SizedBox.shrink(),
          ),
          if (_shouldShowTrending() || (_isLoadingTrending && _trendingProducts.isEmpty))
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          
          // New Arrivals Section with skeleton
          if (_isLoadingNew && _newArrivals.isEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeaderSkeleton()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(
                child: ProductGridSkeleton(
                  crossAxisCount: gridCrossAxisCount,
                  itemCount: 4,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ] else if (_shouldShowNewArrivals()) ...[
            SliverToBoxAdapter(child: _buildNewArrivalsHeader(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCrossAxisCount,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = _newArrivals[index];
                  return ProductCard(
                    product: product,
                    isListView: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProductScreen(product: product),
                        ),
                      ).then((_) => _loadRecentlyViewed());
                    },
                    isWishlisted: _homeWishlist.contains(product.id),
                    pageController:
                        _newArrivalsPageControllers[product.id],
                    onWishlistToggle: _handleWishlistToggle,
                  );
                }, childCount: _newArrivals.length),
              ),
            ),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  bool _shouldShowDailyOutfits() {
    return !_isLoadingOutfits &&
        _dailyOutfitsError == null &&
        _dailyOutfits.isNotEmpty;
  }

  bool _shouldShowTrending() {
    return !_isLoadingTrending &&
        _trendingError == null &&
        _trendingProducts.isNotEmpty;
  }

  bool _shouldShowNewArrivals() {
    return !_isLoadingNew &&
        _newArrivalsError == null &&
        _newArrivals.isNotEmpty;
  }

  bool _shouldShowRecentlyViewed() {
    return _recentlyViewedProducts.isNotEmpty;
  }

  Widget _buildDailyOutfitSection(
    BuildContext context, {
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Builder(
        builder: (context) {
          return Stack(
            children: [
              PageView.builder(
                controller: _outfitPageController,
                onPageChanged: (index) {
                  if (_currentOutfitPage == index) return;
                  setState(() => _currentOutfitPage = index);
                },
                itemCount: _dailyOutfits.length,
                itemBuilder: (context, index) {
                  final outfit = _dailyOutfits[index];
                  final imageUrl = (outfit['banner_image'] as String?) ?? '';
                  final title = (outfit['title'] as String? ?? 'Outfit');
                  final productIds = (outfit['product_ids'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ?? [];

                  return GestureDetector(
                    onTap: () => _openOutfitProducts(
                      title: title,
                      productIds: productIds,
                      bannerImage: imageUrl,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isNotEmpty)
                          LazyImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          )
                        else
                          Container(color: Colors.grey[100]),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 40,
                          child: Text(
                            title.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 3,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_dailyOutfits.length > 1)
                Positioned(
                  left: 24,
                  bottom: 16,
                  child: Row(
                    children: List.generate(_dailyOutfits.length, (i) {
                      final active = i == _currentOutfitPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        height: 2,
                        width: active ? 24 : 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(active ? 1.0 : 0.4),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openOutfitProducts({
    required String title,
    required List<String> productIds,
    String? bannerImage,
  }) {
    if (productIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NO PRODUCTS IN THIS OUTFIT'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutfitProductsScreen(
          outfitTitle: title,
          productIds: productIds,
        ),
      ),
    );
  }

  Future<void> _openAffiliateLink(String? link) async {
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NO LINK AVAILABLE'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Ensure link has proper scheme
      String finalLink = link;
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        finalLink = 'https://$link';
      }

      final uri = Uri.parse(finalLink);

      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw 'Failed to launch URL';
        }
      } else {
        throw 'Cannot launch URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UNABLE TO OPEN LINK: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildCategorySection(BuildContext context) {
    final colorGroups = [
      {
        'name': 'FORMAL',
        'label': 'F',
        'group': 'formal',
        'icon': PhosphorIconsRegular.briefcase,
      },
      {
        'name': 'CASUAL',
        'label': 'C',
        'group': 'casual',
        'icon': PhosphorIconsRegular.tShirt,
      },
      {
        'name': 'WINTER',
        'label': 'W',
        'group': 'winter',
        'icon': PhosphorIconsRegular.snowflake,
      },
      {
        'name': 'LAYERING',
        'label': 'L',
        'group': 'layering',
        'icon': PhosphorIconsRegular.coatHanger,
      },
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SHOP BY COLOR COMBO',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colorGroups.map((group) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ColorComboListScreen(
                            groupType: group['group'] as String,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              group['icon'] as IconData,
                              size: 28,
                              color: Colors.black.withOpacity(0.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          group['name'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedSection(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double itemWidth = (size.width * 0.45).clamp(160.0, 220.0);
    final double height = itemWidth * 1.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'RECENTLY VIEWED',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              if (_recentlyViewedProducts.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchResultsScreen(
                          initialQuery: 'Recently Viewed',
                          initialProducts: _recentlyViewedProducts,
                          hideControls: true,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentlyViewedProducts.length,
            itemBuilder: (context, index) {
              final product = _recentlyViewedProducts[index];
              return SizedBox(
                width: itemWidth,
                height: height,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: ProductCard(
                    product: product,
                    isListView: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductScreen(product: product),
                        ),
                      ).then((_) {
                        // Refresh recently viewed when returning
                        _loadRecentlyViewed();
                      });
                    },
                    isWishlisted: _homeWishlist.contains(product.id),
                    pageController: _recentlyViewedPageControllers[product.id],
                    onWishlistToggle: _handleWishlistToggle,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedProducts(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double itemWidth = (size.width * 0.45).clamp(160.0, 220.0);
    final double height = itemWidth * 1.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'TRENDING NOW',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              if (_trendingProducts.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchResultsScreen(
                          initialQuery: 'Trending',
                          initialProducts: _trendingProducts,
                          hideControls: true,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trendingProducts.length,
            itemBuilder: (context, index) {
              final product = _trendingProducts[index];
              return SizedBox(
                width: itemWidth,
                height: height,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: ProductCard(
                    product: product,
                    isListView: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductScreen(product: product),
                        ),
                      ).then((_) => _loadRecentlyViewed());
                    },
                    isWishlisted: _homeWishlist.contains(product.id),
                    pageController: _trendingPageControllers[product.id],
                    onWishlistToggle: _handleWishlistToggle,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewArrivalsHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        'NEW ARRIVALS',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.5,
        ),
      ),
    );
  }

}
