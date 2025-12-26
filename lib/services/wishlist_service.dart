import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/product.dart';
import '../config/api_config.dart';
import 'cache_service.dart';
import 'auth_service.dart';

class WishlistService extends ChangeNotifier {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  static const String _kCacheKey = 'wishlist';
  static const String _kTokenKey = 'session_token';
  static const Duration _kCacheExpiry = Duration(minutes: 5);

  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConfig.vercelUrl}/api',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  // In-memory cache
  List<Product> _productsCache = [];
  Set<String> _wishlistIdsCache = {};
  DateTime? _lastFetch;
  bool _isInitialized = false;

  /// Unmodifiable list of wishlist products for UI binding
  List<Product> get products => List.unmodifiable(_productsCache);
  
  /// Unmodifiable set of wishlist product IDs for quick lookups
  Set<String> get productIds => Set.unmodifiable(_wishlistIdsCache);
  
  /// Number of items in wishlist
  int get count => _productsCache.length;

  Future<Options> _authOptions() async {
    final token = await _secureStorage.read(key: _kTokenKey);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Initialize the service by loading from cache
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Load from disk cache first for instant UI
    final cachedData = await _cacheService.getListCache(_kCacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      _productsCache = cachedData.map((json) => Product.fromJson(json)).toList();
      _wishlistIdsCache = _productsCache.map((p) => p.id).toSet();
      notifyListeners();
    }
    
    // Then sync with server in background
    _syncWithServer();
  }

  /// Get wishlist products. Returns cached data immediately, fetches in background if stale.
  Future<List<Product>> getWishlist({bool forceRefresh = false}) async {
    // Return cache immediately if valid
    if (!forceRefresh && _productsCache.isNotEmpty) {
      final isValid = _lastFetch != null && 
          DateTime.now().difference(_lastFetch!) < _kCacheExpiry;
      if (isValid) {
        return products;
      }
    }
    
    // If no local data, try disk cache
    if (_productsCache.isEmpty) {
      final cachedData = await _cacheService.getListCache(_kCacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        _productsCache = cachedData.map((json) => Product.fromJson(json)).toList();
        _wishlistIdsCache = _productsCache.map((p) => p.id).toSet();
        notifyListeners();
      }
    }
    
    // Fetch from server
    if (forceRefresh || _productsCache.isEmpty) {
      await _syncWithServer();
    }
    
    return products;
  }

  /// Sync wishlist with server (background operation)
  Future<void> _syncWithServer() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final response = await _dio.get('/wishlist', options: await _authOptions());
      
      dynamic dataWrapper;
      if (response.data is Map) {
        dataWrapper = response.data['data'] ?? response.data['wishlist'] ?? response.data;
      } else {
        dataWrapper = response.data;
      }

      dynamic productList;
      if (dataWrapper is List) {
        productList = dataWrapper;
      } else if (dataWrapper is Map) {
        productList = dataWrapper['wishlist'] ?? dataWrapper['products'];
      }

      if (productList != null && productList is List) {
        final serverProducts = productList
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();

        // Update cache
        _productsCache = serverProducts;
        _wishlistIdsCache = serverProducts.map((p) => p.id).toSet();
        _lastFetch = DateTime.now();
        
        // Persist to disk
        await _persistToCache();
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Wishlist] Sync error: $e');
      // Keep local cache on error
    }
  }

  /// Get wishlist IDs (fast lookup)
  Future<Set<String>> getWishlistIds({bool forceRefresh = false}) async {
    if (!forceRefresh && _wishlistIdsCache.isNotEmpty) {
      return productIds;
    }
    
    // Load from disk if empty
    if (_wishlistIdsCache.isEmpty) {
      final cachedIds = await _cacheService.getWishlistIds();
      if (cachedIds.isNotEmpty) {
        _wishlistIdsCache = cachedIds;
      }
    }
    
    return productIds;
  }

  /// Check if product is in wishlist (instant, no async)
  bool isInWishlistSync(String productId) {
    return _wishlistIdsCache.contains(productId);
  }

  /// Check if product is in wishlist (async for compatibility)
  Future<bool> isInWishlist(String productId) async {
    if (_wishlistIdsCache.isNotEmpty) {
      return _wishlistIdsCache.contains(productId);
    }
    final ids = await getWishlistIds();
    return ids.contains(productId);
  }

  /// Add product to wishlist with optimistic update
  /// 
  /// [productId] - Required product ID
  /// [product] - Optional full product object for optimistic UI update
  Future<void> addToWishlist(String productId, {Product? product}) async {
    // Optimistic update
    _wishlistIdsCache.add(productId);
    if (product != null && !_productsCache.any((p) => p.id == productId)) {
      _productsCache.insert(0, product); // Add to beginning
    }
    notifyListeners();
    
    // Persist to disk immediately
    await _cacheService.addToWishlistCache(productId);
    await _persistToCache();
    
    // Sync with server in background
    if (_authService.isAuthenticated) {
      try {
        await _dio.post('/wishlist', data: {'productId': productId}, options: await _authOptions());
        debugPrint('[Wishlist] Added $productId to server');
      } catch (e) {
        debugPrint('[Wishlist] Add error: $e');
        // Revert on error
        _wishlistIdsCache.remove(productId);
        _productsCache.removeWhere((p) => p.id == productId);
        await _cacheService.removeFromWishlistCache(productId);
        await _persistToCache();
        notifyListeners();
        rethrow;
      }
    }
  }

  /// Remove product from wishlist with optimistic update
  Future<void> removeFromWishlist(String productId) async {
    // Optimistic update
    final removedProduct = _productsCache.where((p) => p.id == productId).firstOrNull;
    _wishlistIdsCache.remove(productId);
    _productsCache.removeWhere((p) => p.id == productId);
    notifyListeners();
    
    // Persist to disk immediately
    await _cacheService.removeFromWishlistCache(productId);
    await _persistToCache();
    
    // Sync with server in background
    if (_authService.isAuthenticated) {
      try {
        await _dio.delete('/wishlist/$productId', options: await _authOptions());
        debugPrint('[Wishlist] Removed $productId from server');
      } catch (e) {
        debugPrint('[Wishlist] Remove error: $e');
        // Revert on error
        _wishlistIdsCache.add(productId);
        if (removedProduct != null) {
          _productsCache.add(removedProduct);
        }
        await _cacheService.addToWishlistCache(productId);
        await _persistToCache();
        notifyListeners();
        rethrow;
      }
    }
  }

  /// Toggle wishlist status
  Future<void> toggleWishlist(String productId, {Product? product}) async {
    if (_wishlistIdsCache.contains(productId)) {
      await removeFromWishlist(productId);
    } else {
      await addToWishlist(productId, product: product);
    }
  }

  /// Persist current state to disk cache
  Future<void> _persistToCache() async {
    final jsonList = _productsCache.map((p) => p.toJson()).toList();
    await _cacheService.setListCache(_kCacheKey, jsonList, expiry: _kCacheExpiry);
    await _cacheService.setWishlistIds(_wishlistIdsCache);
  }

  /// Clear all wishlist cache
  Future<void> clearCache() async {
    _productsCache = [];
    _wishlistIdsCache = {};
    _lastFetch = null;
    await _cacheService.clearWishlistCache();
    await _cacheService.clearCache(_kCacheKey);
    notifyListeners();
  }
}
