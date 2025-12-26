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
  bool _isLoadingProductRecommendations = false;
  final Map<String, PageController> _recommendationPageControllers = {};

  // Color variants
  List<Product> _colorVariants = [];
  bool _isLoadingVariants = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkWishlistStatus();
    _loadProductRecommendations();
    _loadColorVariants();
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
      debugPrint('[Product] Saving ${widget.product.id} to recently viewed');
      await CacheService().addRecentlyViewedProduct(widget.product.toJson());
      debugPrint('[Product] Saved successfully');
    } catch (e) {
      debugPrint('[Product] Error saving to recently viewed: $e');
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

  Future<void> _loadProductRecommendations() async {
    setState(() => _isLoadingProductRecommendations = true);
    try {
      final products = await ProductService().getProductRecommendations(
        widget.product.id,
      );
      if (mounted) {
        setState(() {
          _productRecommendations = products;
          _isLoadingProductRecommendations = false;
        });
        for (final p in products) {
          _recommendationPageControllers.putIfAbsent(
            p.id,
            () => PageController(),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProductRecommendations = false);
    }
  }

  Future<void> _loadColorVariants() async {
    setState(() => _isLoadingVariants = true);
    try {
      final variants = await ProductService().getProductVariants(
        widget.product.id,
      );
      if (mounted) {
        setState(() {
          _colorVariants = variants;
          _isLoadingVariants = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVariants = false);
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
                  child: Image.network(
                    widget.product.images[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 1.2,
                          color: Colors.black,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
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
        ],
      ),
    );
  }

  Widget _buildColorDisplay() {
    if (widget.product.color.isEmpty && _colorVariants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: Colors.black.withOpacity(0.08)),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.color,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_colorVariants.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildColorVariants(),
                    ] else if (_isLoadingVariants) ...[
                      const SizedBox(height: 16),
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
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.black.withOpacity(0.08)),
        ],
      ),
    );
  }

  Widget _buildColorVariants() {
    // Count of other colors available
    final otherColorsCount = _colorVariants.length ;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show available colors count
        if (otherColorsCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$otherColorsCount more ${otherColorsCount == 1 ? 'color' : 'colors'} available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
          ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _colorVariants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final variant = _colorVariants[index];
              final isSelected = variant.id == widget.product.id;
              final thumbnailUrl = variant.images.isNotEmpty
                  ? variant.images.first
                  : null;

              return GestureDetector(
                onTap: isSelected
                    ? null
                    : () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                ProductScreen(product: variant),
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
                      },
                child: SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      // Thumbnail
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.black.withOpacity(0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Thumbnail image
                            if (thumbnailUrl != null)
                              Positioned.fill(
                                child: Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[100],
                                    child: Center(
                                      child: Text(
                                        variant.color.isNotEmpty
                                            ? variant.color[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: Text(
                                    variant.color.isNotEmpty
                                        ? variant.color[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            // Selected indicator overlay
                            if (isSelected)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 3,
                                  color: Colors.black,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Color name label
                      Text(
                        variant.color,
                        style: TextStyle(
                          fontSize: 9,
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

  Widget _buildProductDetails() {
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
          _buildDetailRow('Category', widget.product.category),
          if (widget.product.subcategory != null &&
              widget.product.subcategory!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Subcategory', widget.product.subcategory!),
          ],
          const SizedBox(height: 12),
          _buildDetailRow('Color', widget.product.color),
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
    final description = widget.product.description;
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
    if (_isLoadingProductRecommendations) {
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
              final affiliateLink = widget.product.affiliateLink;
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
