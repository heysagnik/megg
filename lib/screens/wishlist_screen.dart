import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/product.dart';
import '../services/wishlist_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/product_widget.dart';
import 'product_screen.dart';

class WishlistScreen extends StatefulWidget {
  final List<Product> initialWishlist;

  const WishlistScreen({super.key, required this.initialWishlist});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();
  late List<Product> _wishlist;
  final Set<String> _wishlistIds = {};
  final Map<String, PageController> _pageControllers = {};

  @override
  void initState() {
    super.initState();
    _wishlist = List.from(widget.initialWishlist);
    _wishlistIds.addAll(_wishlist.map((p) => p.id));
    _initializePageControllers();
  }

  void _initializePageControllers() {
    for (final product in _wishlist) {
      if (product.images.length > 1) {
        _pageControllers.putIfAbsent(product.id, () => PageController());
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleWishlistToggle(String productId) async {
    final wasInWishlist = _wishlistIds.contains(productId);

    // Optimistically update UI
    setState(() {
      if (wasInWishlist) {
        _wishlistIds.remove(productId);
        _wishlist.removeWhere((p) => p.id == productId);
      }
    });

    try {
      if (wasInWishlist) {
        await _wishlistService.removeFromWishlist(productId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('REMOVED FROM WISHLIST'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.black,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (wasInWishlist) {
            _wishlistIds.add(productId);
            // Need to refresh to get back the product
            _refreshWishlist();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove from wishlist'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _refreshWishlist() async {
    try {
      final updated = await _wishlistService.getWishlist(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _wishlist = updated;
        _wishlistIds
          ..clear()
          ..addAll(_wishlist.map((p) => p.id));
        _initializePageControllers();
      });
    } catch (e) {
      // Keep showing current UI on errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: 'WISHLIST',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_wishlist.length} ITEMS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _wishlist.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshWishlist,
              color: Colors.black,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: _wishlist.length,
                itemBuilder: (context, index) {
                  final product = _wishlist[index];
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
                    isWishlisted: _wishlistIds.contains(product.id),
                    pageController: _pageControllers[product.id],
                    onWishlistToggle: _handleWishlistToggle,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsRegular.heart, size: 64, color: Colors.grey[350]),
          const SizedBox(height: 24),
          const Text(
            'NO ITEMS IN WISHLIST',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start exploring and add items',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              letterSpacing: 0.3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'GO BACK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
