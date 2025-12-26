import '../models/color_combo.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';

class ColorComboService {
  static final ColorComboService _instance = ColorComboService._internal();
  factory ColorComboService() => _instance;
  ColorComboService._internal();

  static const Duration _kCacheExpiry = Duration(hours: 24);
  static const Duration _kProductsCacheExpiry = Duration(hours: 12);
  static const Duration _kRecommendationsCacheExpiry = Duration(hours: 6);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<ColorCombo>> getColorCombos({
    String? group,
    bool forceRefresh = false,
  }) async {
    final cacheKey = group != null ? 'color_combos_$group' : 'color_combos_all';

    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData.map((json) => ColorCombo.fromJson(Map<String, dynamic>.from(json as Map))).toList();
      }
    }

    try {
      final queryParams = <String, String>{};
      if (group != null) {
        queryParams['group_type'] = group;
      }

      final response = await _apiClient.get(
        '/color-combos',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      dynamic dataWrapper;
      if (response is Map) {
        dataWrapper = response['data'] ?? response;
      } else {
        dataWrapper = response;
      }

      final data = (dataWrapper is Map && (dataWrapper.containsKey('combos') || dataWrapper.containsKey('color_combos')))
          ? (dataWrapper['combos'] ?? dataWrapper['color_combos'])
          : dataWrapper;

      if (data is List) {
        final combos = data.map((json) => ColorCombo.fromJson(Map<String, dynamic>.from(json as Map))).toList();

        await _cacheService.setListCache(
          cacheKey,
          combos.map((c) => c.toJson()).toList(),
          expiry: _kCacheExpiry,
        );

        return combos;
      }

      return [];
    } catch (e) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData.map((json) => ColorCombo.fromJson(Map<String, dynamic>.from(json as Map))).toList();
      }
      throw Exception('Failed to fetch color combos: $e');
    }
  }

  Future<Map<String, dynamic>> getColorComboWithProducts(
    String comboId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'color_combo_products_$comboId';

    if (!forceRefresh) {
      final cachedData = await _cacheService.getCache(cacheKey);
      if (cachedData != null) {
        final combo = ColorCombo.fromJson(Map<String, dynamic>.from(cachedData['combo'] as Map));
        final products = (cachedData['products'] as List)
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        return {'combo': combo, 'products': products};
      }
    }

    try {
      // Use direct combo endpoint to get combo details with products
      final response = await _apiClient.get('/color-combos/$comboId');

      final dataWrapper = response['data'] ?? response;
      final comboData = dataWrapper['combo'] ?? dataWrapper;
      final productsData = dataWrapper['products'] ?? [];

      final combo = ColorCombo.fromJson(comboData);
      final products = (productsData as List)
          .map((json) => Product.fromJson(json))
          .toList();

      await _cacheService.setCache(cacheKey, {
        'combo': combo.toJson(),
        'products': products.map((p) => p.toJson()).toList(),
      }, expiry: _kProductsCacheExpiry);

      return {'combo': combo, 'products': products};
    } catch (e) {
      final cachedData = await _cacheService.getCache(cacheKey);
      if (cachedData != null) {
        final combo = ColorCombo.fromJson(Map<String, dynamic>.from(cachedData['combo'] as Map));
        final products = (cachedData['products'] as List)
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        return {'combo': combo, 'products': products};
      }
      throw Exception('Failed to fetch combo products: $e');
    }
  }

  Future<List<ColorCombo>> getRecommendedCombos(String comboId) async {
    final cacheKey = 'color_combo_recommended_$comboId';

    final cachedData = await _cacheService.getListCache(cacheKey);
    if (cachedData != null) {
      return cachedData.map((json) => ColorCombo.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    }

    try {
      final response = await _apiClient.get('/color-combos/$comboId/recommendations');

      final data = response['data'] ?? response;

      if (data is List) {
        final combos = data.map((json) => ColorCombo.fromJson(Map<String, dynamic>.from(json as Map))).toList();

        await _cacheService.setListCache(
          cacheKey,
          combos.map((c) => c.toJson()).toList(),
          expiry: _kRecommendationsCacheExpiry,
        );

        return combos;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<ColorCombo>> getCombosByGroup(
    String group, {
    bool forceRefresh = false,
  }) async {
    return getColorCombos(group: group, forceRefresh: forceRefresh);
  }
}
