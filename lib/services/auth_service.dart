import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'wishlist_service.dart';
import '../models/user_profile.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _kTokenKey = 'session_token';

  final CacheService _cacheService = CacheService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final ApiClient _apiClient;
  bool _isInitialized = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  final _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateChanges => _authStateController.stream;

  UserProfile? _currentUserProfile;
  UserProfile? get currentUser => _currentUserProfile;

  String? get currentSession => _isAuthenticated ? 'session_active' : null;

  void _initApiClient() {
    if (_isInitialized) return;
    _apiClient = ApiClient();
    _isInitialized = true;
  }

  Future<void> init() async {
    _initApiClient();

    try {
      final token = await _secureStorage.read(key: _kTokenKey);

      if (token != null && token.isNotEmpty) {
        try {
          final user = await checkSession();
          
          if (user != null) {
            _isAuthenticated = true;
            _currentUserProfile = user;
            _authStateController.add(true);
          } else {
            await _secureStorage.delete(key: _kTokenKey);
            _isAuthenticated = false;
            _authStateController.add(false);
          }
        } catch (e) {
          debugPrint('[Auth] Network error during validation - trusting stored token');
          _isAuthenticated = true;
          _authStateController.add(true);
        }
      } else {
        _isAuthenticated = false;
        _authStateController.add(false);
      }
    } catch (e) {
      debugPrint('[Auth] Init error: $e');
      try {
        final token = await _secureStorage.read(key: _kTokenKey);
        if (token != null && token.isNotEmpty) {
          _isAuthenticated = true;
          _authStateController.add(true);
        } else {
          _isAuthenticated = false;
          _authStateController.add(false);
        }
      } catch (_) {
        _isAuthenticated = false;
        _authStateController.add(false);
      }
    }
  }

  Future<void> ensureAuthenticated() async {
    if (_isAuthenticated) return;

    final token = await _secureStorage.read(key: _kTokenKey);

    if (token != null && token.isNotEmpty) {
      final user = await checkSession();
      if (user != null) {
        _isAuthenticated = true;
        _currentUserProfile = user;
        return;
      }
      await _secureStorage.delete(key: _kTokenKey);
    }

    throw Exception('User is not authenticated');
  }

  Future<void> signInWithGoogle() async {
    _initApiClient();
    await _googleSignIn.signOut();

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        throw Exception('Sign in cancelled');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to get Google ID token');
      }

      final response = await _apiClient.dio.post(
        '${_apiClient.vercelBaseUrl}/auth/mobile/google',
        data: {'idToken': idToken},
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          throw Exception('Invalid response format from server');
        }
      }

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format from server');
      }

      if (data['success'] == true && data['data'] != null) {
        final responseData = data['data'];
        final sessionData = responseData['session'];
        final userData = responseData['user'];

        if (sessionData != null && sessionData['token'] != null) {
          final token = sessionData['token'] as String;

          await _secureStorage.write(key: _kTokenKey, value: token);

          _isAuthenticated = true;
          _authStateController.add(true);

          if (userData != null) {
            _currentUserProfile = UserProfile.fromJson(userData);
          }

          return;
        }
      }

      final errorMessage = data['error'] ?? 'Failed to create session';
      throw Exception(errorMessage);
    } on DioException catch (e) {
      debugPrint('[Auth] DioException: ${e.type} - ${e.message}');
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
    _initApiClient();
    final token = await _secureStorage.read(key: _kTokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/auth/check',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;

      if (data['authenticated'] == true && data['user'] != null) {
        return UserProfile.fromJson(data['user']);
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }

  Future<UserProfile> getProfile() async {
    final user = await checkSession();
    if (user != null) {
      _currentUserProfile = user;
      await _cacheProfile(user);
      return user;
    }
    throw Exception('Failed to get profile: Session invalid');
  }

  Future<UserProfile?> getCachedProfile() async {
    if (_currentUserProfile != null) return _currentUserProfile;
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

  Future<void> _cacheProfile(UserProfile user) async {
    try {
      await _cacheService.setCache(
        'user_profile',
        user.toJson(),
        expiry: const Duration(days: 30),
      );
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> signOut() async {
    _initApiClient();
    try {
      await _cacheService.clearAllCache();
      await WishlistService().clearCache();

      final token = await _secureStorage.read(key: _kTokenKey);
      if (token != null) {
        try {
          await _apiClient.dio.post(
            '${_apiClient.vercelBaseUrl}/auth/logout',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        } catch (e) {
          // Silent fail for logout endpoint
        }
      }

      await _secureStorage.delete(key: _kTokenKey);
      await _googleSignIn.signOut();
      _isAuthenticated = false;
      _authStateController.add(false);
      _currentUserProfile = null;
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
    final user = await checkSession();
    if (user != null) {
      _currentUserProfile = user;
      _isAuthenticated = true;
      _authStateController.add(true);
      return true;
    }
    await invalidateSession();
    return false;
  }

  Future<void> invalidateSession() async {
    try {
      await _secureStorage.delete(key: _kTokenKey);
    } catch (_) {}
    _isAuthenticated = false;
    _authStateController.add(false);
    _currentUserProfile = null;
  }
}
