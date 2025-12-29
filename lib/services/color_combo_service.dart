import 'package:flutter/foundation.dart';
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
    debugPrint('[ColorComboService] getColorCombos called. group=$group, forceRefresh=$forceRefresh');
    final cacheKey = group != null ? 'color_combos_$group' : 'color_combos_all';

    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        debugPrint('[ColorComboService] Returning ${cachedData.length} combos from cache.');
        return cachedData.map((json) => ColorCombo.fromJson(Map<String, dynamic>.from(json as Map))).toList();
      }
      debugPrint('[ColorComboService] No cache found for key: $cacheKey');
    }

    try {
      final queryParams = <String, String>{};
      if (group != null) {
        queryParams['group_type'] = group;
      }

      debugPrint('[ColorComboService] Making API call to /color-combos with queryParams: $queryParams');
      final response = await _apiClient.get(
        '/color-combos',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      debugPrint('[ColorComboService] API response type: ${response.runtimeType}');

      dynamic dataWrapper;
      if (response is Map) {
        dataWrapper = response['data'] ?? response;
        debugPrint('[ColorComboService] Response is a Map. dataWrapper type: ${dataWrapper.runtimeType}');
      } else {
        dataWrapper = response;
        debugPrint('[ColorComboService] Response is NOT a Map. Using response directly.');
      }

      final data = (dataWrapper is Map && (dataWrapper.containsKey('combos') || dataWrapper.containsKey('color_combos')))
          ? (dataWrapper['combos'] ?? dataWrapper['color_combos'])
          : dataWrapper;

      debugPrint('[ColorComboService] Extracted data type: ${data.runtimeType}');

      if (data is List) {
        debugPrint('[ColorComboService] Data is a List with ${data.length} items.');
        final combos = <ColorCombo>[];
        for (final item in data) {
          try {
            combos.add(ColorCombo.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (e) {
            debugPrint('[ColorComboService] Error parsing combo item: $e');
          }
        }
        debugPrint('[ColorComboService] Successfully parsed ${combos.length} combos.');

        await _cacheService.setListCache(
          cacheKey,
          combos.map((c) => c.toJson()).toList(),
          expiry: _kCacheExpiry,
        );

        return combos;
      }

      debugPrint('[ColorComboService] Data is NOT a List. Returning empty.');
      return [];
    } catch (e) {
      debugPrint('[ColorComboService] API call FAILED: $e');
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        debugPrint('[ColorComboService] Returning ${cachedData.length} combos from fallback cache.');
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
        final combos = <ColorCombo>[];
        for (final item in data) {
          try {
            combos.add(ColorCombo.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (e) {
            print('Error parsing recommendation: $e');
          }
        }

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
