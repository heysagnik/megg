import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';

class TrendingService {
  static final TrendingService _instance = TrendingService._internal();
  factory TrendingService() => _instance;
  TrendingService._internal();

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Product>> getTrendingProducts({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'trending_p${page}_l$limit';

    // Check cache first (if not forcing refresh)
    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData.map((json) => Product.fromJson(json)).toList();
      }
    }

    try {
      final response = await _apiClient.get(
        '/trending/products',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        requiresAuth: true,
      );
      final data = response['data'] ?? response['products'];

      List<Product> products = [];

      if (data is List) {
        products = data.map((json) => Product.fromJson(json)).toList();
      } else if (data is Map && data['products'] is List) {
        products = (data['products'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      } else if (response['products'] is List) {
        products = (response['products'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }

      if (products.isNotEmpty) {
        // Cache trending products (5 minutes expiry)
        await _cacheService.setListCache(
          cacheKey,
          products.map((p) => p.toJson()).toList(),
          expiry: const Duration(minutes: 5),
        );
      }

      return products;
    } catch (e) {
      // Try to return cached data even if expired
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData.map((json) => Product.fromJson(json)).toList();
      }

      throw Exception('Failed to fetch trending products: ${e.toString()}');
    }
  }

  Future<void> trackProductClick(String productId) async {
    try {
      await _apiClient.post('/trending/click/$productId');
    } catch (e) {
      debugPrint('Warning: Failed to track click: $e');
    }
  }
}
