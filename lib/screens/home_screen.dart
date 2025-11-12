import 'package:flutter/material.dart';
import 'package:megg/screens/search_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../models/product.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/loader.dart';
import '../services/trending_service.dart';
import '../services/product_service.dart';
import '../services/outfit_service.dart';
import '../services/wishlist_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'product_screen.dart';
import 'search_results_screen.dart';
import 'color_combo_list_screen.dart';

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

  List<Product> _trendingProducts = [];
  List<Product> _newArrivals = [];
  List<Map<String, dynamic>> _dailyOutfits = [];

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
  final Set<String> _homeWishlist = {};

  @override
  void initState() {
    super.initState();
    _outfitPageController = PageController(initialPage: _currentOutfitPage);
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    await Future.wait([
      _loadDailyOutfits(),
      _loadTrendingProducts(),
      _loadNewArrivals(),
      _loadWishlist(),
    ]);
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

  Future<void> _loadDailyOutfits() async {
    try {
      setState(() {
        _isLoadingOutfits = true;
        _dailyOutfitsError = null;
      });

      final outfits = await _outfitService.getDailyOutfits();

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
        _dailyOutfits = [];
        _currentOutfitPage = 0;
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

  Future<void> _loadTrendingProducts() async {
    try {
      setState(() {
        _isLoadingTrending = true;
        _trendingError = null;
      });

      final products = await _trendingService.getTrendingProducts(limit: 10);

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

  Future<void> _loadNewArrivals() async {
    try {
      setState(() {
        _isLoadingNew = true;
        _newArrivalsError = null;
      });

      final products = await _productService.getProducts(limit: 6);

      if (!mounted) return;

      setState(() {
        _newArrivals = products;
        _isLoadingNew = false;
      });

      // Initialize page controllers for swipeable images
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

  @override
  void dispose() {
    _stopOutfitCarousel();
    _outfitPageController.dispose();

    // Dispose all product page controllers
    for (var controller in _trendingPageControllers.values) {
      controller.dispose();
    }
    for (var controller in _newArrivalsPageControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: 'MEGG',
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDailyOutfitSection(context),
            const SizedBox(height: 32),
            _buildCategorySection(context),
            const SizedBox(height: 32),
            _buildFeaturedProducts(context),
            const SizedBox(height: 32),
            _buildNewArrivals(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyOutfitSection(BuildContext context) {
    return SizedBox(
      height: 550,
      child: Builder(
        builder: (context) {
          if (_isLoadingOutfits) {
            return const Center(child: Loader());
          }

          if (_dailyOutfitsError != null) {
            return Container(
              color: Colors.grey[100],
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UNABLE TO LOAD',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadDailyOutfits,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            );
          }

          if (_dailyOutfits.isEmpty) {
            return Container(
              color: Colors.grey[100],
              alignment: Alignment.center,
              child: Text(
                'NO DAILY OUTFITS AVAILABLE',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 2,
                ),
              ),
            );
          }

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
                  final title = (outfit['title'] as String? ?? 'Outfit')
                      .toUpperCase();
                  final affiliateLink = outfit['affiliate_link'] as String?;

                  return GestureDetector(
                    onTap: () => _openAffiliateLink(affiliateLink),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isNotEmpty)
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(color: Colors.grey[100]);
                            },
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
                            title,
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
      print('Attempting to open outfit link: $link');

      // Ensure link has proper scheme
      String finalLink = link;
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        finalLink = 'https://$link';
      }

      final uri = Uri.parse(finalLink);
      print('Parsed URI: $uri');

      final canLaunch = await canLaunchUrl(uri);
      print('Can launch URL: $canLaunch');

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('Launch result: $launched');

        if (!launched) {
          throw 'Failed to launch URL';
        }
      } else {
        throw 'Cannot launch URL';
      }
    } catch (e) {
      print('Error opening outfit link: $e');
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
        'name': 'SUMMER',
        'label': 'S',
        'group': 'summer',
        'icon': PhosphorIconsRegular.sun,
      },
    ];

    return Padding(
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
    );
  }

  Widget _buildFeaturedProducts(BuildContext context) {
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
        if (_isLoadingTrending)
          const SizedBox(height: 320, child: Center(child: Loader()))
        else if (_trendingError != null)
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UNABLE TO LOAD',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadTrendingProducts,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
          )
        else if (_trendingProducts.isEmpty)
          SizedBox(
            height: 320,
            child: Center(
              child: Text(
                'NO TRENDING PRODUCTS',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 2,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 320,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trendingProducts.length,
              itemBuilder: (context, index) {
                final product = _trendingProducts[index];
                return SizedBox(
                  width: 200,
                  height: 320,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: ProductCard(
                      product: product,
                      isListView: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductScreen(product: product),
                          ),
                        );
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

  Widget _buildNewArrivals(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'NEW ARRIVALS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              if (_newArrivals.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchResultsScreen(
                          initialQuery: 'New Arrivals',
                          initialProducts: _newArrivals,
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
        if (_isLoadingNew)
          const SizedBox(height: 300, child: Center(child: Loader()))
        else if (_newArrivalsError != null)
          SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UNABLE TO LOAD',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadNewArrivals,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
          )
        else if (_newArrivals.isEmpty)
          SizedBox(
            height: 300,
            child: Center(
              child: Text(
                'NO NEW ARRIVALS',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 2,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: _newArrivals.length,
              itemBuilder: (context, index) {
                final product = _newArrivals[index];
                return ProductCard(
                  product: product,
                  isListView: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductScreen(product: product),
                      ),
                    );
                  },
                  isWishlisted: _homeWishlist.contains(product.id),
                  pageController: _newArrivalsPageControllers[product.id],
                  onWishlistToggle: _handleWishlistToggle,
                );
              },
            ),
          ),
      ],
    );
  }

  // _buildProductCard removed (trending uses ProductCard from product_widget.dart)
}
