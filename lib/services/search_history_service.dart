import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static final SearchHistoryService _instance =
      SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  static const String _searchHistoryKey = 'search_history';
  static const int _maxDisplayedItems = 3;
  static const int _maxStoredItems = 10;

  Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];
      print('Raw search history: $history');
      final displayed = history.take(_maxDisplayedItems).toList();
      print('Displayed search history: $displayed');
      return displayed;
    } catch (e) {
      print('Error loading search history: $e');
      return [];
    }
  }

  Future<void> addSearchQuery(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];

      history.remove(trimmedQuery);
      history.insert(0, trimmedQuery);

      if (history.length > _maxStoredItems) {
        history.removeRange(_maxStoredItems, history.length);
      }

      await prefs.setStringList(_searchHistoryKey, history);
      print('Search query saved. Updated history: $history');
    } catch (e) {
      print('Error saving search query: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (_) {}
  }

  Future<void> removeSearchQuery(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];
      history.remove(query);
      await prefs.setStringList(_searchHistoryKey, history);
    } catch (_) {}
  }
}
