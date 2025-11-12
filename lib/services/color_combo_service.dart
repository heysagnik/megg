import '../models/color_combo.dart';
import '../models/product.dart';
import 'api_client.dart';

class ColorComboService {
  static final ColorComboService _instance = ColorComboService._internal();
  factory ColorComboService() => _instance;
  ColorComboService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Get all color combos, optionally filtered by group
  Future<List<ColorCombo>> getColorCombos({String? group}) async {
    try {
      final queryParams = <String, String>{};
      if (group != null) {
        queryParams['group'] = group;
      }

      final response = await _apiClient.get(
        '/color-combos',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      // Handle different response structures
      final data = response['data'] ?? response['combos'] ?? response;

      if (data is List) {
        return data.map((json) => ColorCombo.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch color combos: $e');
    }
  }

  /// Get a specific color combo and its associated products
  Future<Map<String, dynamic>> getColorComboWithProducts(String comboId) async {
    try {
      final response = await _apiClient.get('/color-combos/$comboId/products');

      // Handle nested data structure: response.data.combo and response.data.products
      final dataWrapper = response['data'] ?? response;
      final comboData = dataWrapper['combo'];
      final productsData = dataWrapper['products'];

      if (comboData == null || productsData == null) {
        throw Exception('Invalid response structure');
      }

      final combo = ColorCombo.fromJson(comboData);
      final products = (productsData as List)
          .map((json) => Product.fromJson(json))
          .toList();

      return {'combo': combo, 'products': products};
    } catch (e) {
      throw Exception('Failed to fetch combo products: $e');
    }
  }

  /// Get color combos by group type
  Future<List<ColorCombo>> getCombosByGroup(String group) async {
    return getColorCombos(group: group);
  }
}
