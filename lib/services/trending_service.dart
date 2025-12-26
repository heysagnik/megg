import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';

class TrendingService {
  static final TrendingService _instance = TrendingService._internal();
  factory TrendingService() => _instance;
  TrendingService._internal();

  static const Duration _kCacheExpiry = Duration(minutes: 5);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Product>> getTrendingProducts({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'trending_p${page}_l$limit';

    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData.map((json) => Product.fromJson(json)).toList();
      }
    }

    try {
      final response = await _apiClient.get(
        '/trending',
        queryParams: {'limit': limit.toString()},
      );

      List<Product> products = [];
      List<dynamic>? productList;

      // API returns direct array or wrapped in data/products
      if (response is List) {
        productList = response;
      } else if (response is Map<String, dynamic>) {
        productList = response['data'] as List? ??
            response['products'] as List? ??
            (response['data'] is Map ? response['data']['products'] as List? : null);
      }

      if (productList != null) {
        for (final item in productList) {
          if (item is Map<String, dynamic>) {
            try {
              products.add(Product.fromJson(item));
            } catch (e) {
              debugPrint('Failed to parse trending product: $e');
            }
          }
        }
      }

      if (products.isNotEmpty) {
        await _cacheService.setListCache(
          cacheKey,
          products.map((p) => p.toJson()).toList(),
          expiry: _kCacheExpiry,
        );
      }

      return products;
    } catch (e) {
      debugPrint('Trending fetch error: $e');
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
      debugPrint('Failed to track click: $e');
    }
  }
}
