import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/custom_icons.dart';
import '../widgets/filter_sort_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/loader.dart';

class OutfitCreatorScreen extends StatefulWidget {
  final Product baseProduct;

  const OutfitCreatorScreen({super.key, required this.baseProduct});

  @override
  State<OutfitCreatorScreen> createState() => _OutfitCreatorScreenState();
}

class _OutfitCreatorScreenState extends State<OutfitCreatorScreen> {
  final ProductService _productService = ProductService();
  final WishlistService _wishlistService = WishlistService();

  List<Product> _recommendations = [];
  List<Product> _filteredRecommendations = [];
  Product? _selectedProduct;
  bool _isExpanded = false;
  final Map<String, PageController> _pageControllers = {};
  final Set<String> _wishlist = {};

  String _sortBy = 'Best Match';
  bool _isGridView = true;
  String _colorFilter = 'All Colors';
  bool _isLoadingRecommendations = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      final wishlistIds = await _wishlistService.getWishlistIds();
      if (!mounted) return;
      setState(() {
        _wishlist.clear();
        _wishlist.addAll(wishlistIds);
      });
    } catch (e) {
      // Silently fail
    }
  }

  @override
  void dispose() {
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final complementaryCategory = _OutfitHelper.getComplementaryCategory(
      widget.baseProduct.category,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingRecommendations = true;
      _loadError = null;
    });

    try {
      final categoryParam = complementaryCategory == 'all'
          ? null
          : complementaryCategory;
      final searchParam = complementaryCategory == 'all'
          ? widget.baseProduct.category
          : null;

      final results = await _productService.getProducts(
        category: categoryParam,
        search: searchParam,
        limit: 40,
      );

      if (!mounted) return;

      final filtered = results
          .where((product) => product.id != widget.baseProduct.id)
          .toList();

      setState(() {
        _recommendations = filtered;
        _isLoadingRecommendations = false;
        _loadError = null;
      });

      _applyFiltersAndSort();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingRecommendations = false;
        _loadError = e.toString();
        _recommendations = [];
        _filteredRecommendations = [];
      });
    }
  }

  void _applyFiltersAndSort() {
    var filtered = List<Product>.from(_recommendations);

    // Apply color filter
    if (_colorFilter != 'All Colors') {
      filtered = filtered.where((p) {
        return p.colors.any(
          (color) => color.toLowerCase().contains(_colorFilter.toLowerCase()),
        );
      }).toList();
    }

    // Apply color matching intelligence
    filtered = _OutfitHelper.sortByColorCompatibility(
      filtered,
      widget.baseProduct,
    );

    // Apply sort
    switch (_sortBy) {
      case 'Best Match':
        // Already sorted by color compatibility
        break;
      case 'Price: Low to High':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Newest':
        // Keep current order
        break;
    }

    setState(() => _filteredRecommendations = filtered);
  }

  Widget _buildRecommendationBody() {
    if (_isLoadingRecommendations) {
      return Center(child: Loader());
    }

    if (_loadError != null) {
      return _buildRecommendationError();
    }

    if (_filteredRecommendations.isEmpty) {
      return _buildRecommendationEmptyState();
    }

    if (_isGridView) {
      return _ProductGrid(
        products: _filteredRecommendations,
        selectedProductId: _selectedProduct?.id,
        onProductTap: _onProductTap,
        onProductDoubleTap: (product) => _handleWishlistToggle(product.id),
        wishlistIds: _wishlist,
        getPageController: _getPageController,
        baseProduct: widget.baseProduct,
        onWishlistToggle: _handleWishlistToggle,
      );
    }

    return _ProductList(
      products: _filteredRecommendations,
      selectedProductId: _selectedProduct?.id,
      onProductTap: _onProductTap,
      onProductDoubleTap: (product) => _handleWishlistToggle(product.id),
      wishlistIds: _wishlist,
      getPageController: _getPageController,
      baseProduct: widget.baseProduct,
      onWishlistToggle: _handleWishlistToggle,
    );
  }

  Widget _buildRecommendationError() {
    final details = _loadError ?? 'Unable to fetch recommendations.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 36, color: Colors.red[400]),
            const SizedBox(height: 12),
            const Text(
              'We couldn\'t load outfit ideas.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              details,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () => _loadRecommendations(),
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
                    'RETRY',
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

  Widget _buildRecommendationEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style, size: 36, color: Colors.grey[500]),
            const SizedBox(height: 12),
            const Text(
              'No matches yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting the color filter or picking a different base item.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  PageController _getPageController(String productId) {
    if (!_pageControllers.containsKey(productId)) {
      _pageControllers[productId] = PageController();
    }
    return _pageControllers[productId]!;
  }

  void _onProductTap(Product product) {
    setState(() {
      _selectedProduct = product;
      _isExpanded = true;
    });

    // Haptic feedback for better UX
    // HapticFeedback.mediumImpact();
  }

  void _onRemoveSelection(Product product) {
    setState(() {
      if (_selectedProduct?.id == product.id) {
        _selectedProduct = null;
      }
    });
  }

  Future<void> _handleWishlistToggle(String productId) async {
    final wasInWishlist = _wishlist.contains(productId);

    // Optimistically update UI
    setState(() {
      if (wasInWishlist) {
        _wishlist.remove(productId);
      } else {
        _wishlist.add(productId);
      }
    });

    // Persist to backend
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

  void _showPreviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OutfitPreviewModal(
        baseProduct: widget.baseProduct,
        selectedProduct: _selectedProduct!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(title: 'CREATE OUTFIT', showBackButton: true),
      body: Stack(
        children: [
          Column(
            children: [
              _ColorMatchBanner(
                baseProduct: widget.baseProduct,
                categoryName: _OutfitHelper.getCategoryDisplayName(
                  widget.baseProduct.category,
                ),
              ),
              FilterSortBar(
                sortBy: _sortBy,
                resultCount: _filteredRecommendations.length,
                isGridView: _isGridView,
                onSortTap: _showSortBottomSheet,
                onFilterTap: _showFilterBottomSheet,
                onViewToggle: () => setState(() => _isGridView = !_isGridView),
              ),
              Expanded(child: _buildRecommendationBody()),
              SizedBox(height: _selectedProduct != null ? 280 : 200),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomOutfitBar(
              baseProduct: widget.baseProduct,
              selectedProduct: _selectedProduct,
              isExpanded: _isExpanded,
              onToggleExpand: () {
                setState(() => _isExpanded = !_isExpanded);
              },
              onRemove: _onRemoveSelection,
              onPreview: _showPreviewModal,
            ),
          ),
        ],
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SORT BY',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              _buildSortOption('Best Match'),
              _buildSortOption('Price: Low to High'),
              _buildSortOption('Price: High to Low'),
              _buildSortOption('Newest'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String option) {
    return ListTile(
      title: Text(
        option.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: _sortBy == option ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      trailing: _sortBy == option ? const Icon(Icons.check, size: 20) : null,
      onTap: () {
        setState(() {
          _sortBy = option;
          _applyFiltersAndSort();
        });
        Navigator.pop(context);
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COLOR HARMONY',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filter by color to find perfect matches',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildColorChip('All Colors'),
                    _buildColorChip('Black'),
                    _buildColorChip('White'),
                    _buildColorChip('Blue'),
                    _buildColorChip('Beige'),
                    _buildColorChip('Grey'),
                    _buildColorChip('Brown'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _applyFiltersAndSort();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'APPLY FILTERS',
                      style: TextStyle(
                        letterSpacing: 1.5,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorChip(String color) {
    final isSelected = _colorFilter == color;
    return ChoiceChip(
      label: Text(
        color.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.5,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _colorFilter = color);
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(
        color: isSelected ? Colors.black : Colors.grey[300]!,
        width: 1,
      ),
    );
  }
}

// ============================================================================
// HELPER CLASS
// ============================================================================

class _OutfitHelper {
  static String getComplementaryCategory(String category) {
    final cat = category.toLowerCase();

    if (cat.contains('shirt') ||
        cat.contains('top') ||
        cat.contains('blaz') ||
        cat.contains('knit')) {
      return 'denim';
    } else if (cat.contains('denim') ||
        cat.contains('jean') ||
        cat.contains('pant')) {
      return 'shirt';
    }
    return 'all';
  }

  static String getCategoryDisplayName(String category) {
    final cat = category.toLowerCase();

    if (cat.contains('shirt') ||
        cat.contains('top') ||
        cat.contains('blaz') ||
        cat.contains('knit')) {
      return 'BOTTOMS';
    }
    return 'TOPS';
  }

  // Color compatibility algorithm for smart matching
  static List<Product> sortByColorCompatibility(
    List<Product> products,
    Product baseProduct,
  ) {
    final baseColors = baseProduct.colors.map((c) => c.toLowerCase()).toList();

    // Color harmony rules (simplified)
    final Map<String, List<String>> colorHarmony = {
      'black': ['white', 'grey', 'beige', 'blue', 'red'],
      'white': ['black', 'blue', 'beige', 'grey', 'navy'],
      'blue': ['white', 'beige', 'grey', 'black', 'brown'],
      'beige': ['white', 'brown', 'black', 'blue', 'olive'],
      'grey': ['white', 'black', 'blue', 'navy', 'pink'],
      'brown': ['beige', 'white', 'cream', 'olive', 'tan'],
      'navy': ['white', 'beige', 'grey', 'tan', 'brown'],
    };

    products.sort((a, b) {
      int scoreA = _calculateCompatibilityScore(a, baseColors, colorHarmony);
      int scoreB = _calculateCompatibilityScore(b, baseColors, colorHarmony);
      return scoreB.compareTo(scoreA); // Higher score first
    });

    return products;
  }

  static int _calculateCompatibilityScore(
    Product product,
    List<String> baseColors,
    Map<String, List<String>> colorHarmony,
  ) {
    int score = 0;
    final productColors = product.colors.map((c) => c.toLowerCase()).toList();

    for (var baseColor in baseColors) {
      for (var productColor in productColors) {
        // Exact complementary match
        if (colorHarmony[baseColor]?.contains(productColor) ?? false) {
          score += 10;
        }
        // Neutral colors (always work)
        if (['white', 'black', 'grey', 'beige'].contains(productColor)) {
          score += 5;
        }
        // Same color family
        if (baseColor == productColor) {
          score += 3;
        }
      }
    }

    return score;
  }

  static int getCompatibilityScore(Product product, Product baseProduct) {
    final baseColors = baseProduct.colors.map((c) => c.toLowerCase()).toList();
    final Map<String, List<String>> colorHarmony = {
      'black': ['white', 'grey', 'beige', 'blue', 'red'],
      'white': ['black', 'blue', 'beige', 'grey', 'navy'],
      'blue': ['white', 'beige', 'grey', 'black', 'brown'],
      'beige': ['white', 'brown', 'black', 'blue', 'olive'],
      'grey': ['white', 'black', 'blue', 'navy', 'pink'],
      'brown': ['beige', 'white', 'cream', 'olive', 'tan'],
      'navy': ['white', 'beige', 'grey', 'tan', 'brown'],
    };

    return _calculateCompatibilityScore(product, baseColors, colorHarmony);
  }
}

// ============================================================================
// COLOR MATCH BANNER WIDGET
// ============================================================================

class _ColorMatchBanner extends StatelessWidget {
  final Product baseProduct;
  final String categoryName;

  const _ColorMatchBanner({
    required this.baseProduct,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Color Matching',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Finding perfect $categoryName for ',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              ...baseProduct.colors.take(3).map((color) {
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    color.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRODUCT GRID WIDGET
// ============================================================================

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final String? selectedProductId;
  final Function(Product) onProductTap;
  final Function(Product)? onProductDoubleTap;
  final Set<String> wishlistIds;
  final PageController Function(String) getPageController;
  final Product baseProduct;
  final void Function(String) onWishlistToggle;

  const _ProductGrid({
    required this.products,
    required this.selectedProductId,
    required this.onProductTap,
    this.onProductDoubleTap,
    required this.wishlistIds,
    required this.getPageController,
    required this.baseProduct,
    required this.onWishlistToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Build compatibility scores map
    final compatibilityScores = <String, int>{};
    for (var product in products) {
      compatibilityScores[product.id] = _OutfitHelper.getCompatibilityScore(
        product,
        baseProduct,
      );
    }

    // Build page controllers map
    final pageControllers = <String, PageController>{};
    for (var product in products) {
      pageControllers[product.id] = getPageController(product.id);
    }

    return ProductGrid(
      products: products,
      isListView: false,
      onProductTap: onProductTap,
      onProductDoubleTap: onProductDoubleTap,
      wishlistIds: wishlistIds,
      selectedProductIds: selectedProductId != null ? {selectedProductId!} : {},
      compatibilityScores: compatibilityScores,
      pageControllers: pageControllers,
      showCompatibilityBadge: true,
      onWishlistToggle: onWishlistToggle,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 24,
    );
  }
}

// ============================================================================
// PRODUCT LIST WIDGET
// ============================================================================

class _ProductList extends StatelessWidget {
  final List<Product> products;
  final String? selectedProductId;
  final Function(Product) onProductTap;
  final Function(Product)? onProductDoubleTap;
  final Set<String> wishlistIds;
  final PageController Function(String) getPageController;
  final Product baseProduct;
  final void Function(String) onWishlistToggle;

  const _ProductList({
    required this.products,
    required this.selectedProductId,
    required this.onProductTap,
    this.onProductDoubleTap,
    required this.wishlistIds,
    required this.getPageController,
    required this.baseProduct,
    required this.onWishlistToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Build compatibility scores map
    final compatibilityScores = <String, int>{};
    for (var product in products) {
      compatibilityScores[product.id] = _OutfitHelper.getCompatibilityScore(
        product,
        baseProduct,
      );
    }

    // Build page controllers map
    final pageControllers = <String, PageController>{};
    for (var product in products) {
      pageControllers[product.id] = getPageController(product.id);
    }

    return ProductGrid(
      products: products,
      isListView: true,
      onProductTap: onProductTap,
      onProductDoubleTap: onProductDoubleTap,
      wishlistIds: wishlistIds,
      selectedProductIds: selectedProductId != null ? {selectedProductId!} : {},
      compatibilityScores: compatibilityScores,
      pageControllers: pageControllers,
      showCompatibilityBadge: true,
      onWishlistToggle: onWishlistToggle,
      padding: const EdgeInsets.all(16),
    );
  }
}

class _BottomOutfitBar extends StatelessWidget {
  final Product baseProduct;
  final Product? selectedProduct;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(Product) onRemove;
  final VoidCallback onPreview;

  const _BottomOutfitBar({
    required this.baseProduct,
    required this.selectedProduct,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedProduct != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: isExpanded ? 360 : (hasSelection ? 260 : 180),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _DragHandle(onTap: onToggleExpand),
          Expanded(
            child: isExpanded
                ? _ExpandedView(
                    baseProduct: baseProduct,
                    selectedProduct: selectedProduct,
                    onRemove: onRemove,
                    onPreview: onPreview,
                  )
                : _CollapsedView(
                    baseProduct: baseProduct,
                    selectedProduct: selectedProduct,
                    onRemove: onRemove,
                    onPreview: onPreview,
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DRAG HANDLE WIDGET
// ============================================================================

class _DragHandle extends StatelessWidget {
  final VoidCallback onTap;

  const _DragHandle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COLLAPSED VIEW WIDGET
// ============================================================================

class _CollapsedView extends StatelessWidget {
  final Product baseProduct;
  final Product? selectedProduct;
  final void Function(Product) onRemove;
  final VoidCallback onPreview;

  const _CollapsedView({
    required this.baseProduct,
    required this.selectedProduct,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedProduct != null;
    final imageHeight = hasSelection ? 120.0 : 80.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Title with subtle instruction
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR OUTFIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: Colors.black87,
                ),
              ),
              if (hasSelection)
                Text(
                  'TAP TO EXPAND',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Two product spaces side by side
          Row(
            children: [
              Expanded(
                child: _OutfitProductSlot(
                  product: baseProduct,
                  label: 'BASE',
                  showRemove: false,
                  onRemove: () {},
                  imageHeight: imageHeight,
                  showDetails: hasSelection,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.add,
                  size: hasSelection ? 24 : 20,
                  color: Colors.grey[400],
                ),
              ),
              Expanded(
                child: selectedProduct != null
                    ? _OutfitProductSlot(
                        product: selectedProduct!,
                        label: 'PAIRING',
                        showRemove: true,
                        onRemove: () => onRemove(selectedProduct!),
                        imageHeight: imageHeight,
                        showDetails: hasSelection,
                      )
                    : _EmptyProductSlot(imageHeight: imageHeight),
              ),
            ],
          ),
          if (hasSelection) ...[
            const SizedBox(height: 16),
            // Action button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text(
                  'PREVIEW OUTFIT',
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// EXPANDED VIEW WIDGET
// ============================================================================

class _ExpandedView extends StatelessWidget {
  final Product baseProduct;
  final Product? selectedProduct;
  final void Function(Product) onRemove;
  final VoidCallback onPreview;

  const _ExpandedView({
    required this.baseProduct,
    required this.selectedProduct,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR OUTFIT DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'TAP TO COLLAPSE',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProductDetail(
                  product: baseProduct,
                  label: 'BASE ITEM',
                  showRemove: false,
                  onRemove: () {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 65),
                    Icon(Icons.add, size: 20, color: Colors.grey[600]),
                  ],
                ),
              ),
              Expanded(
                child: selectedProduct != null
                    ? _ProductDetail(
                        product: selectedProduct!,
                        label: 'PAIRING',
                        showRemove: true,
                        onRemove: () => onRemove(selectedProduct!),
                      )
                    : Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Text(
                            'SELECT\nAN ITEM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: selectedProduct != null ? onPreview : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text(
                'PREVIEW OUTFIT',
                style: TextStyle(
                  letterSpacing: 1.5,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// OUTFIT PRODUCT SLOT WIDGET (for collapsed view)
// ============================================================================

class _OutfitProductSlot extends StatelessWidget {
  final Product product;
  final String label;
  final bool showRemove;
  final VoidCallback onRemove;
  final double imageHeight;
  final bool showDetails;

  const _OutfitProductSlot({
    required this.product,
    required this.label,
    required this.showRemove,
    required this.onRemove,
    required this.imageHeight,
    required this.showDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: imageHeight,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(
                  color: showRemove ? Colors.black : Colors.grey[300]!,
                  width: showRemove ? 2 : 1,
                ),
                image: DecorationImage(
                  image: NetworkImage(product.images[0]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (showRemove)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (showDetails) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// EMPTY PRODUCT SLOT WIDGET
// ============================================================================

class _EmptyProductSlot extends StatelessWidget {
  final double imageHeight;

  const _EmptyProductSlot({required this.imageHeight});

  @override
  Widget build(BuildContext context) {
    final iconSize = imageHeight > 100 ? 32.0 : 24.0;
    final fontSize = imageHeight > 100 ? 10.0 : 9.0;

    return Container(
      height: imageHeight,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: iconSize,
              color: Colors.grey[400],
            ),
            SizedBox(height: imageHeight > 100 ? 8 : 4),
            Text(
              'SELECT\nAN ITEM',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey[500],
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRODUCT DETAIL WIDGET (for expanded view)
// ============================================================================

class _ProductDetail extends StatelessWidget {
  final Product product;
  final String label;
  final bool showRemove;
  final VoidCallback onRemove;

  const _ProductDetail({
    required this.product,
    required this.label,
    required this.showRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(
                  color: showRemove ? Colors.black : Colors.grey[300]!,
                  width: showRemove ? 2 : 1,
                ),
                image: DecorationImage(
                  image: NetworkImage(product.images[0]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (showRemove)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// OUTFIT PREVIEW MODAL
// ============================================================================

class _OutfitPreviewModal extends StatelessWidget {
  final Product baseProduct;
  final Product selectedProduct;

  const _OutfitPreviewModal({
    required this.baseProduct,
    required this.selectedProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'OUTFIT PREVIEW',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Model Image Placeholder
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Model Preview',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${baseProduct.name}\n+\n${selectedProduct.name}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Outfit saved to closet'),
                            backgroundColor: Colors.black,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: CustomIcons.heart(
                        size: 20,
                        color: Colors.white,
                        filled: true,
                      ),
                      label: const Text(
                        'SAVE TO CLOSET',
                        style: TextStyle(
                          letterSpacing: 1.5,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
