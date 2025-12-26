import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'cache_service.dart';
import 'wishlist_service.dart';
import '../models/user_profile.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _kTokenKey = 'session_token';
  static const Duration _kNetworkTimeout = Duration(seconds: 15);

  final CacheService _cacheService = CacheService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final Dio _dio;
  bool _isInitialized = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  // ignore: close_sinks
  final _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateChanges => _authStateController.stream;

  UserProfile? _currentUserProfile;
  UserProfile? get currentUser => _currentUserProfile;

  String? get currentSession => _isAuthenticated ? 'session_active' : null;

  void _initDio() {
    if (_isInitialized) return;

    _dio = Dio(BaseOptions(
      connectTimeout: _kNetworkTimeout,
      receiveTimeout: _kNetworkTimeout,
      sendTimeout: _kNetworkTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _isInitialized = true;
    debugPrint('[Auth] Dio initialized');
  }

  Future<void> init() async {
    debugPrint('[Auth] Initializing...');
    _initDio();

    try {
      final token = await _secureStorage.read(key: _kTokenKey);
      debugPrint('[Auth] Stored token: ${token != null ? "exists (${token.length} chars)" : "null"}');

      if (token != null && token.isNotEmpty) {
        // Try to validate with server, but don't invalidate if network fails
        debugPrint('[Auth] Validating token with server...');
        try {
          final user = await checkSession();
          
          if (user != null) {
            _isAuthenticated = true;
            _currentUserProfile = user;
            _authStateController.add(true);
            debugPrint('[Auth] Session valid: ${user.email}');
          } else {
            debugPrint('[Auth] Session explicitly invalid, clearing token');
            await _secureStorage.delete(key: _kTokenKey);
            _isAuthenticated = false;
            _authStateController.add(false);
          }
        } catch (e) {
          // Network error during validation - trust the stored token
          debugPrint('[Auth] Network error during validation: $e - trusting stored token');
          _isAuthenticated = true;
          _authStateController.add(true);
        }
      } else {
        _isAuthenticated = false;
        _authStateController.add(false);
        debugPrint('[Auth] No token found');
      }
    } catch (e) {
      debugPrint('[Auth] Init error: $e');
      // On severe errors, check if we have a token and trust it
      try {
        final token = await _secureStorage.read(key: _kTokenKey);
        if (token != null && token.isNotEmpty) {
          _isAuthenticated = true;
          _authStateController.add(true);
          debugPrint('[Auth] Trusting stored token despite error');
        } else {
          _isAuthenticated = false;
          _authStateController.add(false);
        }
      } catch (_) {
        _isAuthenticated = false;
        _authStateController.add(false);
      }
    }
    debugPrint('[Auth] Init complete, isAuthenticated=$_isAuthenticated');
  }

  Future<void> ensureAuthenticated() async {
    if (_isAuthenticated) return;

    debugPrint('[Auth] ensureAuthenticated called');
    final token = await _secureStorage.read(key: _kTokenKey);

    if (token != null && token.isNotEmpty) {
      final user = await checkSession();
      if (user != null) {
        _isAuthenticated = true;
        _currentUserProfile = user;
        debugPrint('[Auth] Authenticated: ${user.email}');
        return;
      }
      debugPrint('[Auth] Token invalid, clearing');
      await _secureStorage.delete(key: _kTokenKey);
    }

    throw Exception('User is not authenticated');
  }

  Future<void> signInWithGoogle() async {
    debugPrint('[Auth] Starting Google Sign-In...');
    await _googleSignIn.signOut();

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('[Auth] Sign-in cancelled by user');
        throw Exception('Sign in cancelled');
      }
      debugPrint('[Auth] Account: ${account.email}');

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint('[Auth] No ID token received');
        throw Exception('Failed to get Google ID token');
      }
      debugPrint('[Auth] Got ID token (${idToken.length} chars)');

      final endpoint = '${ApiConfig.vercelUrl}/api/auth/mobile/google';
      debugPrint('[Auth] POST $endpoint');
      final response = await _dio.post(endpoint, data: {'idToken': idToken});
      debugPrint('[Auth] Response status: ${response.statusCode}');

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          debugPrint('[Auth] JSON decode error: $e');
          throw Exception('Invalid response format from server');
        }
      }

      if (data is! Map<String, dynamic>) {
        debugPrint('[Auth] Unexpected response type: ${data.runtimeType}');
        throw Exception('Invalid response format from server');
      }

      debugPrint('[Auth] Response: success=${data['success']}, hasData=${data['data'] != null}');

      if (data['success'] == true && data['data'] != null) {
        final responseData = data['data'];
        final sessionData = responseData['session'];
        final userData = responseData['user'];

        if (sessionData != null && sessionData['token'] != null) {
          final token = sessionData['token'] as String;

          await _secureStorage.write(key: _kTokenKey, value: token);
          debugPrint('[Auth] Token stored');

          _isAuthenticated = true;
          _authStateController.add(true);

          if (userData != null) {
            _currentUserProfile = UserProfile.fromJson(userData);
            debugPrint('[Auth] Profile: ${_currentUserProfile?.email}');
          }

          debugPrint('[Auth] Sign-in complete');
          return;
        }
      }

      final errorMessage = data['error'] ?? 'Failed to create session';
      debugPrint('[Auth] Backend error: $errorMessage');
      throw Exception(errorMessage);
    } on DioException catch (e) {
      debugPrint('[Auth] DioException: ${e.type} - ${e.message}');
      if (e.response != null) {
        debugPrint('[Auth] Status: ${e.response?.statusCode}, Data: ${e.response?.data}');
      }
      await _googleSignIn.signOut();

      String errorMessage = 'Network error during sign in';
      if (e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('[Auth] Sign-in error: $e');
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  Future<UserProfile?> checkSession() async {
    debugPrint('[Auth] Checking session...');
    final token = await _secureStorage.read(key: _kTokenKey);
    if (token == null || token.isEmpty) {
      debugPrint('[Auth] No token to validate');
      return null;
    }

    try {
      final endpoint = '${ApiConfig.vercelUrl}/api/auth/check';
      debugPrint('[Auth] GET $endpoint');

      final response = await _dio.get(
        endpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('[Auth] Response: ${response.statusCode}');
      final data = response.data;

      if (data['authenticated'] == true && data['user'] != null) {
        final user = UserProfile.fromJson(data['user']);
        debugPrint('[Auth] Session valid: ${user.email}');
        return user;
      }

      debugPrint('[Auth] Session response says not authenticated');
      return null;
    } on DioException catch (e) {
      debugPrint('[Auth] Session check DioException: ${e.type} - ${e.message}');
      // 401 or 403 means token is invalid - return null
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint('[Auth] Token rejected by server (${e.response?.statusCode})');
        return null;
      }
      // Network errors - rethrow so caller can decide to trust token
      debugPrint('[Auth] Network error - rethrowing for caller to handle');
      rethrow;
    }
  }

  Future<UserProfile> getProfile() async {
    debugPrint('[Auth] Getting profile...');
    final user = await checkSession();
    if (user != null) {
      _currentUserProfile = user;
      // Cache profile for offline access
      await _cacheProfile(user);
      return user;
    }
    throw Exception('Failed to get profile: Session invalid');
  }

  /// Get cached profile without network call - for offline mode
  Future<UserProfile?> getCachedProfile() async {
    // First check in-memory
    if (_currentUserProfile != null) {
      return _currentUserProfile;
    }
    // Try cache
    try {
      final cached = await _cacheService.getCached<dynamic>('user_profile');
      if (cached != null && cached is Map) {
        final profileMap = _deepConvertMap(cached);
        _currentUserProfile = UserProfile.fromJson(profileMap);
        return _currentUserProfile;
      }
    } catch (e) {
      debugPrint('[Auth] Error getting cached profile: $e');
    }
    return null;
  }

  /// Recursively convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _deepConvertMap(Map map) {
    return map.map((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        return MapEntry(stringKey, _deepConvertMap(value));
      } else if (value is List) {
        return MapEntry(stringKey, value.map((e) => e is Map ? _deepConvertMap(e) : e).toList());
      }
      return MapEntry(stringKey, value);
    });
  }

  /// Cache profile for offline access
  Future<void> _cacheProfile(UserProfile user) async {
    try {
      await _cacheService.setCache(
        'user_profile',
        user.toJson(),
        expiry: const Duration(days: 30), // Keep profile for 30 days
      );
    } catch (e) {
      debugPrint('[Auth] Error caching profile: $e');
    }
  }

  Future<void> signOut() async {
    debugPrint('[Auth] Signing out...');
    try {
      await _cacheService.clearAllCache();
      await WishlistService().clearCache();
      debugPrint('[Auth] Cache cleared');

      final token = await _secureStorage.read(key: _kTokenKey);
      if (token != null) {
        try {
          final endpoint = '${ApiConfig.vercelUrl}/api/auth/logout';
          debugPrint('[Auth] POST $endpoint');
          await _dio.post(
            endpoint,
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          debugPrint('[Auth] Server logout complete');
        } catch (e) {
          debugPrint('[Auth] Logout endpoint error: $e');
        }
      }

      await _secureStorage.delete(key: _kTokenKey);
      await _googleSignIn.signOut();
      _isAuthenticated = false;
      _authStateController.add(false);
      _currentUserProfile = null;
      debugPrint('[Auth] Sign-out complete');
    } catch (e) {
      debugPrint('[Auth] Sign-out error: $e');
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  Future<String?> getStoredToken() async {
    return await _secureStorage.read(key: _kTokenKey);
  }

  Future<bool> hasStoredToken() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> checkAuth() async {
    debugPrint('[Auth] Full auth check...');
    final user = await checkSession();
    if (user != null) {
      _currentUserProfile = user;
      _isAuthenticated = true;
      _authStateController.add(true);
      debugPrint('[Auth] Auth check passed');
      return true;
    }
    debugPrint('[Auth] Auth check failed, invalidating session');
    await invalidateSession();
    return false;
  }

  /// Called when API returns 401 to invalidate the local session
  Future<void> invalidateSession() async {
    debugPrint('[Auth] Invalidating session...');
    try {
      await _secureStorage.delete(key: _kTokenKey);
    } catch (_) {}
    _isAuthenticated = false;
    _authStateController.add(false);
    _currentUserProfile = null;
    debugPrint('[Auth] Session invalidated');
  }
}
