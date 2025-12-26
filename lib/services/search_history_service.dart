import 'cache_service.dart';

class SearchHistoryService {
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  static const String _kSearchHistoryKey = 'search_history';
  static const int _kMaxDisplayedItems = 5;
  static const int _kMaxStoredItems = 10;

  final CacheService _cacheService = CacheService();

  Future<List<String>> getSearchHistory() async {
    try {
      final history = await _cacheService.getCached<List>(_kSearchHistoryKey);
      if (history == null) return [];

      final casted = history.cast<String>();
      return casted.take(_kMaxDisplayedItems).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addSearchQuery(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    try {
      final historyRaw = await _cacheService.getCached<List>(_kSearchHistoryKey) ?? [];
      final history = historyRaw.cast<String>().toList();

      history.remove(trimmedQuery);
      history.insert(0, trimmedQuery);

      if (history.length > _kMaxStoredItems) {
        history.removeRange(_kMaxStoredItems, history.length);
      }

      await _cacheService.setCache(_kSearchHistoryKey, history);
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    await _cacheService.clearCache(_kSearchHistoryKey);
  }

  Future<void> removeSearchQuery(String query) async {
    try {
      final historyRaw = await _cacheService.getCached<List>(_kSearchHistoryKey) ?? [];
      final history = historyRaw.cast<String>().toList();
      history.remove(query);
      await _cacheService.setCache(_kSearchHistoryKey, history);
    } catch (_) {}
  }
}
