import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/product.dart';
import '../services/product_service.dart';

// ============================================================================
// UNIVERSAL PRODUCT GRID
// ============================================================================

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final bool isListView;
  final Function(Product) onProductTap;
  final Function(Product)? onProductDoubleTap;
  final Function(Product)? onProductLongPress;
  final Set<String>? selectedProductIds;
  final Set<String>? wishlistIds;
  final Map<String, int>? compatibilityScores;
  final Map<String, PageController>? pageControllers;
  final bool showCompatibilityBadge;
  final bool showWishlistAnimation;
  final EdgeInsetsGeometry? padding;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final Function(String)? onWishlistToggle;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ProductGrid({
    super.key,
    required this.products,
    this.isListView = false,
    required this.onProductTap,
    this.onProductDoubleTap,
    this.onProductLongPress,
    this.selectedProductIds,
    this.wishlistIds,
    this.compatibilityScores,
    this.pageControllers,
    this.showCompatibilityBadge = false,
    this.showWishlistAnimation = false,
    this.padding,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.onWishlistToggle,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (isListView) {
      return ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding ?? const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            isListView: true,
            onTap: () => onProductTap(product),
            onDoubleTap: onProductDoubleTap != null
                ? () => onProductDoubleTap!(product)
                : null,
            onLongPress: onProductLongPress != null
                ? () => onProductLongPress!(product)
                : null,
            isSelected: selectedProductIds?.contains(product.id) ?? false,
            isWishlisted: wishlistIds?.contains(product.id) ?? false,
            compatibilityScore: compatibilityScores?[product.id],
            pageController: pageControllers?[product.id],
            showCompatibilityBadge: showCompatibilityBadge,
            onWishlistToggle: onWishlistToggle,
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding ?? const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: crossAxisSpacing ?? 16,
        mainAxisSpacing: mainAxisSpacing ?? 20,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          isListView: false,
          onTap: () => onProductTap(product),
          onDoubleTap: onProductDoubleTap != null
              ? () => onProductDoubleTap!(product)
              : null,
          onLongPress: onProductLongPress != null
              ? () => onProductLongPress!(product)
              : null,
          isSelected: selectedProductIds?.contains(product.id) ?? false,
          isWishlisted: wishlistIds?.contains(product.id) ?? false,
          compatibilityScore: compatibilityScores?[product.id],
          pageController: pageControllers?[product.id],
          showCompatibilityBadge: showCompatibilityBadge,
          onWishlistToggle: onWishlistToggle,
        );
      },
    );
  }
}

// ============================================================================
// UNIVERSAL PRODUCT CARD
// ============================================================================

class ProductCard extends StatefulWidget {
  final Product product;
  final bool isListView;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isWishlisted;
  final int? compatibilityScore;
  final PageController? pageController;
  final bool showCompatibilityBadge;
  final Widget? customBadge;
  final Widget? customOverlay;
  final Function(String)? onWishlistToggle;

