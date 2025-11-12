import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Cache with expiry
  Future<void> setCache(
    String key,
    Map<String, dynamic> data, {
    Duration? expiry,
  }) async {
    await init();

    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };

    await _prefs?.setString(key, jsonEncode(cacheData));
  }

  Future<Map<String, dynamic>?> getCache(String key) async {
    await init();

    final cachedString = _prefs?.getString(key);
    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiryMs = cacheData['expiry'] as int?;

      // Check if expired
      if (expiryMs != null) {
        final expiredAt = timestamp + expiryMs;
        if (DateTime.now().millisecondsSinceEpoch > expiredAt) {
          await clearCache(key);
          return null;
        }
      }

      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      await clearCache(key);
      return null;
    }
  }

  Future<void> clearCache(String key) async {
    await init();
    await _prefs?.remove(key);
  }

  Future<void> clearAllCache() async {
    await init();
    await _prefs?.clear();
  }

  // Wishlist-specific methods
  Future<void> setWishlistIds(Set<String> ids) async {
    await init();
    await _prefs?.setStringList('wishlist_ids', ids.toList());
  }

  Future<Set<String>> getWishlistIds() async {
    await init();
    final ids = _prefs?.getStringList('wishlist_ids') ?? [];
    return Set<String>.from(ids);
  }

  Future<void> addToWishlistCache(String productId) async {
    final ids = await getWishlistIds();
    ids.add(productId);
    await setWishlistIds(ids);
  }

  Future<void> removeFromWishlistCache(String productId) async {
    final ids = await getWishlistIds();
    ids.remove(productId);
    await setWishlistIds(ids);
  }

  Future<void> clearWishlistCache() async {
    await init();
    await _prefs?.remove('wishlist_ids');
  }

  // Generic list cache
  Future<void> setListCache(
    String key,
    List<Map<String, dynamic>> data, {
    Duration? expiry,
  }) async {
    await init();

    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };

    await _prefs?.setString(key, jsonEncode(cacheData));
  }

  Future<List<Map<String, dynamic>>?> getListCache(String key) async {
    await init();

    final cachedString = _prefs?.getString(key);
    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiryMs = cacheData['expiry'] as int?;

      // Check if expired
      if (expiryMs != null) {
        final expiredAt = timestamp + expiryMs;
        if (DateTime.now().millisecondsSinceEpoch > expiredAt) {
          await clearCache(key);
          return null;
        }
      }

      return (cacheData['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      await clearCache(key);
      return null;
    }
  }
}
