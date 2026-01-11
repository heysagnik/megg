import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  static const Duration _kProductsCacheExpiry = Duration(minutes: 10);
  static const Duration _kDetailsCacheExpiry = Duration(minutes: 10);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Product>> getProducts({
    String? category,
    String? color,
    String? search,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final bool canCache = page == 1 && category == null && color == null && search == null;
    final String cacheKey = 'products_new_arrivals_p1_l$limit';

    if (canCache && !forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData.map((json) => Product.fromJson(json)).toList();
      }
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (color != null) queryParams['color'] = color;
      if (search != null) queryParams['search'] = search;

      final response = await _apiClient.get('/products', queryParams: queryParams);

      dynamic dataWrapper;
      if (response is Map) {
        dataWrapper = response['data'] ?? response;
      } else {
        dataWrapper = response;
      }

      List<Product> products = [];
      dynamic productList;

      if (dataWrapper is List) {
        productList = dataWrapper;
      } else if (dataWrapper is Map) {
        productList = dataWrapper['products'] ?? dataWrapper['data'];
      }

      if (productList is List) {
        products = productList.map<Product>((json) => Product.fromJson(json)).toList();
      }

      if (canCache && products.isNotEmpty) {
        await _cacheService.setListCache(
          cacheKey,
          products.map((p) => p.toJson()).toList(),
          expiry: _kProductsCacheExpiry,
        );
      }

      return products;
    } catch (e) {
      if (canCache) {
        final cachedData = await _cacheService.getListCache(cacheKey);
        if (cachedData != null) {
          return cachedData.map((json) => Product.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to fetch products: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getProductDetails(
    String productId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'product_$productId';

    if (!forceRefresh) {
      final cachedData = await _cacheService.getCache(cacheKey);
      if (cachedData != null) {
        debugPrint('[ProductService] Using cached data for $productId');
        try {
          final productData = Map<String, dynamic>.from(cachedData['product'] as Map);
          final product = Product.fromJson(productData);
          final recommended = (cachedData['recommended'] as List? ?? [])
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();
          final variants = (cachedData['variants'] as List? ?? [])
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();
          return {'product': product, 'recommended': recommended, 'variants': variants};
        } catch (e) {
          debugPrint('[ProductService] Cache parse error, fetching fresh: $e');
        }
      }
    }

    try {
      debugPrint('[ProductService] Fetching from API for $productId');
      final response = await _apiClient.get('/products/$productId');
      debugPrint('[ProductService] Raw response type: ${response.runtimeType}');
      
      final data = response['data'] ?? response;
      debugPrint('[ProductService] Data keys: ${data is Map ? data.keys.toList() : 'not a map'}');

      final productJson = data['product'] ?? data;
      final recommendedSource = data['recommended'] ?? data['related'];
      final variantsSource = data['variants'];
      
      debugPrint('[ProductService] recommendedSource type: ${recommendedSource.runtimeType}, is list: ${recommendedSource is List}');
      debugPrint('[ProductService] variantsSource type: ${variantsSource.runtimeType}, is list: ${variantsSource is List}');

      final product = Product.fromJson(productJson);
      final recommended = (recommendedSource is List)
          ? recommendedSource.map((json) => Product.fromJson(json)).toList()
          : <Product>[];
      final variants = (variantsSource is List)
          ? variantsSource.map((json) => Product.fromJson(json)).toList()
          : <Product>[];
      
      debugPrint('[ProductService] Parsed recommended: ${recommended.length}, variants: ${variants.length}');

      await _cacheService.setCache(cacheKey, {
        'product': product.toJson(),
        'recommended': recommended.map((p) => p.toJson()).toList(),
        'variants': variants.map((p) => p.toJson()).toList(),
      }, expiry: _kDetailsCacheExpiry);

      return {'product': product, 'recommended': recommended, 'variants': variants};
    } catch (e) {
      debugPrint('[ProductService] Error: $e');
      final cachedData = await _cacheService.getCache(cacheKey);
      if (cachedData != null) {
        try {
          final productData = Map<String, dynamic>.from(cachedData['product'] as Map);
          final product = Product.fromJson(productData);
          final recommended = (cachedData['recommended'] as List? ?? [])
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();
          final variants = (cachedData['variants'] as List? ?? [])
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();
          return {'product': product, 'recommended': recommended, 'variants': variants};
        } catch (_) {
          // Cache parsing failed, rethrow original error
        }
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
        return (data['related'] as List).map((json) => Product.fromJson(json)).toList();
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
      throw Exception('Failed to fetch recommendations: ${e.toString()}');
    }
  }

  Future<void> recordProductClick(String productId) async {
    try {
      await _apiClient.post('/products/$productId/click', body: {}, requiresAuth: true);
    } catch (e) {
      debugPrint('Failed to record product click: $e');
    }
  }

  Future<List<Product>> getProductVariants(String productId) async {
    try {
      final response = await _apiClient.get('/products/$productId/variants');
      final data = response['data'];

      if (data is List) {
        return data.map((json) => Product.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Failed to fetch product variants: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return [];

    final futures = productIds.map((id) async {
      try {
        final result = await getProductDetails(id);
        final product = result['product'];
        if (product is Product) {
          return product;
        }
      } catch (e) {
        // Silently skip missing products (404s are expected for deleted products)
      }
      return null;
    });

    final results = await Future.wait(futures);
    return results.whereType<Product>().toList();
  }
}
