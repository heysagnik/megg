import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/loader.dart';
import 'product_screen.dart';


class ReelProductsScreen extends StatefulWidget {
  final List<String> productIds;
  final String reelCategory;

  const ReelProductsScreen({
    super.key,
    required this.productIds,
    required this.reelCategory,
  });

  @override
  State<ReelProductsScreen> createState() => _ReelProductsScreenState();
}

class _ReelProductsScreenState extends State<ReelProductsScreen> {
  final ProductService _productService = ProductService();
  final WishlistService _wishlistService = WishlistService();

  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
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
    try {
      final products = await _productService.getProductsByIds(widget.productIds);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });

        for (final p in products) {
          _pageControllers.putIfAbsent(p.id, () => PageController());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: 'SHOP THIS LOOK',
        showBackButton: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: Loader(showCaption: true));
    }

    if (_error != null) {
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.warningCircle, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'UNABLE TO LOAD PRODUCTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!.replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadProducts();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500),
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
            Icon(PhosphorIconsRegular.package, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'NO PRODUCTS FOUND',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Products for this look are no longer available',
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

          // Products grid
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
