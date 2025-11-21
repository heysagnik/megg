import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../services/search_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/filter_sort_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/custom_refresh_indicator.dart';
import 'product_screen.dart';
import 'search_screen.dart';
import '../widgets/loader.dart';

class CategoryBrowseScreen extends StatefulWidget {
  final String category;
  const CategoryBrowseScreen({super.key, required this.category});

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen>
    with TickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final WishlistService _wishlistService = WishlistService();

  List<Product> _products = [];
  List<Map<String, dynamic>> _banners = [];

  String _sortBy = 'Popularity';
  bool _isGridView = true;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _pageSize = ApiConfig.defaultPageSize;
  int? _totalResults;
  bool _hasMore = false;

  // Optional simple filters (color only for now)
  String? _selectedColor;
  List<String> _availableColors = [];

  // UI controllers
  final Map<String, PageController> _pageControllers = {};
  final Set<String> _wishlist = {};

  @override
  void initState() {
    super.initState();
    _fetch(page: 1);
    _loadWishlist();
  }

  @override
  void dispose() {
    for (final c in _pageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWishlist() async {
    try {
      final ids = await _wishlistService.getWishlistIds();
      if (!mounted) return;
      setState(() {
        _wishlist
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {}
  }

  String? _mapSortOptionToParam(String option) {
    switch (option) {
      case 'Popularity':
        return 'popularity';
      case 'Price: Low to High':
        return 'price_asc';
      case 'Price: High to Low':
        return 'price_desc';
      case 'Newest':
        return 'newest';
      case 'Oldest':
        return 'oldest';
      case 'Most Clicked':
        return 'clicks';
      default:
        return 'popularity';
    }
  }

  Future<void> _fetch({required int page}) async {
    final isLoadMore = page > 1;

    if (isLoadMore) {
      if (_isLoadingMore || !_hasMore) return;
    } else if (_isInitialLoading) {
      return;
    }

    if (mounted) {
      setState(() {
        _errorMessage = null;
        if (isLoadMore) {
          _isLoadingMore = true;
        } else {
          _isInitialLoading = true;
          _products = [];
          _banners = [];
          _currentPage = 1;
          _hasMore = false;
          _totalResults = null;
        }
      });
    }

    try {
      final result = await _searchService.browseCategory(
        category: widget.category,
        color: _selectedColor,
        sort: _mapSortOptionToParam(_sortBy),
        page: page,
        limit: _pageSize,
      );

      if (!mounted) return;

      final banners = <Map<String, dynamic>>[];
      final md = result.metadata ?? const <String, dynamic>{};
      final rawBanners = md['banners'];
      if (rawBanners is List) {
        for (final item in rawBanners) {
          if (item is Map<String, dynamic>) banners.add(item);
        }
      }

      // Colors from products
      final colors = <String>{};
      for (final p in result.products) {
        if (p.color.isNotEmpty) colors.add(p.color);
      }

      setState(() {
        _currentPage = result.page;
        _pageSize = result.limit;
        _hasMore = result.hasMore;
        _totalResults = result.totalResults ?? result.products.length;

        if (isLoadMore) {
          _products.addAll(result.products);
        } else {
          _products = List<Product>.from(result.products);
          _banners = banners;
          _availableColors = colors.toList()..sort();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!isLoadMore) {
          _products = [];
          _banners = [];
        }
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        if (isLoadMore) {
          _isLoadingMore = false;
        } else {
          _isInitialLoading = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category.toUpperCase();
    final activeFilterCount = _selectedColor == null ? 0 : 1;

    return Scaffold(
      appBar: AestheticAppBar(
        title: title,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [Expanded(child: _buildBody())]),
      bottomNavigationBar: FilterSortBar(
        sortBy: _sortBy,
        resultCount: _totalResults ?? _products.length,
        isGridView: _isGridView,
        onSortTap: _showSortBottomSheet,
        onFilterTap: _showFilterBottomSheet,
        onViewToggle: () => setState(() => _isGridView = !_isGridView),
        isSticky: true,
        activeFilterCount: activeFilterCount,
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return Center(child: Loader());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return CustomRefreshIndicator(
      onRefresh: () => _fetch(page: 1),
      color: Colors.black,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView(
          children: [
            if (_banners.isNotEmpty) _buildBannerCarousel(),
            if (_products.isEmpty) _buildEmptyState(),
            if (_products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _isGridView ? _buildGridView() : _buildListView(),
              ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Loader(size: 28)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    final double bannerWidth =
        MediaQuery.of(context).size.width -
        32; // full width minus horizontal padding
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _banners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final banner = _banners[i];
          final imageUrl =
              (banner['banner_image'] ?? banner['image'])?.toString() ?? '';
          final link = banner['link']?.toString();
          return GestureDetector(
            onTap: (link != null && link.isNotEmpty)
                ? () async {
                    final uri = Uri.tryParse(link);
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                : null,
            child: Container(
              width: bannerWidth,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withOpacity(0.08),
                  width: 1,
                ),
                color: Colors.white,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            PhosphorIconsRegular.image,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.35),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridView() {
    for (final product in _products) {
      _pageControllers.putIfAbsent(product.id, () => PageController());
    }

    return ProductGrid(
      products: _products,
      isListView: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onProductTap: (product) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductScreen(product: product),
          ),
        );
      },
      onProductDoubleTap: (product) => _handleWishlistToggle(product.id),
      wishlistIds: _wishlist,
      pageControllers: _pageControllers,
      onWishlistToggle: _handleWishlistToggle,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 24,
    );
  }

  Widget _buildListView() {
    for (final product in _products) {
      _pageControllers.putIfAbsent(product.id, () => PageController());
    }

    return ProductGrid(
      products: _products,
      isListView: true,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onProductTap: (product) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductScreen(product: product),
          ),
        );
      },
      onProductDoubleTap: (product) => _handleWishlistToggle(product.id),
      wishlistIds: _wishlist,
      pageControllers: _pageControllers,
      onWishlistToggle: _handleWishlistToggle,
      padding: const EdgeInsets.all(16),
    );
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
    } catch (_) {
      if (!mounted) return;
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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_hasMore || _isLoadingMore || _isInitialLoading) return false;

    if (notification.metrics.maxScrollExtent <= 0) return false;

    const threshold = 120.0;
    final reachBottom =
        notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - threshold;

    if (reachBottom &&
        (notification is ScrollEndNotification ||
            notification is OverscrollNotification ||
            notification is ScrollUpdateNotification)) {
      _fetch(page: _currentPage + 1);
    }

    return false;
  }

  Widget _buildErrorState() {
    final error = _errorMessage ?? 'Unknown error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 36, color: Colors.red[400]),
            const SizedBox(height: 12),
            const Text(
              "We couldn't load this category.",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () => _fetch(page: 1),
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 36, color: Colors.grey[500]),
            const SizedBox(height: 12),
            const Text(
              'No products in this category yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              _buildSortOption('Popularity'),
              _buildSortOption('Newest'),
              _buildSortOption('Price: Low to High'),
              _buildSortOption('Price: High to Low'),
              _buildSortOption('Most Clicked'),
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
        final shouldRefresh = _sortBy != option;
        setState(() => _sortBy = option);
        Navigator.pop(context);
        if (shouldRefresh) _fetch(page: 1);
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
        String? tempColor = _selectedColor;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
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
                            'FILTERS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempColor = null;
                              });
                              setState(() {
                                _selectedColor = null;
                              });
                              Navigator.pop(context);
                              _fetch(page: 1);
                            },
                            child: const Text(
                              'CLEAR ALL',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'COLOR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableColors.isEmpty
                            ? [
                                _buildColorChip('Black', tempColor, (c) {
                                  setModalState(() => tempColor = c);
                                }),
                                _buildColorChip('White', tempColor, (c) {
                                  setModalState(() => tempColor = c);
                                }),
                                _buildColorChip('Beige', tempColor, (c) {
                                  setModalState(() => tempColor = c);
                                }),
                              ]
                            : _availableColors
                                  .map(
                                    (color) => _buildColorChip(
                                      color,
                                      tempColor,
                                      (c) => setModalState(() => tempColor = c),
                                    ),
                                  )
                                  .toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedColor = tempColor;
                            });
                            Navigator.pop(context);
                            _fetch(page: 1);
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
                            style: TextStyle(letterSpacing: 2, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorChip(
    String color,
    String? selectedColor,
    Function(String?) onSelect,
  ) {
    final isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () => onSelect(isSelected ? null : color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          color.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
