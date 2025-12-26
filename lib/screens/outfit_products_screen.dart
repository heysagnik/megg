import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/loader.dart';
import 'product_screen.dart';

class OutfitProductsScreen extends StatefulWidget {
  final String outfitTitle;
  final List<String> productIds;

  const OutfitProductsScreen({
    super.key,
    required this.outfitTitle,
    required this.productIds,
  });

  @override
  State<OutfitProductsScreen> createState() => _OutfitProductsScreenState();
}

class _OutfitProductsScreenState extends State<OutfitProductsScreen> {
  final ProductService _productService = ProductService();
  final WishlistService _wishlistService = WishlistService();

  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _wishlist = {};
  final Map<String, PageController> _pageControllers = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadWishlist();
  }

  @override
  void dispose() {
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await _productService.getProductsByIds(widget.productIds);

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });

      for (final p in products) {
        _pageControllers.putIfAbsent(p.id, () => PageController());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadWishlist() async {
    try {
      final wishlistIds = await _wishlistService.getWishlistIds();
      if (!mounted) return;
      setState(() {
        _wishlist.clear();
        _wishlist.addAll(wishlistIds);
      });
    } catch (_) {}
  }

  Future<void> _handleWishlistToggle(String productId) async {
    final wasInWishlist = _wishlist.contains(productId);

    setState(() {
      if (wasInWishlist) {
        _wishlist.remove(productId);
      } else {
        _wishlist.add(productId);
      }
    });

    try {
      if (wasInWishlist) {
        await _wishlistService.removeFromWishlist(productId);
      } else {
        await _wishlistService.addToWishlist(productId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasInWishlist) {
            _wishlist.add(productId);
          } else {
            _wishlist.remove(productId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: widget.outfitTitle.toUpperCase(),
        showBackButton: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: Loader(showCaption: true));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_products.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductsGrid();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 36, color: Colors.red[400]),
            const SizedBox(height: 12),
            const Text(
              'Unable to load products',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: _loadProducts,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 1),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'TRY AGAIN',
                    style: TextStyle(letterSpacing: 1.5, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.tShirt, size: 36, color: Colors.grey[500]),
            const SizedBox(height: 12),
            const Text(
              'No products in this outfit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This outfit doesn\'t have any products yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    final size = MediaQuery.of(context).size;
    final int crossAxisCount = (size.width / 180).floor().clamp(2, 4);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
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
                isWishlisted: _wishlist.contains(product.id),
                pageController: _pageControllers[product.id],
                onWishlistToggle: _handleWishlistToggle,
              );
            },
          ),
        ],
      ),
    );
  }
}
