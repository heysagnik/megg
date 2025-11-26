import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Product>> getProducts({
    String? category,
    String? color,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (color != null) queryParams['color'] = color;
      if (search != null) queryParams['search'] = search;

      final response = await _apiClient.get(
        '/products',
        queryParams: queryParams,
      );

      final data = response['data'] ?? response['products'];

      if (data is List) {
        return data.map((json) => Product.fromJson(json)).toList();
      }

      if (data is Map && data['products'] is List) {
        return (data['products'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }

      if (response['products'] is List) {
        return (response['products'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch products: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getProductDetails(
    String productId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'product_$productId';

    // Check cache first (if not forcing refresh)
    if (!forceRefresh) {
      final cachedData = await _cacheService.getCache(cacheKey);
      if (cachedData != null) {
        final product = Product.fromJson(cachedData['product']);
        final recommended = (cachedData['recommended'] as List)
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
        return {'product': product, 'recommended': recommended};
      }
    }

    try {
      final response = await _apiClient.get('/products/$productId');
      final data = response['data'] ?? response;

      final productJson = data['product'] ?? data;
      final recommendedSource = data['recommended'] ?? data['related'];

      final product = Product.fromJson(productJson);
      final recommended = (recommendedSource is List)
          ? recommendedSource.map((json) => Product.fromJson(json)).toList()
          : <Product>[];

      // Cache product details (10 minutes expiry)
      await _cacheService.setCache(cacheKey, {
        'product': product.toJson(),
        'recommended': recommended.map((p) => p.toJson()).toList(),
      }, expiry: const Duration(minutes: 10));

      return {'product': product, 'recommended': recommended};
    } catch (e) {
      // Try to return cached data even if expired
      final cachedData = await _cacheService.getCache(cacheKey);
      if (cachedData != null) {
        final product = Product.fromJson(cachedData['product']);
        final recommended = (cachedData['recommended'] as List)
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
        return {'product': product, 'recommended': recommended};
      }

      throw Exception('Failed to fetch product details: ${e.toString()}');
    }
  }

  Future<List<Product>> getRelatedProducts(String productId) async {
    try {
      final response = await _apiClient.get('/products/$productId/related');
      final data = response['data'] ?? response['related'] ?? response;

      if (data is List) {
        return data.map((json) => Product.fromJson(json)).toList();
      }

      if (data is Map && data['related'] is List) {
        return (data['related'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch related products: ${e.toString()}');
    }
  }


  Future<List<Product>> getProductRecommendations(String productId) async {
    try {
      final response = await _apiClient.get('/products/$productId/recommendations');
      final data = response['data'];

      if (data is List) {
        return data.map((json) => Product.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch product recommendations: ${e.toString()}');
    }
  }

  Future<void> recordProductClick(String productId) async {
    try {
      await _apiClient.post(
        '/products/$productId/click',
        body: {},
        requiresAuth: true,
      );
    } catch (e) {
      // Silently fail for analytics
      debugPrint('Failed to record product click: $e');
    }
  }
}
