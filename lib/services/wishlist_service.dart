import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'auth_service.dart';

class WishlistService {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  Set<String>? _wishlistIdsCache;
  DateTime? _lastFetch;

  Future<List<Product>> getWishlist({bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated) {
      final cachedData = await _cacheService.getListCache('wishlist');
      if (cachedData != null) {
        final products = cachedData
            .map((json) => Product.fromJson(json))
            .toList();
        _wishlistIdsCache = products.map((p) => p.id).toSet();
        return products;
      }
      return [];
    }

    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache('wishlist');
      if (cachedData != null) {
        final products = cachedData
            .map((json) => Product.fromJson(json))
            .toList();
        _wishlistIdsCache = products.map((p) => p.id).toSet();
        _lastFetch = DateTime.now();
        return products;
      }
    }

    try {
      await _authService.ensureAuthenticated();

      final response = await _apiClient.get('/wishlist', requiresAuth: true);
      final wishlistData = response['data'] ?? response['wishlist'];

      if (wishlistData != null && wishlistData is List) {
        final products = wishlistData
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();

        _wishlistIdsCache = products.map((p) => p.id).toSet();
        _lastFetch = DateTime.now();

        await _cacheService.setWishlistIds(_wishlistIdsCache!);

        final jsonList = products.map((p) => p.toJson()).toList();
        await _cacheService.setListCache(
          'wishlist',
          jsonList,
          expiry: const Duration(minutes: 5),
        );

        return products;
      }

      return [];
    } catch (e) {

      final cachedData = await _cacheService.getListCache('wishlist');
      if (cachedData != null) {
        final products = cachedData
            .map((json) => Product.fromJson(json))
            .toList();
        _wishlistIdsCache = products.map((p) => p.id).toSet();
        return products;
      }

      return [];
    }
  }

  Future<Set<String>> getWishlistIds({bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated) {
      return await _cacheService.getWishlistIds();
    }

    if (!forceRefresh && _wishlistIdsCache != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < const Duration(minutes: 5)) {
        return _wishlistIdsCache!;
      }
    }

    if (!forceRefresh) {
      final cachedIds = await _cacheService.getWishlistIds();
      if (cachedIds.isNotEmpty) {
        _wishlistIdsCache = cachedIds;
        return cachedIds;
      }
    }

    try {
      final products = await getWishlist(forceRefresh: forceRefresh);
      return products.map((p) => p.id).toSet();
    } catch (e) {
      return await _cacheService.getWishlistIds();
    }
  }

  Future<bool> isInWishlist(String productId) async {
    final ids = await getWishlistIds();
    return ids.contains(productId);
  }

  Future<void> addToWishlist(String productId) async {
    if (!_authService.isAuthenticated) {
      _wishlistIdsCache?.add(productId);
      await _cacheService.addToWishlistCache(productId);
      return;
    }

    _wishlistIdsCache?.add(productId);
    await _cacheService.addToWishlistCache(productId);

    try {
      await _authService.ensureAuthenticated();

      await _apiClient.post(
        '/wishlist',
        body: {'product_id': productId},
        requiresAuth: true,
      );

      await _cacheService.clearCache('wishlist');
    } catch (e) {
      _wishlistIdsCache?.remove(productId);
      await _cacheService.removeFromWishlistCache(productId);
      throw Exception('Failed to add to wishlist: ${e.toString()}');
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    if (!_authService.isAuthenticated) {
      _wishlistIdsCache?.remove(productId);
      await _cacheService.removeFromWishlistCache(productId);
      return;
    }

    _wishlistIdsCache?.remove(productId);
    await _cacheService.removeFromWishlistCache(productId);

    try {
      await _authService.ensureAuthenticated();

      await _apiClient.delete('/wishlist/$productId', requiresAuth: true);

      await _cacheService.clearCache('wishlist');
    } catch (e) {
      _wishlistIdsCache?.add(productId);
      await _cacheService.addToWishlistCache(productId);
      throw Exception('Failed to remove from wishlist: ${e.toString()}');
    }
  }

  Future<void> clearCache() async {
    _wishlistIdsCache = null;
    _lastFetch = null;
    await _cacheService.clearWishlistCache();
    await _cacheService.clearCache('wishlist');
  }
}
