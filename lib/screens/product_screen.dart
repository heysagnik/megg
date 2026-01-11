import 'package:flutter/material.dart';
import 'package:megg/screens/search_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../services/cache_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/lazy_image.dart';
import '../services/auth_service.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/product_widget.dart';

class ProductScreen extends StatefulWidget {
  final Product product;

  const ProductScreen({super.key, required this.product});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  late PageController _pageController;
  Timer? _autoSlideTimer;
  final WishlistService _wishlistService = WishlistService();

  List<Product> _productRecommendations = [];
  bool _isLoadingData = false;
  final Map<String, PageController> _recommendationPageControllers = {};

  // Color variants
  List<Product> _colorVariants = [];
  
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product; 
    _pageController = PageController();
    _checkWishlistStatus();
    _loadProductData();
    _saveToRecentlyViewed();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    if (widget.product.images.length <= 1) return;

    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;

      final nextIndex = (_currentImageIndex + 1) % widget.product.images.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  Future<void> _saveToRecentlyViewed() async {
    try {
      await CacheService().addRecentlyViewedProduct(widget.product.toJson());
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final isInWishlist = await _wishlistService.isInWishlist(
        widget.product.id,
      );
      if (mounted) setState(() => _isFavorite = isInWishlist);
    } catch (_) {}
  }

