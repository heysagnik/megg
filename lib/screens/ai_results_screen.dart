import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/ai_analysis_result.dart';
import '../models/product.dart';
import '../widgets/product_widget.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../services/wishlist_service.dart';
import 'product_screen.dart';

class AIResultsScreen extends StatefulWidget {
  final File uploadedImage;
  final AIAnalysisResult result;

  const AIResultsScreen({
    super.key,
    required this.uploadedImage,
    required this.result,
  });

  @override
  State<AIResultsScreen> createState() => _AIResultsScreenState();
}

class _AIResultsScreenState extends State<AIResultsScreen> {
  String? _selectedCategory;
  String _sortBy = 'popularity';
  Set<String> _wishlistIds = {};

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final ids = await WishlistService().getWishlistIds();
    if (mounted) {
      setState(() => _wishlistIds = ids);
    }
  }

  void _handleWishlistToggle(String productId) {
    setState(() {
      if (_wishlistIds.contains(productId)) {
        _wishlistIds.remove(productId);
      } else {
        _wishlistIds.add(productId);
      }
    });
  }

  List<Product> get _filteredProducts {
    var products = widget.result.products;
    
    // Filter by category
    if (_selectedCategory != null) {
      products = products
          .where((p) => p.category.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }
    
    // Sort
    switch (_sortBy) {
      case 'price_low':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'popularity':
      default:
        products.sort((a, b) => b.popularity.compareTo(a.popularity));
    }
    
    return products;
  }

  Color _getColorFromName(String colorName) {
    final colorMap = {
      'white': Colors.white,
      'black': Colors.black,
      'grey': Colors.grey,
      'ash': const Color(0xFFB2BEB5),
      'charcoal': const Color(0xFF36454F),
      'navy': const Color(0xFF002E68),
      'navy blue': const Color(0xFF002E68),
      'blue': const Color(0xFF4C6F92),
      'light blue': const Color(0xFFAFD2E8),
      'red': const Color(0xFFFF3F41),
      'light red': const Color(0xFFFFCCCB),
      'deep red': const Color(0xFF8B0000),
      'maroon': const Color(0xFF800000),
      'burgundy': const Color(0xFF800020),
      'pink': const Color(0xFFF2A9C4),
      'light pink': const Color(0xFFFFB6C1),
      'orange': const Color(0xFFF28D21),
      'light orange': const Color(0xFFFFCC80),
      'saffron': const Color(0xFFF4C430),
      'yellow': Colors.yellow,
      'soft yellow': const Color(0xFFFFFACD),
      'green': const Color(0xFF4EAE49),
      'mint': const Color(0xFF98FBCB),
      'mint green': const Color(0xFF98FBCB),
      'deep green': const Color(0xFF006400),
      'olive': const Color(0xFF808000),
      'olive green': const Color(0xFF556B2F),
      'purple': Colors.purple,
      'lavender': const Color(0xFFE6E6FA),
      'pale purple': const Color(0xFFD8BFD8),
      'brown': Colors.brown,
      'dark brown': const Color(0xFF5D4037),
      'beige': const Color(0xFFF5F5DC),
      'cream': const Color(0xFFFFFDD0),
      'khaki': const Color(0xFFF0E68C),
    };
    return colorMap[colorName.toLowerCase()] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(
        title: '',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Header: Image + Color Detection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uploaded Image
                Container(
                  width: 100,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  child: Image.file(
                    widget.uploadedImage,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                // Color Detection Box
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DETECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Primary Color
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _getColorFromName(result.primaryColor),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            result.primaryColor.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      // Secondary Color
                      if (result.secondaryColor != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _getColorFromName(result.secondaryColor!),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              result.secondaryColor!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Pattern
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          result.pattern.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Suggested Colors Row
          if (result.matchingColors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUGGESTED ${result.targetCategoryType.toUpperCase()} COLORS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: result.matchingColors.map((color) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _getColorFromName(color),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                color.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8,
                                  letterSpacing: 0.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          // Filter and Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Category Filter
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCategoryFilter(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory?.toUpperCase() ?? 'ALL CATEGORIES',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(
                            PhosphorIconsRegular.caretDown,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort
                GestureDetector(
                  onTap: () => _showSortOptions(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.funnel,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'SORT',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'NO MATCHING PRODUCTS',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        isListView: false,
                        isWishlisted: _wishlistIds.contains(product.id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductScreen(
                                product: product,
                              ),
                            ),
                          );
                        },
                        onWishlistToggle: _handleWishlistToggle,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilter(BuildContext context) {
    final categories = ['All', ...widget.result.targetCategories];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: const Text(
                'FILTER BY CATEGORY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),
            ...categories.map((cat) {
              final isSelected = cat == 'All' 
                  ? _selectedCategory == null 
                  : _selectedCategory == cat;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat == 'All' ? null : cat;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.transparent,
                  ),
                  child: Text(
                    cat.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final options = [
      ('popularity', 'POPULARITY'),
      ('price_low', 'PRICE: LOW TO HIGH'),
      ('price_high', 'PRICE: HIGH TO LOW'),
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: const Text(
                'SORT BY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),
            ...options.map((opt) {
              final isSelected = _sortBy == opt.$1;
              return InkWell(
                onTap: () {
                  setState(() => _sortBy = opt.$1);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.transparent,
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
