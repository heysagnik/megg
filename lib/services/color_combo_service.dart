import 'package:flutter/foundation.dart';
import '../models/color_combo.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'cache_service.dart';


class ColorCombosResult {
  final List<ColorCombo> combos;
  final List<String> colorsA;
  final List<String> colorsB;
  final List<String> colorsC;

  ColorCombosResult({
    required this.combos,
    this.colorsA = const [],
    this.colorsB = const [],
    this.colorsC = const [],
  });
}

class ColorComboService {
  static final ColorComboService _instance = ColorComboService._internal();
  factory ColorComboService() => _instance;
  ColorComboService._internal();

  static const Duration _kCacheExpiry = Duration(hours: 24);
  static const Duration _kProductsCacheExpiry = Duration(hours: 12);
  static const Duration _kRecommendationsCacheExpiry = Duration(hours: 6);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<ColorCombosResult> getColorCombosWithMeta({
    String? group,
    String? colorA,
    String? colorB,
    String? colorC,
    bool forceRefresh = false,
  }) async {
    // Build cache key including filters
    final filterKey = '${colorA ?? ''}_${colorB ?? ''}_${colorC ?? ''}';
    final cacheKey = group != null 
        ? 'color_combos_${group}_$filterKey' 
        : 'color_combos_all_$filterKey';

    if (forceRefresh) {
      await _cacheService.clearCache(cacheKey);
    }

    try {
      final queryParams = <String, String>{};
      if (group != null) queryParams['group_type'] = group;
      if (colorA != null) queryParams['color_a'] = colorA;
      if (colorB != null) queryParams['color_b'] = colorB;
      if (colorC != null) queryParams['color_c'] = colorC;

      final response = await _apiClient.get(
        '/color-combos',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        forceRefresh: forceRefresh,
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

      // Parse color metadata
      List<String> colorsA = [];
      List<String> colorsB = [];
      List<String> colorsC = [];
      
      if (response is Map && response['meta'] != null) {
        final meta = response['meta'];
        if (meta['colors'] != null) {
          final colors = meta['colors'];
          colorsA = List<String>.from(colors['a'] ?? []);
          colorsB = List<String>.from(colors['b'] ?? []);
          colorsC = List<String>.from(colors['c'] ?? []);
        }
      }

      if (data is List) {
        final combos = <ColorCombo>[];
        for (final item in data) {
          try {
            combos.add(ColorCombo.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (e) {
            debugPrint('[ColorCombo] Parse error: $e');
          }
        }

        return ColorCombosResult(
          combos: combos,
          colorsA: colorsA,
          colorsB: colorsB,
          colorsC: colorsC,
        );
      }

      return ColorCombosResult(combos: []);
    } catch (e) {
      debugPrint('[ColorCombo] Fetch failed: $e');
      throw Exception('Failed to fetch color combos: $e');
    }
  }

  Future<List<ColorCombo>> getColorCombos({
    String? group,
    bool forceRefresh = false,
  }) async {
    final result = await getColorCombosWithMeta(group: group, forceRefresh: forceRefresh);
    return result.combos;
  }

  Future<Map<String, dynamic>> getColorComboWithProducts(
    String comboId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'color_combo_products_$comboId';

    if (forceRefresh) {
      await _cacheService.clearCache(cacheKey);
    }

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
      final response = await _apiClient.get('/color-combos/$comboId', forceRefresh: forceRefresh);
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
            // Skip invalid items
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
