import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'auth_service.dart';

class WishlistService extends ChangeNotifier {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  static const String _kCacheKey = 'wishlist';
  static const Duration _kCacheExpiry = Duration(minutes: 5);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  List<Product> _productsCache = [];
  Set<String> _wishlistIdsCache = {};
  DateTime? _lastFetch;
  bool _isInitialized = false;

  List<Product> get products => List.unmodifiable(_productsCache);
  Set<String> get productIds => Set.unmodifiable(_wishlistIdsCache);
  int get count => _productsCache.length;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    final cachedData = await _cacheService.getListCache(_kCacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      _productsCache = cachedData.map((json) => Product.fromJson(json)).toList();
      _wishlistIdsCache = _productsCache.map((p) => p.id).toSet();
      notifyListeners();
    }
    
    _syncWithServer();
  }

  Future<List<Product>> getWishlist({bool forceRefresh = false}) async {
    if (!forceRefresh && _productsCache.isNotEmpty) {
      final isValid = _lastFetch != null && 
          DateTime.now().difference(_lastFetch!) < _kCacheExpiry;
      if (isValid) return products;
    }
    
    if (_productsCache.isEmpty) {
      final cachedData = await _cacheService.getListCache(_kCacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        _productsCache = cachedData.map((json) => Product.fromJson(json)).toList();
        _wishlistIdsCache = _productsCache.map((p) => p.id).toSet();
        notifyListeners();
      }
    }
    
    if (forceRefresh || _productsCache.isEmpty) {
      await _syncWithServer();
    }
    
    return products;
  }

  Future<void> _syncWithServer() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final token = await _authService.getStoredToken();
      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/wishlist',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
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

        _productsCache = serverProducts;
        _wishlistIdsCache = serverProducts.map((p) => p.id).toSet();
        _lastFetch = DateTime.now();
        
        await _persistToCache();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Wishlist] Sync error: $e');
    }
  }

  Future<Set<String>> getWishlistIds({bool forceRefresh = false}) async {
    if (!forceRefresh && _wishlistIdsCache.isNotEmpty) return productIds;
    
    if (_wishlistIdsCache.isEmpty) {
      final cachedIds = await _cacheService.getWishlistIds();
      if (cachedIds.isNotEmpty) {
        _wishlistIdsCache = cachedIds;
      }
    }
    
    return productIds;
  }

  bool isInWishlistSync(String productId) => _wishlistIdsCache.contains(productId);

  Future<bool> isInWishlist(String productId) async {
    if (_wishlistIdsCache.isNotEmpty) return _wishlistIdsCache.contains(productId);
    final ids = await getWishlistIds();
    return ids.contains(productId);
  }

  Future<void> addToWishlist(String productId, {Product? product}) async {
    _wishlistIdsCache.add(productId);
    if (product != null && !_productsCache.any((p) => p.id == productId)) {
      _productsCache.insert(0, product);
    }
    notifyListeners();
    
    await _cacheService.addToWishlistCache(productId);
    await _persistToCache();
    
    if (_authService.isAuthenticated) {
      try {
        final token = await _authService.getStoredToken();
        await _apiClient.dio.post(
          '${_apiClient.vercelBaseUrl}/wishlist',
          data: {'productId': productId},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (e) {
        debugPrint('[Wishlist] Add error: $e');
        _wishlistIdsCache.remove(productId);
        _productsCache.removeWhere((p) => p.id == productId);
        await _cacheService.removeFromWishlistCache(productId);
        await _persistToCache();
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    final removedProduct = _productsCache.where((p) => p.id == productId).firstOrNull;
    _wishlistIdsCache.remove(productId);
    _productsCache.removeWhere((p) => p.id == productId);
    notifyListeners();
    
    await _cacheService.removeFromWishlistCache(productId);
    await _persistToCache();
    
    if (_authService.isAuthenticated) {
      try {
        final token = await _authService.getStoredToken();
        await _apiClient.dio.delete(
          '${_apiClient.vercelBaseUrl}/wishlist/$productId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (e) {
        debugPrint('[Wishlist] Remove error: $e');
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

  Future<void> toggleWishlist(String productId, {Product? product}) async {
    if (_wishlistIdsCache.contains(productId)) {
      await removeFromWishlist(productId);
    } else {
      await addToWishlist(productId, product: product);
    }
  }

  Future<void> _persistToCache() async {
    final jsonList = _productsCache.map((p) => p.toJson()).toList();
    await _cacheService.setListCache(_kCacheKey, jsonList, expiry: _kCacheExpiry);
    await _cacheService.setWishlistIds(_wishlistIdsCache);
  }

  Future<void> clearCache() async {
    _productsCache = [];
    _wishlistIdsCache = {};
    _lastFetch = null;
    await _cacheService.clearWishlistCache();
    await _cacheService.clearCache(_kCacheKey);
    notifyListeners();
  }
}
