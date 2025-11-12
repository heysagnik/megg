import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    _initHttpClient();
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  late http.Client _httpClient;
  // Debug logging removed for clean auth system

  void _initHttpClient() {
    _httpClient = http.Client();

    HttpOverrides.global = _DevHttpOverrides();
  }

  http.Client get httpClient => _httpClient;

  Future<String?> _getAccessToken() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session == null) {
        return null;
      }

      final token = session.accessToken;

      if (token.isEmpty) {
        return null;
      }

      // Validate token expiration
      final isExpired = session.isExpired;
      if (isExpired) {
        final refreshedSession = await _supabase.auth.refreshSession();
        if (refreshedSession.session != null) {
          return refreshedSession.session!.accessToken;
        }
        return null;
      }

      return token;
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _getHeaders({
    String? accessToken,
    bool isMultipart = false,
  }) {
    final headers = <String, String>{};

    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }

    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = false,
  }) async {
    try {
      String? token;
      if (requiresAuth) {
        token = await _getAccessToken();
        if (token == null) {
          throw Exception('Not authenticated');
        }
      }

      final uri = Uri.parse(
        '${ApiConfig.apiBaseUrl}$endpoint',
      ).replace(queryParameters: queryParams);

      final response = await _httpClient
          .get(uri, headers: _getHeaders(accessToken: token))
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      String? token;
      if (requiresAuth) {
        token = await _getAccessToken();
        if (token == null) {
          throw Exception('Not authenticated');
        }
      }

      final uri = Uri.parse('${ApiConfig.apiBaseUrl}$endpoint');

      final response = await _httpClient
          .post(
            uri,
            headers: _getHeaders(accessToken: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      String? token;
      if (requiresAuth) {
        token = await _getAccessToken();
        if (token == null) {
          throw Exception('Not authenticated');
        }
      }

      final uri = Uri.parse('${ApiConfig.apiBaseUrl}$endpoint');
      final response = await _httpClient
          .put(
            uri,
            headers: _getHeaders(accessToken: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      String? token;
      if (requiresAuth) {
        token = await _getAccessToken();
        if (token == null) {
          throw Exception('Not authenticated');
        }
      }

      final uri = Uri.parse('${ApiConfig.apiBaseUrl}$endpoint');
      final response = await _httpClient
          .delete(uri, headers: _getHeaders(accessToken: token))
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      return jsonDecode(response.body);
    }

    String errorMessage = 'Request failed';
    try {
      final errorBody = jsonDecode(response.body);
      errorMessage = errorBody['error'] ?? errorBody['message'] ?? errorMessage;
    } catch (_) {
      errorMessage = response.body;
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(errorMessage);
    }

    if (response.statusCode == 403) {
      throw ForbiddenException(errorMessage);
    }

    if (response.statusCode == 404) {
      throw NotFoundException(errorMessage);
    }

    throw ApiException(
      'Request failed (${response.statusCode}): $errorMessage',
    );
  }

  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return ApiException('Network error: ${error.toString()}');
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

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
