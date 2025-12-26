import 'api_client.dart';
import 'cache_service.dart';

class OutfitService {
  static final OutfitService _instance = OutfitService._internal();
  factory OutfitService() => _instance;
  OutfitService._internal();

  static const String _kOutfitsCacheKey = 'outfits_latest';
  static const String _kDailyOutfitsCacheKey = 'daily_outfits';
  static const Duration _kCacheExpiry = Duration(minutes: 30);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Map<String, dynamic>>> getOutfits({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(_kOutfitsCacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final response = await _apiClient.get('/outfits');

      dynamic dataWrapper;
      if (response is Map) {
        dataWrapper = response['data'] ?? response;
      } else {
        dataWrapper = response;
      }

      final outfitsData = (dataWrapper is Map)
          ? (dataWrapper['outfits'] ?? dataWrapper['data'])
          : dataWrapper;

      if (outfitsData != null && outfitsData is List) {
        final outfits = (outfitsData as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

        await _cacheService.setListCache(_kOutfitsCacheKey, outfits, expiry: _kCacheExpiry);

        return outfits;
      }

      return [];
    } catch (e) {
      final cachedData = await _cacheService.getListCache(_kOutfitsCacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      throw Exception('Failed to fetch outfits: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getDailyOutfits({bool forceRefresh = false}) async {
    // Use 24-hour cache for daily outfits - works offline
    const dailyCacheExpiry = Duration(hours: 24);
    
    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(_kDailyOutfitsCacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      // Fetch fresh data
      final outfits = await getOutfits(forceRefresh: forceRefresh);
      
      // Cache with 24-hour expiry
      if (outfits.isNotEmpty) {
        await _cacheService.setListCache(
          _kDailyOutfitsCacheKey, 
          outfits, 
          expiry: dailyCacheExpiry,
        );
      }
      
      return outfits;
    } catch (e) {
      // Return cached data on error (even if expired check above failed)
      final cachedData = await _cacheService.getListCache(_kDailyOutfitsCacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOutfitsByColor(String color) async {
    try {
      final response = await _apiClient.get(
        '/outfits/by-color',
        queryParams: {'color': color},
      );

      if (response['outfits'] != null) {
        return (response['outfits'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<Map<String, dynamic>> createOutfit(Map<String, dynamic> outfitData) async {
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
        return (response['combos'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
        return (response['outfits'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch outfits by combo: ${e.toString()}');
    }
  }
}
