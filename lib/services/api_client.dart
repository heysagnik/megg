import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const String _kTokenKey = 'session_token';

  late Dio _dio;
  late CacheOptions _cacheOptions;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiClient._internal() {
    _initDio();
  }

  void _initDio() {
    _cacheOptions = CacheOptions(
      store: MemCacheStore(),
      policy: CachePolicy.request,
      maxStale: const Duration(minutes: 15),
      priority: CachePriority.normal,
      cipher: null,
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
      allowPostMethod: false,
    );

    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectionTimeout,
      receiveTimeout: ApiConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
      },
    ));

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.idleTimeout = const Duration(seconds: 30);
        return client;
      },
    );

    _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));


    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final requiresAuth = options.extra['requiresAuth'] ?? false;
        if (requiresAuth) {
          final token = await _secureStorage.read(key: _kTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        debugPrint('[API] ERROR: ${error.requestOptions.method} $path -> ${error.response?.statusCode}');
        
        if (error.response?.statusCode == 401) {
          final isAuthEndpoint = path.contains('/auth/');
          if (isAuthEndpoint) {
            debugPrint('[API] 401 on auth endpoint - invalidating session');
            await AuthService().invalidateSession();
          } else {
            debugPrint('[API] 401 on non-auth endpoint ($path) - NOT invalidating session');
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  String get vercelBaseUrl => '${ApiConfig.vercelUrl}/api';

  Future<dynamic> _retryRequest(
    Future<dynamic> Function() request, {
    int retries = 3,
    String? context,
  }) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await request();
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final isLastAttempt = i == retries - 1;

        if (isLastAttempt) {
          rethrow;
        }

        final shouldRetry = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            (statusCode != null && (statusCode == 429 || statusCode >= 500));

        if (!shouldRetry) {
          rethrow;
        }

        final delay = Duration(milliseconds: 500 * (1 << i));
        await Future.delayed(delay);
      }
    }
    throw Exception('Unreachable');
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = false,
    bool forceRefresh = false,
  }) async {
    final context = 'GET $endpoint';

    return _retryRequest(
      () async {
        Options? options;
        if (forceRefresh) {
          options = _cacheOptions.copyWith(policy: CachePolicy.refresh).toOptions();
        }
        options ??= Options();
        options.extra = {'requiresAuth': requiresAuth};

        final response = await _dio.get(
          endpoint,
          queryParameters: queryParams,
          options: options,
        );
        return response.data;
      },
      context: context,
    ).catchError((e) {
      if (e is DioException) throw _handleError(e, context);
      throw e;
    });
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
  }) async {
    final context = 'POST $endpoint';

    try {
      final response = await _dio.post(
        endpoint,
        data: body,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e, context);
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
  }) async {
    final context = 'PUT $endpoint';

    try {
      final response = await _dio.put(
        endpoint,
        data: body,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e, context);
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final context = 'DELETE $endpoint';

    try {
      final response = await _dio.delete(
        endpoint,
        options: Options(extra: {'requiresAuth': requiresAuth}),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e, context);
    }
  }

  Exception _handleError(DioException error, String context) {
    String errorMessage = 'Request failed';

    if (error.response?.data != null) {
      try {
        final data = error.response?.data;
        if (data is Map) {
          errorMessage = data['error'] ?? data['message'] ?? errorMessage;
        } else {
          errorMessage = data.toString();
        }
      } catch (_) {}
    } else {
      errorMessage = error.message ?? errorMessage;
    }

    final statusCode = error.response?.statusCode;

    switch (statusCode) {
      case 401:
        return UnauthorizedException(errorMessage);
      case 403:
        return ForbiddenException(errorMessage);
      case 404:
        return NotFoundException(errorMessage);
      case 429:
        return RateLimitException('Too many requests. Please try again later.');
      default:
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return NetworkException('Connection timed out. Please check your internet.');
        }
        if (error.type == DioExceptionType.connectionError) {
          return NetworkException('No internet connection.');
        }
        return ApiException('Request failed ($statusCode): $errorMessage');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message);
}

class ForbiddenException extends ApiException {
  ForbiddenException(super.message);
}

class NotFoundException extends ApiException {
  NotFoundException(super.message);
}

class RateLimitException extends ApiException {
  RateLimitException(super.message);
}

class NetworkException extends ApiException {
  NetworkException(super.message);
}