  Future<void> _toggleWishlist() async {
    if (!AuthService().isAuthenticated) {
      showDialog(
        context: context,
        builder: (context) => const LoginRequiredDialog(),
      );
      return;
    }

    final wasFavorite = _isFavorite;
    setState(() => _isFavorite = !wasFavorite);

    try {
      if (wasFavorite) {
        await _wishlistService.removeFromWishlist(widget.product.id);
      } else {
        await _wishlistService.addToWishlist(widget.product.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasFavorite ? 'Removed from Wishlist' : 'Added to Wishlist',
              style: const TextStyle(letterSpacing: 0.5),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = wasFavorite);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasFavorite
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

  /// Load product data (recommendations and variants) from unified API
  Future<void> _loadProductData() async {
    setState(() => _isLoadingData = true);
    try {
      debugPrint('[ProductScreen] Loading data for product: ${widget.product.id}');
      final result = await ProductService().getProductDetails(widget.product.id);
      
      debugPrint('[ProductScreen] API result keys: ${result.keys}');
      debugPrint('[ProductScreen] Recommended type: ${result['recommended'].runtimeType}');
      debugPrint('[ProductScreen] Variants type: ${result['variants'].runtimeType}');
      
      if (mounted) {
        final fetchedProduct = result['product'] as Product?;
        final recommendations = result['recommended'] as List<Product>? ?? [];
        final variants = result['variants'] as List<Product>? ?? [];
        
        debugPrint('[ProductScreen] Recommendations count: ${recommendations.length}');
        debugPrint('[ProductScreen] Variants count: ${variants.length}');
        debugPrint('[ProductScreen] Fetched product description: ${fetchedProduct?.description}');
        debugPrint('[ProductScreen] Fetched product fabric: ${fetchedProduct?.fabric}');
        
        setState(() {
          if (fetchedProduct != null) {
            _currentProduct = fetchedProduct;
          }
          _productRecommendations = recommendations;
          _colorVariants = variants;
          _isLoadingData = false;
        });
        
        for (final p in recommendations) {
          _recommendationPageControllers.putIfAbsent(
            p.id,
            () => PageController(),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ProductScreen] Error loading data: $e');
      debugPrint('[ProductScreen] Stack trace: $stackTrace');
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    for (var controller in _recommendationPageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AestheticAppBar(
        title: '',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
            color: Colors.black,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            ),
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(
              _isFavorite
                  ? PhosphorIconsFill.heart
                  : PhosphorIconsRegular.heart,
              size: 20,
            ),
            color: _isFavorite ? Colors.red : Colors.black,
            onPressed: _toggleWishlist,
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.shareNetwork, size: 20),
            color: Colors.black,
            onPressed: () async {
              final text =
                  'Check out ${widget.product.name} on MEGG!\n${widget.product.affiliateLink}';
              final url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
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
            _buildProductImages(),
            const SizedBox(height: 32),
            _buildProductHeader(),
            const SizedBox(height: 24),
            _buildColorDisplay(),
            const SizedBox(height: 40),
            _buildProductDetails(),
            const SizedBox(height: 32),
            _buildDescription(),
            const SizedBox(height: 40),
            _buildProductRecommendations(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProductImages() {
    final double imageHeight = (MediaQuery.of(context).size.height * 0.6).clamp(
      0.0,
      450.0,
    );

    return GestureDetector(
      onPanDown: (_) => _stopAutoSlide(),
      onPanEnd: (_) => _startAutoSlide(),
      child: SizedBox(
        height: imageHeight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.product.images.length,
              onPageChanged: (index) =>
                  setState(() => _currentImageIndex = index),
              itemBuilder: (context, index) {
                return Container(
                  color: const Color(0xFFF8F8F8),
                  child: LazyImage(
                    imageUrl: widget.product.images[index],
                    fit: BoxFit.cover,
                    errorWidget: Center(
                      child: Icon(
                        PhosphorIconsRegular.image,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.product.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.product.images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      height: 2,
                      width: _currentImageIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          _currentImageIndex == index ? 1.0 : 0.4,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.brand.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rs ${widget.product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prices may vary',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorDisplay() {
    if (_colorVariants.isEmpty && !_isLoadingData) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: Colors.black.withOpacity(0.08)),
          const SizedBox(height: 24),
          if (_colorVariants.isNotEmpty)
            _buildColorVariants()
          else if (_isLoadingData)
            SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.black.withOpacity(0.08)),
        ],
      ),
    );
  }

  Widget _buildColorVariants() {
    final List<Product> allColors = [
      widget.product,
      ..._colorVariants.where((v) => v.id != widget.product.id),
    ];
    
    final totalColorsCount = allColors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with color count
        Row(
          children: [
            Text(
              'COLOR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: Colors.grey[600],
              ),
            ),
            if (totalColorsCount > 1) ...[
              const SizedBox(width: 12),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$totalColorsCount colors',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Color variant thumbnails
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final variant = allColors[index];
              final isSelected = variant.id == widget.product.id;
              final thumbnailUrl = variant.images.isNotEmpty
                  ? variant.images.first
                  : null;

              return GestureDetector(
                onTap: isSelected
                    ? null
                    : () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                        
                        try {
                          final result = await ProductService().getProductDetails(variant.id);
                          final fullProduct = result['product'] as Product?;
                          
                          if (!mounted) return;
                          Navigator.pop(context);
                          
                          if (fullProduct != null) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    ProductScreen(product: fullProduct),
                                transitionDuration: const Duration(
                                  milliseconds: 200,
                                ),
                                transitionsBuilder: (_, animation, __, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to load product'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      // Thumbnail - larger size
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.grey.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: thumbnailUrl != null
                            ? LazyImage(
                                imageUrl: thumbnailUrl,
                                fit: BoxFit.cover,
                                errorWidget: _buildColorFallback(variant.color),
                              )
                            : _buildColorFallback(variant.color),
                      ),
                      const SizedBox(height: 8),
                      // Color name label
                      Text(
                        variant.color,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected ? Colors.black : Colors.grey[600],
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorFallback(String color) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Text(
          color.isNotEmpty ? color[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    debugPrint('[ProductScreen] Building details - fabric: ${_currentProduct.fabric}, desc: ${_currentProduct.description?.substring(0, (_currentProduct.description?.length ?? 0).clamp(0, 30))}');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(color: Colors.grey[50]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRODUCT DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Category', _currentProduct.category),
          if (_currentProduct.subcategory != null &&
              _currentProduct.subcategory!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Subcategory', _currentProduct.subcategory!),
          ],
          const SizedBox(height: 12),
          _buildDetailRow('Color', _currentProduct.color),
          if (_currentProduct.fabric.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Fabric', _currentProduct.fabric.join(', ')),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final description = _currentProduct.description;
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.grey[800],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRecommendations() {
    if (_isLoadingData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
        ),
      );
    }

    if (_productRecommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'YOU MAY ALSO LIKE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 24,
            ),
            itemCount: _productRecommendations.length,
            itemBuilder: (context, index) {
              final product = _productRecommendations[index];
              return ProductCard(
                product: product,
                isListView: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductScreen(product: product),
                  ),
                ),
                pageController: _recommendationPageControllers[product.id],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () async {
              final affiliateLink = _currentProduct.affiliateLink;
              if (affiliateLink == null || affiliateLink.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'No purchase link available',
                        style: TextStyle(letterSpacing: 0.5),
                      ),
                      backgroundColor: Colors.black,
                      behavior: SnackBarBehavior.floating,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  );
                }
                return;
              }
              
              await ProductService().recordProductClick(widget.product.id);
              final url = Uri.parse(affiliateLink);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Could not open link',
                        style: TextStyle(letterSpacing: 0.5),
                      ),
                      backgroundColor: Colors.black,
                      behavior: SnackBarBehavior.floating,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  );
                }
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/myntra.png',
                  height: 24,
                  width: 24,
                  color: Colors.white,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    PhosphorIconsBold.shoppingBag,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'BUY NOW',
                  style: TextStyle(
                    letterSpacing: 2.0,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
