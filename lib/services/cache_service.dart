import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _kCacheBoxName = 'api_cache';
  static const String _kWishlistKey = 'wishlist_ids';
  static const String _kRecentlyViewedKey = 'recently_viewed';
  static const int _kMaxRecentlyViewed = 10;

  Box? _cacheBox;

  Future<void> init() async {
    if (_cacheBox != null) return;
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox(_kCacheBoxName);
  }

  Future<Box> get _box async {
    await init();
    return _cacheBox!;
  }

  Future<T?> getCached<T>(String key) async {
    final box = await _box;
    final cached = box.get(key);
    if (cached == null) return null;

    if (cached is Map && cached.containsKey('timestamp') && cached.containsKey('data')) {
      final cachedAt = DateTime.parse(cached['timestamp']);
      final maxAgeMs = cached['maxAge'] as int?;

      if (maxAgeMs != null) {
        if (DateTime.now().difference(cachedAt).inMilliseconds > maxAgeMs) {
          await box.delete(key);
          return null;
        }
      }

      final dynamic data = cached['data'];

      if (data is T) return data;

      try {
        if (data is Map) {
          final casted = data.cast<String, dynamic>();
          if (casted is T) return casted as T;
        }
        if (data is List) {
          final casted = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
          if (casted is T) return casted as T;
        }
      } catch (_) {}

      try {
        return data as T;
      } catch (_) {
        return null;
      }
    }

    return cached as T?;
  }

  Future<void> setCache(String key, dynamic data, {Duration? expiry}) async {
    final box = await _box;
    await box.put(key, {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'maxAge': expiry?.inMilliseconds,
    });
  }

  Future<void> clearCache(String key) async {
    final box = await _box;
    await box.delete(key);
  }

  Future<Map<String, dynamic>?> getCache(String key) async {
    return await getCached<Map<String, dynamic>>(key);
  }

  Future<void> setListCache(String key, List<dynamic> data, {Duration? expiry}) async {
    await setCache(key, data, expiry: expiry);
  }

  Future<List<Map<String, dynamic>>?> getListCache(String key) async {
    final result = await getCached<List>(key);
    if (result == null) return null;
    return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> setWishlistIds(Set<String> ids) async {
    final box = await _box;
    await box.put(_kWishlistKey, ids.toList());
  }

  Future<Set<String>> getWishlistIds() async {
    final box = await _box;
    final ids = box.get(_kWishlistKey);
    if (ids == null) return {};
    return (ids as List).cast<String>().toSet();
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
    final box = await _box;
    await box.delete(_kWishlistKey);
  }

  Future<void> clearAllCache() async {
    final box = await _box;
    await box.clear();
  }

  Future<void> addRecentlyViewedProduct(Map<String, dynamic> product) async {
    final box = await _box;
    List<dynamic> current = box.get(_kRecentlyViewedKey, defaultValue: []);

    current.removeWhere((p) => p['id'] == product['id']);
    current.insert(0, product);

    if (current.length > _kMaxRecentlyViewed) {
      current = current.sublist(0, _kMaxRecentlyViewed);
    }

    await box.put(_kRecentlyViewedKey, current);
  }

  Future<List<Map<String, dynamic>>> getRecentlyViewedProducts() async {
    final box = await _box;
    final data = box.get(_kRecentlyViewedKey);
    if (data == null) return [];
    try {
      // Hive stores maps as LinkedHashMap, need to cast each item
      return (data as List).map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearRecentlyViewed() async {
    final box = await _box;
    await box.delete(_kRecentlyViewedKey);
  }
}
