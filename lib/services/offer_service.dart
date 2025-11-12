import 'api_client.dart';
import 'cache_service.dart';

class OfferService {
  static final OfferService _instance = OfferService._internal();
  factory OfferService() => _instance;
  OfferService._internal();

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Map<String, dynamic>>> getOffers({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'offers_p${page}_l$limit';

    // Check cache first (if not forcing refresh)
    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final response = await _apiClient.get(
        '/offers',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
      );

      // Handle nested data structure
      final dataWrapper = response['data'] ?? response;

      if (dataWrapper['offers'] != null) {
        final offers = List<Map<String, dynamic>>.from(dataWrapper['offers']);

        // Cache offers (15 minutes expiry)
        await _cacheService.setListCache(
          cacheKey,
          offers,
          expiry: const Duration(minutes: 15),
        );

        return offers;
      }

      return [];
    } catch (e) {
      // Try to return cached data even if expired
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }

      throw Exception('Failed to fetch offers: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getOfferDetails(String offerId) async {
    try {
      final response = await _apiClient.get('/offers/$offerId');
      return response['offer'] ?? {};
    } catch (e) {
      throw Exception('Failed to fetch offer details: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createOffer(
    Map<String, dynamic> offerData,
  ) async {
    try {
      final response = await _apiClient.post(
        '/offers',
        body: offerData,
        requiresAuth: true,
      );

      return response['offer'] ?? {};
    } catch (e) {
      throw Exception('Failed to create offer: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateOffer(
    String offerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiClient.put(
        '/offers/$offerId',
        body: updates,
        requiresAuth: true,
      );

      return response['offer'] ?? {};
    } catch (e) {
      throw Exception('Failed to update offer: ${e.toString()}');
    }
  }

  Future<void> deleteOffer(String offerId) async {
    try {
      await _apiClient.delete('/offers/$offerId', requiresAuth: true);
    } catch (e) {
      throw Exception('Failed to delete offer: ${e.toString()}');
    }
  }
}
