import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/reel.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class ReelService {
  static final ReelService _instance = ReelService._internal();
  factory ReelService() => _instance;
  ReelService._internal();

  static const String _kLikedReelsCacheKey = 'liked_reels';
  static const String _kLikedReelIdsKey = 'liked_reel_ids';
  static const String _kPendingLikesKey = 'pending_reel_likes';

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  bool _isSyncing = false;
  Set<String> _localLikedReelIds = {};
  bool _localCacheLoaded = false;

  Future<List<Reel>> getReels({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/reels',
        queryParameters: {'page': page, 'limit': limit},
      );
      return _parseReelsList(response.data);
    } catch (e) {
      debugPrint('[Reels] Error fetching reels: $e');
      throw Exception('Failed to fetch reels: ${e.toString()}');
    }
  }

  Future<List<Reel>> getReelsByCategory(String category) async {
    try {
      final response = await _apiClient.get(
        '/reels',
        queryParams: {'category': category},
      );
      return _parseReelsList(response);
    } catch (e) {
      debugPrint('[Reels] Error fetching category reels: $e');
      throw Exception('Failed to fetch category reels: ${e.toString()}');
    }
  }

  Future<Reel> getReelDetails(String reelId) async {
    try {
      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/reels/$reelId',
      );
      final data = response.data;
      final reelData = data['data'] ?? data['reel'] ?? data;
      return Reel.fromJson(reelData);
    } catch (e) {
      debugPrint('[Reels] Error fetching reel details: $e');
      throw Exception('Failed to fetch reel details: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getReelWithProducts(String reelId) async {
    try {
      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/reels/$reelId/products',
      );
      final data = response.data;
      final reelData = data['data'] ?? data;
      
      List<Product> products = [];
      if (reelData['products'] != null) {
        products = (reelData['products'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
      }
      
      return {
        'reel': reelData,
        'products': products,
        'views': reelData['views'] ?? 0,
        'likes': reelData['likes'] ?? 0,
      };
    } catch (e) {
      debugPrint('[Reels] Error fetching reel products: $e');
      throw Exception('Failed to fetch reel products: ${e.toString()}');
    }
  }

  Future<void> incrementViews(String reelId) async {
    try {
      await _apiClient.dio.post('${_apiClient.vercelBaseUrl}/reels/$reelId/view');
    } catch (e) {
      // Silently fail for view tracking
    }
  }

  Future<void> toggleLike(String reelId, {required bool like}) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User must be logged in to like reels');
    }
    
    await _ensureLocalCacheLoaded();
    
    if (like) {
      _localLikedReelIds.add(reelId);
    } else {
      _localLikedReelIds.remove(reelId);
    }
    await _saveLikedReelIdsToCache();
    
    if (_connectivityService.isOffline) {
      await _queuePendingLike(reelId, like);
      return;
    }
    
    try {
      await _syncLikeToServer(reelId, like);
    } catch (e) {
      debugPrint('[Reels] Network failed, queuing like action: $e');
      await _queuePendingLike(reelId, like);
    }
  }

  Future<bool> isReelLiked(String reelId) async {
    await _ensureLocalCacheLoaded();
    return _localLikedReelIds.contains(reelId);
  }

  Future<Set<String>> getLocalLikedReelIds() async {
    await _ensureLocalCacheLoaded();
    return Set.from(_localLikedReelIds);
  }

  Future<void> _queuePendingLike(String reelId, bool like) async {
    final pending = await _getPendingLikes();
    pending[reelId] = like;
    await _cacheService.setCache(_kPendingLikesKey, pending);
  }

  Future<Map<String, bool>> _getPendingLikes() async {
    try {
      final cached = await _cacheService.getCached<Map<String, dynamic>>(_kPendingLikesKey);
      if (cached == null) return {};
      return cached.map((k, v) => MapEntry(k, v as bool));
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveLikedReelIdsToCache() async {
    await _cacheService.setCache(_kLikedReelIdsKey, _localLikedReelIds.toList());
  }

  Future<void> _ensureLocalCacheLoaded() async {
    if (_localCacheLoaded) return;
    try {
      final cached = await _cacheService.getCached<List<dynamic>>(_kLikedReelIdsKey);
      if (cached != null) {
        _localLikedReelIds = cached.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('[Reels] Error loading cached liked IDs: $e');
    }
    _localCacheLoaded = true;
  }

  Future<void> _syncLikeToServer(String reelId, bool like) async {
    final token = await _authService.getStoredToken();
    if (token == null || token.isEmpty) {
      throw Exception('No auth token available');
    }
    
    await _apiClient.dio.post(
      '${_apiClient.vercelBaseUrl}/reels/$reelId/like',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> syncPendingLikes() async {
    if (_isSyncing) return;
    if (!_authService.isAuthenticated) return;
    if (_connectivityService.isOffline) return;
    
    final pending = await _getPendingLikes();
    if (pending.isEmpty) return;
    
    _isSyncing = true;
    
    final synced = <String>[];
    for (final entry in pending.entries) {
      try {
        await _syncLikeToServer(entry.key, entry.value);
        synced.add(entry.key);
      } catch (e) {
        debugPrint('[Reels] Failed to sync like for ${entry.key}: $e');
        break;
      }
    }
    
    if (synced.isNotEmpty) {
      for (final id in synced) {
        pending.remove(id);
      }
      await _cacheService.setCache(_kPendingLikesKey, pending);
    }
    
    _isSyncing = false;
  }

  void initOfflineSync() {
    _connectivityService.addListener(() {
      if (_connectivityService.isOnline) {
        syncPendingLikes();
      }
    });
  }

  Future<List<Reel>> getLikedReels() async {
    if (!_authService.isAuthenticated) return [];
    
    try {
      final token = await _authService.getStoredToken();
      if (token == null || token.isEmpty) return [];

      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/reels/liked',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      List<Reel> reels = _parseReelsList(response.data);

      if (reels.isNotEmpty) {
        await _cacheService.setListCache(
          _kLikedReelsCacheKey,
          reels.map((r) => r.toJson()).toList(),
        );
      }

      return reels;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return [];
      return [];
    } catch (e) {
      debugPrint('[Reels] Error fetching liked reels: $e');
      return [];
    }
  }

  Future<Set<String>> getLikedReelIds({bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated) return {};
    
    await _ensureLocalCacheLoaded();
    
    if (!forceRefresh && _connectivityService.isOnline) {
      _refreshLikedReelIdsFromServer();
    }
    
    return Set.from(_localLikedReelIds);
  }

  Future<void> _refreshLikedReelIdsFromServer() async {
    try {
      final likedReels = await getLikedReels();
      final ids = likedReels.map((reel) => reel.id).toSet();
      _localLikedReelIds = ids;
      await _saveLikedReelIdsToCache();
    } catch (e) {
      // Silent fail
    }
  }

  List<Reel> _parseReelsList(dynamic data) {
    if (data is List) {
      return data.map((json) => Reel.fromJson(json)).toList();
    } else if (data is Map) {
      final reelsData = data['data'] ?? data['reels'];
      if (reelsData is List) {
        return reelsData.map((json) => Reel.fromJson(json)).toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> createReel(Map<String, dynamic> reelData) async {
    try {
      await _authService.ensureAuthenticated();
      final token = await _authService.getStoredToken();

      final response = await _apiClient.dio.post(
        '${_apiClient.vercelBaseUrl}/reels',
        data: reelData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['reel'] ?? {};
    } catch (e) {
      debugPrint('[Reels] Error creating reel: $e');
      throw Exception('Failed to create reel: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateReel(
    String reelId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _authService.ensureAuthenticated();
      final token = await _authService.getStoredToken();

      final response = await _apiClient.dio.put(
        '${_apiClient.vercelBaseUrl}/reels/$reelId',
        data: updates,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['reel'] ?? {};
    } catch (e) {
      debugPrint('[Reels] Error updating reel: $e');
      throw Exception('Failed to update reel: ${e.toString()}');
    }
  }

  Future<void> deleteReel(String reelId) async {
    try {
      await _authService.ensureAuthenticated();
      final token = await _authService.getStoredToken();

      await _apiClient.dio.delete(
        '${_apiClient.vercelBaseUrl}/reels/$reelId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('[Reels] Error deleting reel: $e');
      throw Exception('Failed to delete reel: ${e.toString()}');
    }
  }
}
