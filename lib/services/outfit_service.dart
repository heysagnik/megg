import 'api_client.dart';
import 'cache_service.dart';

class OutfitService {
  static final OutfitService _instance = OutfitService._internal();
  factory OutfitService() => _instance;
  OutfitService._internal();

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Map<String, dynamic>>> getOutfits({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'outfits_latest';

    // Check cache first
    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }
    try {
      final response = await _apiClient.get('/outfits');

      print('Outfits API response: $response');

      // API returns: { success: true, data: { outfits: [...] } }
      final data = response['data'];
      if (data != null && data is Map && data['outfits'] != null) {
        final outfits = List<Map<String, dynamic>>.from(data['outfits']);

        // Cache outfits (30 minutes expiry)
        await _cacheService.setListCache(
          cacheKey,
          outfits,
          expiry: const Duration(minutes: 30),
        );

        return outfits;
      }

      return [];
    } catch (e) {
      // Try to return cached data even if expired
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }

      throw Exception('Failed to fetch outfits: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getDailyOutfits({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'daily_outfits';

    // Check cache first
    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    // Use the main getOutfits() method which returns up to 4 latest outfits
    return getOutfits(forceRefresh: forceRefresh);
  }

  Future<List<Map<String, dynamic>>> getOutfitsByColor(String color) async {
    try {
      final response = await _apiClient.get(
        '/outfits/by-color',
        queryParams: {'color': color},
      );

      if (response['outfits'] != null) {
        return List<Map<String, dynamic>>.from(response['outfits']);
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch outfits by color: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getOutfitDetails(String outfitId) async {
    try {
      final response = await _apiClient.get('/outfits/$outfitId');
      return response['outfit'] ?? {};
    } catch (e) {
      throw Exception('Failed to fetch outfit details: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createOutfit(
    Map<String, dynamic> outfitData,
  ) async {
    try {
      final response = await _apiClient.post(
        '/outfits',
        body: outfitData,
        requiresAuth: true,
      );

      return response['outfit'] ?? {};
    } catch (e) {
      throw Exception('Failed to create outfit: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getColorCombos() async {
    try {
      final response = await _apiClient.get('/color-combos');

      if (response['combos'] != null) {
        return List<Map<String, dynamic>>.from(response['combos']);
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch color combos: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getOutfitsByCombo(String comboId) async {
    try {
      final response = await _apiClient.get('/color-combos/$comboId/outfits');

      if (response['outfits'] != null) {
        return List<Map<String, dynamic>>.from(response['outfits']);
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch outfits by combo: ${e.toString()}');
    }
  }
}
