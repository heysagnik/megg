import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../config/api_config.dart';
import '../models/product.dart';
import '../services/search_service.dart';
import '../services/search_history_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/filter_sort_bar.dart';
import '../widgets/product_widget.dart';
import '../widgets/custom_refresh_indicator.dart';
import 'product_screen.dart';
import 'search_screen.dart';
import '../widgets/loader.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  final List<Product>? initialProducts;
  final bool hideControls;

  const SearchResultsScreen({
    super.key,
    this.initialQuery = '',
    this.initialProducts,
    this.hideControls = false,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen>
    with TickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final SearchHistoryService _historyService = SearchHistoryService();
  final WishlistService _wishlistService = WishlistService();

  List<Product> _searchResults = [];
  String _sortBy = 'Popularity';
  bool _isGridView = true;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _pageSize = ApiConfig.defaultPageSize;
  int? _totalResults;
  bool _hasMore = false;
  String _currentQuery = '';
  int _requestSerial = 0;

  // Filter state - tracks user's explicit selections
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedColor;

  // Auto-detected filters from API response
  String? _detectedCategory;
  String? _detectedSubcategory;
  String? _detectedColor;

  // Track if subcategory was detected from original query (not user selection)
  bool _subcategoryFromQuery = false;

  // UI state
  List<String> _availableSubcategories = [];
  List<String> _availableColors = []; // Auto-scroll controller for first item
  final Map<String, PageController> _pageControllers = {};
  final Map<String, Timer> _autoScrollTimers = {};

  final Set<String> _wishlist = {};
  final Map<String, AnimationController> _likeAnimations = {};
  final Map<String, Animation<double>> _scaleAnimations = {};
  final Map<String, Animation<double>> _fadeAnimations = {};

  @override
  void dispose() {
    for (var controller in _pageControllers.values) {
      controller.dispose(); // Dispose of page controllers
    }
    for (var timer in _autoScrollTimers.values) {
      timer.cancel(); // Cancel auto-scroll timers
    }
    for (var controller in _likeAnimations.values) {
      controller.dispose(); // Dispose of like animations
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.initialQuery.trim();

    if (_currentQuery.isNotEmpty) {
      _historyService.addSearchQuery(_currentQuery);
    }

    if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      _searchResults = List<Product>.from(widget.initialProducts!);
      _totalResults = _searchResults.length;
      _hasMore = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncControllersWithResults();
        }
      });
    } else if (_currentQuery.isNotEmpty) {
      _performSearch(_currentQuery);
    }

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
    } catch (_) {}
  }

  Future<void> _performSearch(String query, {int page = 1}) async {
    final trimmedQuery = query.trim();
    final isLoadMore = page > 1;

    // Allow empty query if we have explicit filters (category, subcategory, or color)
    final hasExplicitFilters =
        _selectedCategory != null ||
        _selectedSubcategory != null ||
        _selectedColor != null;

    if (trimmedQuery.isEmpty && !hasExplicitFilters) {
      if (!mounted) return;
      setState(() {
        _currentQuery = '';
        _searchResults = [];
        _currentPage = 1;
        _pageSize = ApiConfig.defaultPageSize;
        _totalResults = 0;
        _hasMore = false;
        _errorMessage = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _syncControllersWithResults();
      });
      return;
    }

    if (isLoadMore) {
      if (_isLoadingMore || !_hasMore) return;
    } else {
      if (_isInitialLoading) return;
    }

    final requestToken = ++_requestSerial;

    if (mounted) {
      setState(() {
        _currentQuery = trimmedQuery;
        _errorMessage = null;
        if (isLoadMore) {
          _isLoadingMore = true;
        } else {
          _isInitialLoading = true;
          _searchResults = [];
          _currentPage = 1;
          _totalResults = null;
          _hasMore = false;
          _syncControllersWithResults();
        }
      });
    }

    try {
      final SearchResultPage response;

      response = await _searchService.search(
        query: trimmedQuery.isNotEmpty ? trimmedQuery : null,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        color: _selectedColor,
        sort: _mapSortOptionToParam(_sortBy),
        page: page,
        limit: _pageSize,
      );

      if (!mounted || requestToken != _requestSerial) return;

      final bool shouldUpdateFilters = !isLoadMore;
      
      setState(() {
        final resolvedPage = response.page > 0 ? response.page : page;
        _currentPage = resolvedPage;
        _pageSize = response.limit;
        _hasMore = response.hasMore;

        if (isLoadMore) {
          _searchResults.addAll(response.products);
          _totalResults = response.totalResults ?? _searchResults.length;
        } else {
          _searchResults = List<Product>.from(response.products);
          _totalResults = response.totalResults ?? _searchResults.length;
        }

        _syncControllersWithResults();
      });
      
      if (shouldUpdateFilters) {
        _updateFiltersFromResponse(response);
      }
    } catch (e) {
      if (!mounted || requestToken != _requestSerial) return;

      setState(() {
        if (!isLoadMore) {
          _searchResults = [];
          _totalResults = 0;
          _syncControllersWithResults();
        }
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted || requestToken != _requestSerial) return;

      setState(() {
        if (isLoadMore) {
          _isLoadingMore = false;
        } else {
          _isInitialLoading = false;
        }
      });
    }
  }

  Future<void> _updateFiltersFromResponse(SearchResultPage response) async {
    final filters = response.appliedFilters;

    if (filters != null) {
      _detectedCategory = filters['appliedCategory'] as String?;
      _detectedColor = filters['appliedColor'] as String?;
      
    final apiSubcategory = filters['appliedSubcategory'] as String?;
      if (_selectedSubcategory == null && apiSubcategory != null) {
        _detectedSubcategory = apiSubcategory;
        _subcategoryFromQuery = true;  // Subcategory was in original query
      } else if (_selectedSubcategory != null) {
        // User selected a subcategory - keep showing the filter bar
        _subcategoryFromQuery = false;
      }

      // Fetch subcategories from API based on detected/selected category
      final categoryToFetch = _selectedCategory ?? _detectedCategory;
      if (categoryToFetch != null) {
        await _fetchSubcategoriesForCategory(categoryToFetch);
      } else {
        _availableSubcategories = [];
      }
    } else {
      // Fallback: detect from results if no filters in response
      await _extractFiltersFromResults();
    }

    // Extract available colors from results
    final colors = <String>{};
    for (final product in _searchResults) {
      if (product.color.isNotEmpty) {
        colors.add(product.color);
      }
    }
    _availableColors = colors.toList()..sort();
  }

  /// Fetch subcategories for a category from API
  Future<void> _fetchSubcategoriesForCategory(String category) async {
    final subcategories = await _searchService.getSubcategories(category);
    if (mounted) {
      setState(() {
        _availableSubcategories = subcategories;
      });
    }
  }

  /// Fallback method to extract filters from results when API doesn't provide them
  Future<void> _extractFiltersFromResults() async {
    if (_searchResults.isEmpty) {
      _availableSubcategories = [];
      _availableColors = [];
      return;
    }

    // Detect the primary category from results
    final categories = _searchResults
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet();

    String? categoryToFetch;
    if (categories.length == 1) {
      final category = categories.first;
      _detectedCategory = category;
      categoryToFetch = category;
    } else if (categories.isNotEmpty) {
      final categoryCount = <String, int>{};
      for (final product in _searchResults) {
        categoryCount[product.category] =
            (categoryCount[product.category] ?? 0) + 1;
      }

      final mostCommonCategory = categoryCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      _detectedCategory = mostCommonCategory;
      categoryToFetch = mostCommonCategory;
    }

    if (categoryToFetch != null) {
      await _fetchSubcategoriesForCategory(categoryToFetch);
    } else {
      _availableSubcategories = [];
    }

    final colors = <String>{};
    for (final product in _searchResults) {
      if (product.color.isNotEmpty) {
        colors.add(product.color);
      }
    }

    _availableColors = colors.toList()..sort();
  }

  void _syncControllersWithResults() {
    final currentIds = _searchResults.map((product) => product.id).toSet();

    final stalePageControllers = _pageControllers.entries
        .where((entry) => !currentIds.contains(entry.key))
        .toList();
    for (final entry in stalePageControllers) {
      entry.value.dispose();
      _pageControllers.remove(entry.key);
    }

    final staleTimers = _autoScrollTimers.entries
        .where((entry) => !currentIds.contains(entry.key))
        .toList();
    for (final entry in staleTimers) {
      entry.value.cancel();
      _autoScrollTimers.remove(entry.key);
    }

    final staleAnimations = _likeAnimations.entries
        .where((entry) => !currentIds.contains(entry.key))
        .toList();
    for (final entry in staleAnimations) {
      entry.value.dispose();
      _likeAnimations.remove(entry.key);
      _scaleAnimations.remove(entry.key);
      _fadeAnimations.remove(entry.key);
    }
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

  @override
  Widget build(BuildContext context) {
    final title = (_currentQuery.isEmpty)
        ? 'SEARCH'
        : _currentQuery.toUpperCase();

    int activeFilterCount = 0;
    if (_selectedSubcategory != null) activeFilterCount++;
    if (_selectedColor != null) activeFilterCount++;

    return PopScope(
      canPop: _selectedSubcategory == null && _selectedColor == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // Clear filters step by step before allowing back navigation
        if (_selectedSubcategory != null || _selectedColor != null) {
          setState(() {
            if (_selectedSubcategory != null) {
              _selectedSubcategory = null;
              _selectedCategory = null;
            } else if (_selectedColor != null) {
              _selectedColor = null;
            }
          });
          _performSearch(_currentQuery, page: 1);
        }
      },
      child: Scaffold(
      appBar: AestheticAppBar(
        title: title,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(initialQuery: _currentQuery),
                ),
              );
            },
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (!widget.hideControls &&
              _detectedCategory != null &&
              _selectedCategory == null)
            _buildDetectedFiltersInfo(),
          // Show subcategory filter if:
          // 1. We have subcategories to show
          // 2. AND (subcategory was not detected from query OR user is actively browsing)
          if (!widget.hideControls && 
              _availableSubcategories.isNotEmpty &&
              !_subcategoryFromQuery)
            SubcategoryFilterBar(
              subcategories: _availableSubcategories,
              selectedSubcategory: _selectedSubcategory,
              onSubcategorySelected: (subcategory) {
                setState(() {
                  _selectedSubcategory = subcategory;
                  if (subcategory != null && _detectedCategory != null) {
                    _selectedCategory = _detectedCategory;
                  } else {
                    _selectedCategory = null;
                  }
                });
                _performSearch(_currentQuery, page: 1);
              },
            ),
          Expanded(child: _buildResultsBody()),
        ],
      ),
      bottomNavigationBar: widget.hideControls
          ? null
          : FilterSortBar(
              sortBy: _sortBy,
              resultCount: _totalResults ?? _searchResults.length,
              isGridView: _isGridView,
              onSortTap: _showSortBottomSheet,
              onFilterTap: _showFilterBottomSheet,
              onViewToggle: () => setState(() => _isGridView = !_isGridView),
              isSticky: true,
              activeFilterCount: activeFilterCount,
            ),
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_isInitialLoading) {
      return Center(child: Loader());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState();
    }

    // Disable pull-to-refresh when hideControls is true (View All pages)
    // or when we have initialProducts (pre-populated lists that can't be refreshed via search)
    final bool disableRefresh =
        widget.hideControls || widget.initialProducts != null;

    final scrollableContent = NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: _isGridView ? _buildGridView() : _buildListView(),
    );

    return Stack(
      children: [
        if (disableRefresh)
          scrollableContent
        else
          CustomRefreshIndicator(
            onRefresh: () => _performSearch(_currentQuery, page: 1),
            color: Colors.black,
            child: scrollableContent,
          ),
        if (_isLoadingMore)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(child: Loader(size: 28)),
          ),
      ],
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final hasExplicitFilters = _selectedCategory != null || 
        _selectedSubcategory != null || 
        _selectedColor != null;
    
    if ((_currentQuery.isEmpty && !hasExplicitFilters) ||
        !_hasMore ||
        _isLoadingMore ||
        _isInitialLoading) {
      return false;
    }

    if (notification.metrics.maxScrollExtent <= 0) {
      return false;
    }

    const threshold = 120.0;
    final reachBottom =
        notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - threshold;

    if (reachBottom &&
        (notification is ScrollEndNotification ||
            notification is OverscrollNotification ||
            notification is ScrollUpdateNotification)) {
      _performSearch(_currentQuery, page: _currentPage + 1);
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
              'We couldn\'t load these results.',
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
                onPressed: () => _performSearch(_currentQuery, page: 1),
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
    final headline = _currentQuery.isEmpty
        ? 'Search the collection'
        : 'No results for "$_currentQuery"';
    final subtitle = _currentQuery.isEmpty
        ? 'Try searching for styles, colors, or product names.'
        : 'Try a different keyword or adjust your filters.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 36, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              headline,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView() {
    // Initialize controllers for all products
    for (var i = 0; i < _searchResults.length; i++) {
      final product = _searchResults[i];
      _initializeProductControllers(product, isFirst: i == 0);
    }

    return ProductGrid(
      products: _searchResults,
      isListView: false,
      onProductTap: (product) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductScreen(product: product),
          ),
        );
      },
      // Note: onProductDoubleTap is not needed since ProductCard._handleDoubleTap
      // already calls onWishlistToggle internally
      wishlistIds: _wishlist,
      pageControllers: _pageControllers,
      onWishlistToggle: _handleDoubleTap,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 24,
    );
  }

  Widget _buildListView() {
    for (var i = 0; i < _searchResults.length; i++) {
      final product = _searchResults[i];
      _initializeProductControllers(product, isFirst: i == 0);
    }

    return ProductGrid(
      products: _searchResults,
      isListView: true,
      onProductTap: (product) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductScreen(product: product),
          ),
        );
      },
      // Note: onProductDoubleTap is not needed since ProductCard._handleDoubleTap
      // already calls onWishlistToggle internally
      wishlistIds: _wishlist,
      pageControllers: _pageControllers,
      onWishlistToggle: _handleDoubleTap,
      padding: const EdgeInsets.all(16),
    );
  }

  void _initializeProductControllers(Product product, {bool isFirst = false}) {
    if (!_pageControllers.containsKey(product.id)) {
      _pageControllers[product.id] = PageController();

      if (isFirst && product.images.length > 1) {
        _setupAutoScroll(product.id, product.images.length);
      }
    }

    if (!_likeAnimations.containsKey(product.id)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _likeAnimations[product.id] = controller;

      _scaleAnimations[product.id] = Tween<double>(begin: 0.0, end: 1.0)
          .animate(
            CurvedAnimation(
              parent: controller,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
          );

      _fadeAnimations[product.id] = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
        ),
      );
    }
  }

  Future<void> _handleDoubleTap(String productId) async {
    final wasInWishlist = _wishlist.contains(productId);

    // Optimistically update UI
    setState(() {
      if (wasInWishlist) {
        _wishlist.remove(productId);
      } else {
        _wishlist.add(productId);
      }
    });

    // Trigger animation
    _likeAnimations[productId]?.forward(from: 0.0);

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

  void _setupAutoScroll(String productId, int imageCount) {
    _autoScrollTimers[productId]?.cancel();

    // Scroll once from 0 to 1 and back to 0, then stop
    int scrollCount = 0;
    _autoScrollTimers[productId] = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) {
      if (!mounted || !_pageControllers.containsKey(productId)) {
        timer.cancel();
        return;
      }

      final controller = _pageControllers[productId]!;
      if (!controller.hasClients) return;

      final currentPage = controller.page?.round() ?? 0;

      if (scrollCount >= 2) {
        timer.cancel();
        return;
      }

      final nextPage = currentPage == 0 ? 1 : 0;
      scrollCount++;

      controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
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
        if (shouldRefresh && _currentQuery.isNotEmpty) {
          _performSearch(_currentQuery, page: 1);
        }
      },
    );
  }

  void _showFilterBottomSheet() {
    // Create a stateful widget for the filter sheet to track local state
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) {
        String? tempSubcategory = _selectedSubcategory;
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
                                tempSubcategory = null;
                                tempColor = null;
                              });
                              setState(() {
                                _selectedSubcategory = null;
                                _selectedColor = null;
                                _selectedCategory = null;
                              });
                              Navigator.pop(context);
                              _performSearch(_currentQuery, page: 1);
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
                      // Only show subcategory filter if API didn't already apply one
                      if (_availableSubcategories.isNotEmpty && _detectedSubcategory == null) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'SUBCATEGORY',
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
                          children: _availableSubcategories
                              .map(
                                (subcategory) => _buildFilterChip(
                                  subcategory,
                                  tempSubcategory,
                                  (s) =>
                                      setModalState(() => tempSubcategory = s),
                                ),
                              )
                              .toList(),
                        ),
                      ],
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
                                _buildColorChip('Grey', tempColor, (c) {
                                  setModalState(() => tempColor = c);
                                }),
                                _buildColorChip('Blue', tempColor, (c) {
                                  setModalState(() => tempColor = c);
                                }),
                                _buildColorChip('Brown', tempColor, (c) {
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
                              _selectedSubcategory = tempSubcategory;
                              _selectedColor = tempColor;

                              // Use detected category when applying subcategory filter
                              if (tempSubcategory != null && _detectedCategory != null) {
                                _selectedCategory = _detectedCategory;
                              } else if (tempColor != null &&
                                  _detectedCategory != null) {
                                // If only color is selected, keep the detected category
                                _selectedCategory = _detectedCategory;
                              } else {
                                // Clear category if no filters
                                _selectedCategory = null;
                              }
                            });
                            Navigator.pop(context);
                            _performSearch(_currentQuery, page: 1);
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

  Widget _buildFilterChip(
    String label,
    String? selectedValue,
    Function(String?) onSelect,
  ) {
    final isSelected = selectedValue == label;
    return GestureDetector(
      onTap: () => onSelect(isSelected ? null : label),
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
          label.toUpperCase(),
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

  Widget _buildDetectedFiltersInfo() {
    final detectedFilters = <String>[];

    if (_detectedCategory != null) {
      detectedFilters.add(_detectedCategory!);
    }
    if (_detectedSubcategory != null) {
      detectedFilters.add(_detectedSubcategory!);
    }
    if (_detectedColor != null) {
      detectedFilters.add(_detectedColor!);
    }

    if (detectedFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.sparkle, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing: ${detectedFilters.join(' • ')}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
