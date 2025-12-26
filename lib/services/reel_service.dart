import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/reel.dart';
import '../models/product.dart';
import '../config/api_config.dart';
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
  static const String _kTokenKey = 'session_token';

  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  late final Dio _dioVercel;
  late final Dio _dioCloudflare;
  bool _isInitialized = false;
  bool _isSyncing = false;
  
  // Local cache of liked reel IDs for instant UI updates
  Set<String> _localLikedReelIds = {};
  bool _localCacheLoaded = false;

  void _initDio() {
    if (_isInitialized) return;
    
    // Vercel API - for auth-related operations (likes, views, etc.)
    _dioVercel = Dio(BaseOptions(
      baseUrl: '${ApiConfig.vercelUrl}/api',
      connectTimeout: ApiConfig.connectionTimeout,
      receiveTimeout: ApiConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Cloudflare API - for category filtering
    _dioCloudflare = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectionTimeout,
      receiveTimeout: ApiConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _isInitialized = true;
    debugPrint('[Reels] Dio initialized - Vercel: ${ApiConfig.vercelUrl}/api, Cloudflare: ${ApiConfig.baseUrl}');
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _secureStorage.read(key: _kTokenKey);
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  /// Get all reels with pagination
  Future<List<Reel>> getReels({int page = 1, int limit = 20}) async {
    _initDio();
    try {
      debugPrint('[Reels] GET /reels?page=$page&limit=$limit');
      final response = await _dioVercel.get(
        '/reels',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = response.data;
      return _parseReelsList(data);
    } catch (e) {
      debugPrint('[Reels] Error fetching reels: $e');
      throw Exception('Failed to fetch reels: ${e.toString()}');
    }
  }

  /// Get reels filtered by category
  Future<List<Reel>> getReelsByCategory(String category) async {
    _initDio();
    try {
      debugPrint('[Reels] GET /reels?category=$category');
      final response = await _dioCloudflare.get(
        '/reels',
        queryParameters: {'category': category},
      );

      final data = response.data;
      return _parseReelsList(data);
    } catch (e) {
      debugPrint('[Reels] Error fetching category reels: $e');
      throw Exception('Failed to fetch category reels: ${e.toString()}');
    }
  }

  /// Get a single reel's details
  Future<Reel> getReelDetails(String reelId) async {
    _initDio();
    try {
      debugPrint('[Reels] GET /reels/$reelId');
      final response = await _dioVercel.get('/reels/$reelId');
      
      final data = response.data;
      final reelData = data['data'] ?? data['reel'] ?? data;
      return Reel.fromJson(reelData);
    } catch (e) {
      debugPrint('[Reels] Error fetching reel details: $e');
      throw Exception('Failed to fetch reel details: ${e.toString()}');
    }
  }

  /// Get reel with associated products
  /// GET /reels/{reelId}/products
  Future<Map<String, dynamic>> getReelWithProducts(String reelId) async {
    _initDio();
    try {
      debugPrint('[Reels] GET /reels/$reelId/products');
      final response = await _dioVercel.get('/reels/$reelId/products');
      
      final data = response.data;
      final reelData = data['data'] ?? data;
      
      // Parse products if available
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

  /// Track a view for a reel (call when user watches)
  /// POST /reels/{reelId}/view
  Future<void> incrementViews(String reelId) async {
    _initDio();
    try {
      debugPrint('[Reels] POST /reels/$reelId/view');
      await _dioVercel.post('/reels/$reelId/view');
      debugPrint('[Reels] View tracked for $reelId');
    } catch (e) {
      // Silently fail for view tracking
      debugPrint('[Reels] Failed to track view: $e');
    }
  }

  
  /// Toggle like for a reel - OFFLINE FIRST
  /// Updates local state immediately, queues for sync if offline
  Future<void> toggleLike(String reelId, {required bool like}) async {
    _initDio();
    
    if (!_authService.isAuthenticated) {
      debugPrint('[Reels] User not authenticated, cannot like reel');
      throw Exception('User must be logged in to like reels');
    }
    
    // Load local cache if needed
    await _ensureLocalCacheLoaded();
    
    // Update local state immediately for instant UI feedback
    if (like) {
      _localLikedReelIds.add(reelId);
    } else {
      _localLikedReelIds.remove(reelId);
    }
    await _saveLikedReelIdsToCache();
    debugPrint('[Reels] Local like state updated for $reelId (like=$like)');
    
    // Check connectivity
    if (_connectivityService.isOffline) {
      // Queue the action for later sync
      await _queuePendingLike(reelId, like);
      debugPrint('[Reels] Offline - queued like action for $reelId');
      return;
    }
    
    // Online: try to sync immediately
    try {
      await _syncLikeToServer(reelId, like);
    } catch (e) {
      // Network failed, queue for later
      debugPrint('[Reels] Network failed, queuing like action: $e');
      await _queuePendingLike(reelId, like);
    }
  }

  /// Check if a reel is liked (uses local cache for instant response)
  Future<bool> isReelLiked(String reelId) async {
    await _ensureLocalCacheLoaded();
    return _localLikedReelIds.contains(reelId);
  }

  /// Get liked reel IDs from local cache (instant, no network)
  Future<Set<String>> getLocalLikedReelIds() async {
    await _ensureLocalCacheLoaded();
    return Set.from(_localLikedReelIds);
  }

  /// Queue a pending like action for later sync
  Future<void> _queuePendingLike(String reelId, bool like) async {
    final pending = await _getPendingLikes();
    // Replace any existing action for this reel with the latest
    pending[reelId] = like;
    await _cacheService.setCache(_kPendingLikesKey, pending);
    debugPrint('[Reels] Pending likes queue: ${pending.length} items');
  }

  /// Get pending likes queue from cache
  Future<Map<String, bool>> _getPendingLikes() async {
    try {
      final cached = await _cacheService.getCached<Map<String, dynamic>>(_kPendingLikesKey);
      if (cached == null) return {};
      return cached.map((k, v) => MapEntry(k, v as bool));
    } catch (e) {
      return {};
    }
  }

  /// Save liked reel IDs to cache
  Future<void> _saveLikedReelIdsToCache() async {
    await _cacheService.setCache(_kLikedReelIdsKey, _localLikedReelIds.toList());
  }

  /// Load liked reel IDs from cache
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

  /// Sync a single like to server
  Future<void> _syncLikeToServer(String reelId, bool like) async {
    final token = await _secureStorage.read(key: _kTokenKey);
    if (token == null || token.isEmpty) {
      throw Exception('No auth token available');
    }
    
    debugPrint('[Reels] POST /reels/$reelId/like (like=$like)');
    await _dioVercel.post(
      '/reels/$reelId/like',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    debugPrint('[Reels] Like synced for $reelId');
  }

  /// Sync all pending likes to server (call when back online)
  Future<void> syncPendingLikes() async {
    if (_isSyncing) return;
    if (!_authService.isAuthenticated) return;
    if (_connectivityService.isOffline) return;
    
    final pending = await _getPendingLikes();
    if (pending.isEmpty) {
      debugPrint('[Reels] No pending likes to sync');
      return;
    }
    
    _isSyncing = true;
    debugPrint('[Reels] Syncing ${pending.length} pending likes...');
    
    final synced = <String>[];
    for (final entry in pending.entries) {
      try {
        await _syncLikeToServer(entry.key, entry.value);
        synced.add(entry.key);
      } catch (e) {
        debugPrint('[Reels] Failed to sync like for ${entry.key}: $e');
        // Stop on first failure, will retry later
        break;
      }
    }
    
    // Remove synced items from queue
    if (synced.isNotEmpty) {
      for (final id in synced) {
        pending.remove(id);
      }
      await _cacheService.setCache(_kPendingLikesKey, pending);
      debugPrint('[Reels] Synced ${synced.length} likes, ${pending.length} remaining');
    }
    
    _isSyncing = false;
  }

  /// Initialize offline sync listener (call on app startup)
  void initOfflineSync() {
    _connectivityService.addListener(() {
      if (_connectivityService.isOnline) {
        debugPrint('[Reels] Back online - triggering pending likes sync');
        syncPendingLikes();
      }
    });
  }


  /// Get user's liked reels
  Future<List<Reel>> getLikedReels() async {
    _initDio();
    
    if (!_authService.isAuthenticated) {
      debugPrint('[Reels] User not authenticated, returning empty liked reels');
      return [];
    }
    
    try {
      final token = await _secureStorage.read(key: _kTokenKey);
      debugPrint('[Reels] Token for liked reels: ${token != null ? "exists (${token.length} chars)" : "null"}');
      
      if (token == null || token.isEmpty) {
        debugPrint('[Reels] No token available, returning empty');
        return [];
      }

      debugPrint('[Reels] GET /reels/liked');
      final response = await _dioVercel.get(
        '/reels/liked',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      List<Reel> reels = _parseReelsList(response.data);
      debugPrint('[Reels] Fetched ${reels.length} liked reels');

      if (reels.isNotEmpty) {
        await _cacheService.setListCache(
          _kLikedReelsCacheKey,
          reels.map((r) => r.toJson()).toList(),
        );
      }

      return reels;
    } on DioException catch (e) {
      debugPrint('[Reels] DioException fetching liked reels: ${e.response?.statusCode}');
      // On 401, return empty list instead of throwing
      if (e.response?.statusCode == 401) {
        debugPrint('[Reels] 401 - user not authenticated for liked reels');
        return [];
      }
      return [];
    } catch (e) {
      debugPrint('[Reels] Error fetching liked reels: $e');
      return [];
    }
  }

  /// Get IDs of user's liked reels - OFFLINE FIRST
  /// Returns local cache immediately, refreshes from server in background if online
  Future<Set<String>> getLikedReelIds({bool forceRefresh = false}) async {
    // Check auth first before attempting
    if (!_authService.isAuthenticated) {
      return {};
    }
    
    // Return local cache immediately for instant UI
    await _ensureLocalCacheLoaded();
    
    // If online and not stale, refresh from server in background
    if (!forceRefresh && _connectivityService.isOnline) {
      // Fire and forget - update cache in background
      _refreshLikedReelIdsFromServer();
    }
    
    return Set.from(_localLikedReelIds);
  }

  /// Refresh liked reel IDs from server and update local cache
  Future<void> _refreshLikedReelIdsFromServer() async {
    try {
      final likedReels = await getLikedReels();
      final ids = likedReels.map((reel) => reel.id).toSet();
      _localLikedReelIds = ids;
      await _saveLikedReelIdsToCache();
      debugPrint('[Reels] Refreshed liked reel IDs from server: ${ids.length}');
    } catch (e) {
      debugPrint('[Reels] Error refreshing liked reel IDs: $e');
    }
  }

  /// Helper to parse reels list from various API response formats
  List<Reel> _parseReelsList(dynamic data) {
    if (data is List) {
      return data.map((json) => Reel.fromJson(json)).toList();
    } else if (data is Map) {
      // Check for wrapped response
      final reelsData = data['data'] ?? data['reels'];
      if (reelsData is List) {
        return reelsData.map((json) => Reel.fromJson(json)).toList();
      }
    }
    return [];
  }

  // Admin methods (if needed)
  
  Future<Map<String, dynamic>> createReel(Map<String, dynamic> reelData) async {
    _initDio();
    try {
      await _authService.ensureAuthenticated();
      final headers = await _getAuthHeaders();

      debugPrint('[Reels] POST /reels');
      final response = await _dioVercel.post(
        '/reels',
        data: reelData,
        options: Options(headers: headers),
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
    _initDio();
    try {
      await _authService.ensureAuthenticated();
      final headers = await _getAuthHeaders();

      debugPrint('[Reels] PUT /reels/$reelId');
      final response = await _dioVercel.put(
        '/reels/$reelId',
        data: updates,
        options: Options(headers: headers),
      );

      return response.data['reel'] ?? {};
    } catch (e) {
      debugPrint('[Reels] Error updating reel: $e');
      throw Exception('Failed to update reel: ${e.toString()}');
    }
  }

  Future<void> deleteReel(String reelId) async {
    _initDio();
    try {
      await _authService.ensureAuthenticated();
      final headers = await _getAuthHeaders();

      debugPrint('[Reels] DELETE /reels/$reelId');
      await _dioVercel.delete(
        '/reels/$reelId',
        options: Options(headers: headers),
      );
    } catch (e) {
      debugPrint('[Reels] Error deleting reel: $e');
      throw Exception('Failed to delete reel: ${e.toString()}');
    }
  }
}
