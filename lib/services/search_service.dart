import '../config/api_config.dart';
import '../models/product.dart';
import 'api_client.dart';

class SearchResultPage {
  final List<Product> products;
  final int page;
  final int limit;
  final int? totalResults;
  final bool hasMore;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? appliedFilters;

  const SearchResultPage({
    required this.products,
    required this.page,
    required this.limit,
    required this.totalResults,
    required this.hasMore,
    this.metadata,
    this.appliedFilters,
  });
}

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<SearchResultPage> search({
    String? query,
    String? category,
    String? subcategory,
    String? color,
    String? sort,
    int page = 1,
    int limit = ApiConfig.defaultPageSize,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    if (subcategory != null && subcategory.isNotEmpty) {
      params['subcategory'] = subcategory;
    }
    if (color != null && color.isNotEmpty) {
      params['color'] = color;
    }
    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }

    try {
      final response = await _apiClient.get('/search', queryParams: params);
      return _parseUnifiedSearchResponse(response);
    } catch (e) {
      throw Exception('Failed to search products: ${e.toString()}');
    }
  }

  Future<SearchResultPage> browseCategory({
    required String category,
    String? subcategory,
    String? color,
    String? sort,
    int page = 1,
    int limit = ApiConfig.defaultPageSize,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (subcategory != null && subcategory.isNotEmpty) {
      params['subcategory'] = subcategory;
    }
    if (color != null && color.isNotEmpty) {
      params['color'] = color;
    }
    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }

    try {
      final encoded = Uri.encodeComponent(category);
      final response = await _apiClient.get(
        '/products/browse/$encoded',
        queryParams: params,
      );

      final root = response['data'] ?? response;

      final productsPayload =
          (root['products'] is List) ? (root['products'] as List) : <dynamic>[];

      final products = productsPayload
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();

      final metadata = <String, dynamic>{};
      if (root['banners'] is List) {
        metadata['banners'] = root['banners'];
      }
      final appliedFilters =
          (root['appliedFilters'] ?? root['filters']) as Map<String, dynamic>?;

      final resolvedPage = _parseInt(root['page']) ?? _parseInt(response['page']) ?? page;
      final resolvedLimit = _parseInt(root['limit']) ?? _parseInt(response['limit']) ?? limit;
      final total = _parseInt(root['total']) ?? _parseInt(response['total']);

      final hasMore = _inferHasMore(
        metadata: metadata,
        page: resolvedPage,
        limit: resolvedLimit,
        total: total,
      );

      return SearchResultPage(
        products: products,
        page: resolvedPage,
        limit: resolvedLimit,
        totalResults: total,
        hasMore: hasMore,
        metadata: metadata.isEmpty ? null : metadata,
        appliedFilters: appliedFilters,
      );
    } catch (e) {
      throw Exception('Failed to browse category: ${e.toString()}');
    }
  }

  Future<SearchResultPage> searchProducts({
    required String query,
    int page = 1,
    int limit = ApiConfig.defaultPageSize,
    String? sort,
    Map<String, dynamic>? filters,
  }) async {
    if (query.trim().isEmpty) {
      return const SearchResultPage(
        products: [],
        page: 1,
        limit: ApiConfig.defaultPageSize,
        totalResults: 0,
        hasMore: false,
      );
    }

    final params = <String, String>{
      'query': query,
      'q': query,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }

    filters?.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        params[key] = value.map((item) => item.toString()).join(',');
      } else {
        params[key] = value.toString();
      }
    });

    try {
      final response = await _apiClient.get('/search', queryParams: params);
      return _parseSearchResponse(response);
    } catch (e) {
      throw Exception('Failed to search products: ${e.toString()}');
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _apiClient.get(
        '/search/suggestions',
        queryParams: {'query': query, 'q': query},
      );

      final data = response['data'] ?? response['suggestions'] ?? response;

      if (data is List) {
        return data
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
      }

      if (data is Map<String, dynamic>) {
        final suggestions = data['suggestions'] ?? data['results'];
        if (suggestions is List) {
          return suggestions
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch suggestions: ${e.toString()}');
    }
  }

  SearchResultPage _parseSearchResponse(Map<String, dynamic> response) {
    final dynamic rootData =
        response['data'] ?? response['results'] ?? response['products'];

    final extraction = _extractProductList(rootData, fallback: response);
    final productsPayload = extraction.productsPayload;
    final metadata = extraction.metadata;

    final products = productsPayload
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();

    final page =
        _parseInt(
          metadata['page'] ??
              metadata['current_page'] ??
              metadata['pageNumber'] ??
              metadata['currentPage'] ??
              response['page'],
        ) ??
        1;

    final limit =
        _parseInt(
          metadata['limit'] ??
              metadata['per_page'] ??
              metadata['page_size'] ??
              metadata['pageSize'] ??
              response['limit'],
        ) ??
        ApiConfig.defaultPageSize;

    final total = _parseInt(
      metadata['total'] ??
          metadata['total_results'] ??
          metadata['totalCount'] ??
          metadata['count'] ??
          metadata['total_items'] ??
          metadata['totalItems'] ??
          response['total'],
    );

    final hasMore = _inferHasMore(
      metadata: metadata,
      page: page,
      limit: limit,
      total: total,
    );

    return SearchResultPage(
      products: products,
      page: page,
      limit: limit,
      totalResults: total,
      hasMore: hasMore,
      metadata: metadata.isEmpty ? null : metadata,
    );
  }

  SearchResultPage _parseUnifiedSearchResponse(Map<String, dynamic> response) {
    final dynamic rootData =
        response['data'] ?? response['results'] ?? response['products'];

    final extraction = _extractProductList(rootData, fallback: response);
    final productsPayload = extraction.productsPayload;
    final metadata = extraction.metadata;

    final products = productsPayload
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();

    Map<String, dynamic>? appliedFilters;
    List<dynamic>? banners;

    if (rootData is Map<String, dynamic>) {
      appliedFilters = rootData['filters'] as Map<String, dynamic>?;
      banners = rootData['banners'] as List<dynamic>?;
    }
    appliedFilters ??= response['filters'] as Map<String, dynamic>?;
    banners ??= response['banners'] as List<dynamic>?;

    final page =
        _parseInt(
          metadata['page'] ??
              metadata['current_page'] ??
              metadata['pageNumber'] ??
              metadata['currentPage'] ??
              response['page'],
        ) ??
        1;

    final limit =
        _parseInt(
          metadata['limit'] ??
              metadata['per_page'] ??
              metadata['page_size'] ??
              metadata['pageSize'] ??
              response['limit'],
        ) ??
        ApiConfig.defaultPageSize;

    final total = _parseInt(
      metadata['total'] ??
          metadata['total_results'] ??
          metadata['totalCount'] ??
          metadata['count'] ??
          metadata['total_items'] ??
          metadata['totalItems'] ??
          response['total'],
    );

    final hasMore = _inferHasMore(
      metadata: metadata,
      page: page,
      limit: limit,
      total: total,
    );

    if (banners != null && banners.isNotEmpty) {
      metadata['banners'] = banners;
    }
    if (response['searchMode'] != null) {
      metadata['searchMode'] = response['searchMode'];
    }

    return SearchResultPage(
      products: products,
      page: page,
      limit: limit,
      totalResults: total,
      hasMore: hasMore,
      metadata: metadata.isEmpty ? null : metadata,
      appliedFilters: appliedFilters,
    );
  }

  _ProductExtraction _extractProductList(
    dynamic data, {
    required Map<String, dynamic> fallback,
  }) {
    final metadata = <String, dynamic>{};
    dynamic payload = data;

    if (fallback['meta'] is Map<String, dynamic>) {
      metadata.addAll(fallback['meta'] as Map<String, dynamic>);
    }

    if (data is Map<String, dynamic>) {
      if (data['meta'] is Map<String, dynamic>) {
        metadata.addAll(data['meta'] as Map<String, dynamic>);
      }
      if (data['pagination'] is Map<String, dynamic>) {
        metadata.addAll(data['pagination'] as Map<String, dynamic>);
      }

      payload = _firstList(data);

      if (payload == null) {
        for (final value in data.values) {
          if (value is Map<String, dynamic>) {
            final nested = _firstList(value);
            if (nested != null) {
              payload = nested;
              if (value['meta'] is Map<String, dynamic>) {
                metadata.addAll(value['meta'] as Map<String, dynamic>);
              }
              if (value['pagination'] is Map<String, dynamic>) {
                metadata.addAll(value['pagination'] as Map<String, dynamic>);
              }
              break;
            }
          }
        }
      }
    }

    payload ??= _firstList(fallback) ?? <dynamic>[];

    if (payload is Map<String, dynamic>) {
      payload = _firstList(payload) ?? <dynamic>[];
    }

    return _ProductExtraction(
      productsPayload: payload is List ? payload : <dynamic>[],
      metadata: metadata,
    );
  }

  List<dynamic>? _firstList(Map<String, dynamic> source) {
    for (final entry in source.entries) {
      if (entry.value is List) {
        return entry.value as List<dynamic>;
      }
    }
    return null;
  }

  bool _inferHasMore({
    required Map<String, dynamic> metadata,
    required int page,
    required int limit,
    required int? total,
  }) {
    final direct = metadata['has_more'] ?? metadata['hasMore'];
    if (direct is bool) return direct;
    if (direct is String) {
      if (direct.toLowerCase() == 'true') return true;
      if (direct.toLowerCase() == 'false') return false;
    }

    if (metadata.containsKey('next_page') || metadata.containsKey('nextPage')) {
      return metadata['next_page'] != null || metadata['nextPage'] != null;
    }

    if (total != null && limit > 0) {
      return page * limit < total;
    }

    return false;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class _ProductExtraction {
  final List<dynamic> productsPayload;
  final Map<String, dynamic> metadata;

  const _ProductExtraction({
    required this.productsPayload,
    required this.metadata,
  });
}