  const ProductCard({
    super.key,
    required this.product,
    required this.isListView,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.isSelected = false,
    this.isWishlisted = false,
    this.compatibilityScore,
    this.pageController,
    this.showCompatibilityBadge = false,
    this.customBadge,
    this.customOverlay,
    this.onWishlistToggle,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showAnimation = false;
  bool _isHovering = false;
  Timer? _autoScrollTimer;
  int _currentImageIndex = 0;
  // Pulse ring removed per request

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(_animationController);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_animationController);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showAnimation = false;
        });
        _animationController.reset();
      }
    });

    // Pulse ring removed
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animations when item just became wishlisted
    if (!oldWidget.isWishlisted && widget.isWishlisted) {
      setState(() {
        _showAnimation = true;
      });
      if (!_animationController.isAnimating) {
        _animationController.forward(from: 0.0);
      }
    }
  }

  void _startAutoScroll() {
    if (widget.product.images.length <= 1 || widget.pageController == null) {
      return;
    }

    _autoScrollTimer?.cancel();
    _currentImageIndex = widget.pageController!.hasClients
        ? widget.pageController!.page?.round() ?? 0
        : 0;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted || widget.pageController == null) return;
      if (!widget.pageController!.hasClients) return;

      _currentImageIndex =
          (_currentImageIndex + 1) % widget.product.images.length;

      widget.pageController!.animateToPage(
        _currentImageIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _handleDoubleTap() {
    if (widget.onDoubleTap != null) {
      widget.onDoubleTap!();
    }

    if (widget.onWishlistToggle != null) {
      widget.onWishlistToggle!(widget.product.id);
    }

    setState(() {
      _showAnimation = true;
    });
    _animationController.forward();
  }

  void _handleWishlistTap() {
    if (widget.onWishlistToggle != null) {
      widget.onWishlistToggle!(widget.product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isListView
        ? _buildListCard(context)
        : _buildGridCard(context);
  }

  // ============================================================================
  // LIST VIEW LAYOUT
  // ============================================================================

  Widget _buildListCard(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _startAutoScroll();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _stopAutoScroll();
      },
      child: GestureDetector(
        onTap: () {
          // Fire and forget analytics call
          ProductService().getProductDetails(widget.product.id);
          widget.onTap();
        },
        onDoubleTap: _handleDoubleTap,
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            border: widget.isSelected
                ? Border.all(color: Colors.black, width: 2)
                : null,
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  SizedBox(
                    width: 110,
                    height: 145,
                    child: _buildImageCarousel(),
                  ),
                  const SizedBox(width: 16),
                  // Product Details
                  Expanded(
                    child: SizedBox(
                      height: 145,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.brand.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.product.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Rs ${widget.product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.product.color,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: 8,
                right: 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  // Always visible for accessibility; hover still scales icon
                  opacity: 1.0,
                  child: GestureDetector(
                    onTap: _handleWishlistTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isWishlisted
                              ? Colors.red.withOpacity(0.2)
                              : Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulse ring removed
                          // Heart icon with hover scale
                          Center(
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              scale:
                                  (widget.isWishlisted ? 1.05 : 1.0) *
                                  (_isHovering ? 1.05 : 1.0),
                              child: Icon(
                                widget.isWishlisted
                                    ? PhosphorIconsFill.heart
                                    : PhosphorIconsRegular.heart,
                                size: 14,
                                color: widget.isWishlisted
                                    ? Colors.red
                                    : Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Custom Badge
              if (widget.customBadge != null)
                Positioned(top: 8, left: 8, child: widget.customBadge!),
              // Selection Indicator
              if (widget.isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIconsRegular.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              // Double-tap animation overlay - Refined Zara Style
              if (_showAnimation)
                Positioned.fill(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  PhosphorIconsFill.heart,
                                  size: 32,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              // Custom Overlay
              if (widget.customOverlay != null) widget.customOverlay!,
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // GRID VIEW LAYOUT
  // ============================================================================

  Widget _buildGridCard(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _startAutoScroll();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _stopAutoScroll();
      },
      child: GestureDetector(
        onTap: () {
          // Fire and forget analytics call
          ProductService().getProductDetails(widget.product.id);
          widget.onTap();
        },
        onDoubleTap: _handleDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: widget.isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImageCarousel(),
                        // Wishlist Heart (Grid View - Bottom Right) - Minimalist Style
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _handleWishlistTap,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.08),
                                  width: 0.5,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  widget.isWishlisted
                                      ? PhosphorIconsFill.heart
                                      : PhosphorIconsRegular.heart,
                                  size: 14,
                                  color: widget.isWishlisted
                                      ? Colors.red
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Double-tap animation overlay
                        if (_showAnimation)
                          Center(
                            child: AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _fadeAnimation.value,
                                  child: Transform.scale(
                                    scale: _scaleAnimation.value,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          PhosphorIconsFill.heart,
                                          size: 32,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Brand Name
                Text(
                  widget.product.brand.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Product Name
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Product Price
                Text(
                  'Rs ${widget.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            // Custom Badge
            if (widget.customBadge != null)
              Positioned(top: 8, right: 8, child: widget.customBadge!),
            // Selection Indicator (Grid)
            if (widget.isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            // Custom Overlay
            if (widget.customOverlay != null) widget.customOverlay!,
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // IMAGE CAROUSEL
  // ============================================================================

  Widget _buildImageCarousel() {
    if (widget.product.images.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Icon(
            PhosphorIconsRegular.image,
            color: Colors.grey[400],
            size: 40,
          ),
        ),
      );
    }

    if (widget.product.images.length == 1 || widget.pageController == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          image: DecorationImage(
            image: NetworkImage(widget.product.images[0]),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.product.images.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            image: DecorationImage(
              image: NetworkImage(widget.product.images[index]),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  //   // ============================================================================
  //   // COMPATIBILITY BADGE
  //   // ============================================================================

  //   Widget _buildCompatibilityBadge({required bool isCompact}) {
  //     if (compatibilityScore == null) return const SizedBox.shrink();

  //     final matchLabel = compatibilityScore! > 15
  //         ? (isCompact ? 'PERFECT' : 'PERFECT MATCH')
  //         : compatibilityScore! > 10
  //         ? (isCompact ? 'GREAT' : 'GREAT MATCH')
  //         : compatibilityScore! > 5
  //         ? (isCompact ? 'GOOD' : 'GOOD MATCH')
  //         : null;

  //     if (matchLabel == null) return const SizedBox.shrink();

  //     final matchColor = compatibilityScore! > 15
  //         ? Colors.green[600]!
  //         : compatibilityScore! > 10
  //         ? Colors.blue[600]!
  //         : Colors.orange[600]!;

  //     return Container(
  //       padding: EdgeInsets.symmetric(
  //         horizontal: isCompact ? 6 : 8,
  //         vertical: isCompact ? 3 : 4,
  //       ),
  //       decoration: BoxDecoration(
  //         color: matchColor,
  //         borderRadius: BorderRadius.circular(2),
  //       ),
  //       child: Text(
  //         matchLabel,
  //         style: TextStyle(
  //           fontSize: isCompact ? 9 : 10,
  //           color: Colors.white,
  //           fontWeight: FontWeight.w600,
  //           letterSpacing: 0.5,
  //         ),
  //       ),
  //     );
  //   }
  // }

  // // ============================================================================
  // // SLIVER PRODUCT GRID (for CustomScrollView)
  // // ============================================================================

  // class SliverProductGrid extends StatelessWidget {
  //   final List<Product> products;
  //   final bool isListView;
  //   final Function(Product) onProductTap;
  //   final Function(Product)? onProductDoubleTap;
  //   final Function(Product)? onProductLongPress;
  //   final Set<String>? selectedProductIds;
  //   final Set<String>? wishlistIds;
  //   final Map<String, int>? compatibilityScores;
  //   final Map<String, PageController>? pageControllers;
  //   final bool showCompatibilityBadge;
  //   final EdgeInsetsGeometry? padding;
  //   final double? crossAxisSpacing;
  //   final double? mainAxisSpacing;

  //   const SliverProductGrid({
  //     super.key,
  //     required this.products,
  //     this.isListView = false,
  //     required this.onProductTap,
  //     this.onProductDoubleTap,
  //     this.onProductLongPress,
  //     this.selectedProductIds,
  //     this.wishlistIds,
  //     this.compatibilityScores,
  //     this.pageControllers,
  //     this.showCompatibilityBadge = false,
  //     this.padding,
  //     this.crossAxisSpacing,
  //     this.mainAxisSpacing,
  //   });

  //   @override
  //   Widget build(BuildContext context) {
  //     if (isListView) {
  //       return SliverPadding(
  //         padding: padding ?? const EdgeInsets.all(16),
  //         sliver: SliverList(
  //           delegate: SliverChildBuilderDelegate((context, index) {
  //             final product = products[index];
  //             return ProductCard(
  //               product: product,
  //               isListView: true,
  //               onTap: () => onProductTap(product),
  //               onDoubleTap: onProductDoubleTap != null
  //                   ? () => onProductDoubleTap!(product)
  //                   : null,
  //               onLongPress: onProductLongPress != null
  //                   ? () => onProductLongPress!(product)
  //                   : null,
  //               isSelected: selectedProductIds?.contains(product.id) ?? false,
  //               isWishlisted: wishlistIds?.contains(product.id) ?? false,
  //               compatibilityScore: compatibilityScores?[product.id],
  //               pageController: pageControllers?[product.id],
  //               showCompatibilityBadge: showCompatibilityBadge,
  //             );
  //           }, childCount: products.length),
  //         ),
  //       );
  //     }

  //     return SliverPadding(
  //       padding: padding ?? const EdgeInsets.all(16),
  //       sliver: SliverGrid(
  //         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //           crossAxisCount: 2,
  //           childAspectRatio: 0.65,
  //           crossAxisSpacing: crossAxisSpacing ?? 16,
  //           mainAxisSpacing: mainAxisSpacing ?? 20,
  //         ),
  //         delegate: SliverChildBuilderDelegate((context, index) {
  //           final product = products[index];
  //           return ProductCard(
  //             product: product,
  //             isListView: false,
  //             onTap: () => onProductTap(product),
  //             onDoubleTap: onProductDoubleTap != null
  //                 ? () => onProductDoubleTap!(product)
  //                 : null,
  //             onLongPress: onProductLongPress != null
  //                 ? () => onProductLongPress!(product)
  //                 : null,
  //             isSelected: selectedProductIds?.contains(product.id) ?? false,
  //             isWishlisted: wishlistIds?.contains(product.id) ?? false,
  //             compatibilityScore: compatibilityScores?[product.id],
  //             pageController: pageControllers?[product.id],
  //             showCompatibilityBadge: showCompatibilityBadge,
  //           );
  //         }, childCount: products.length),
  //       ),
  //     );
  //   }
}
