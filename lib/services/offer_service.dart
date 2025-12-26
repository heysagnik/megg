import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'cache_service.dart';

class OfferService {
  static final OfferService _instance = OfferService._internal();
  factory OfferService() => _instance;
  OfferService._internal();

  static const Duration _kCacheExpiry = Duration(minutes: 15);

  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  Future<List<Map<String, dynamic>>> getOffers({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'offers_p${page}_l$limit';
    debugPrint('[Offers] getOffers(page=$page, limit=$limit, forceRefresh=$forceRefresh)');

    if (!forceRefresh) {
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        debugPrint('[Offers] Returning ${cachedData.length} cached offers');
        return cachedData;
      }
    }

    try {
      debugPrint('[Offers] GET /offers');
      final response = await _apiClient.get(
        '/offers',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
      );
      debugPrint('[Offers] Response type: ${response.runtimeType}');

      List<Map<String, dynamic>> offers = [];
      
      // Handle different response formats
      if (response is List) {
        // Direct list response
        offers = List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        // Wrapped response - try different keys
        final data = response['data'] ?? response;
        if (data is List) {
          offers = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['offers'] != null) {
          offers = List<Map<String, dynamic>>.from(data['offers']);
        }
      }

      debugPrint('[Offers] Fetched ${offers.length} offers');
      
      if (offers.isNotEmpty) {
        await _cacheService.setListCache(cacheKey, offers, expiry: _kCacheExpiry);
      }

      return offers;
    } catch (e) {
      debugPrint('[Offers] Error: $e');
      final cachedData = await _cacheService.getListCache(cacheKey);
      if (cachedData != null) {
        debugPrint('[Offers] Returning ${cachedData.length} cached offers after error');
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

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> offerData) async {
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
