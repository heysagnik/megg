import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'wishlist_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiClient _apiClient = ApiClient();
  final CacheService _cacheService = CacheService();

  static const String _tokenKey = 'supabase_access_token';
  static const String _refreshTokenKey = 'supabase_refresh_token';
  static const String _userIdKey = 'user_id';

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => _supabase.auth.currentSession != null;
  Session? get currentSession => _supabase.auth.currentSession;
  String? get accessToken => _supabase.auth.currentSession?.accessToken;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<bool> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.megg://login-callback',
      );

      return response;
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  Future<void> syncWithBackend() async {
    try {
      final token = accessToken;

      if (token == null) {
        return;
      }

      await _apiClient.post('/auth/google', body: {'token': token});

      await _storeTokens();
    } catch (e) {
      throw Exception('Backend sync failed: ${e.toString()}');
    }
  }

  Future<void> _storeTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final session = currentSession;

      if (session != null) {
        await prefs.setString(_tokenKey, session.accessToken);
        if (session.refreshToken != null) {
          await prefs.setString(_refreshTokenKey, session.refreshToken!);
        }
        if (currentUser?.id != null) {
          await prefs.setString(_userIdKey, currentUser!.id);
        }
      }
    } catch (e) {}
  }

  Future<void> _clearStoredTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
    } catch (e) {}
  }

  Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      return await _apiClient.get('/auth/profile', requiresAuth: true);
    } catch (e) {
      if (_isAuthError(e)) {
        await refreshSession();
        return await _apiClient.get('/auth/profile', requiresAuth: true);
      }
      throw Exception('Failed to get profile: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> updates,
  ) async {
    try {
      return await _apiClient.put(
        '/auth/profile',
        body: updates,
        requiresAuth: true,
      );
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _cacheService.clearAllCache();
      await WishlistService().clearCache();
      await _clearStoredTokens();
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  void setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn && event.session != null) {
        await _storeTokens();
        await syncWithBackend();
      } else if (event.event == AuthChangeEvent.signedOut) {
        await _clearStoredTokens();
        await _cacheService.clearAllCache();
      } else if (event.event == AuthChangeEvent.tokenRefreshed) {
        await _storeTokens();
      }
    });
  }

  Future<void> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();

      if (response.session != null) {
        await _storeTokens();
      } else {}
    } catch (e) {
      throw Exception('Session refresh failed: ${e.toString()}');
    }
  }

  Future<void> ensureAuthenticated() async {
    if (!isAuthenticated) {
      throw Exception('User is not authenticated');
    }

    final session = currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    if (session.expiresAt != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        session.expiresAt! * 1000,
      );
      final now = DateTime.now();

      if (expiresAt.isBefore(now)) {
        await refreshSession();
      } else if (expiresAt.difference(now).inMinutes < 5) {
        await refreshSession();
      }
    }
  }

  bool _isAuthError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('unauthorized') ||
        errorString.contains('401') ||
        errorString.contains('invalid token') ||
        errorString.contains('expired token');
  }

  Future<Map<String, dynamic>> getAuthStatus() async {
    final user = currentUser;
    final session = currentSession;
    final token = accessToken;

    final status = {
      'isAuthenticated': isAuthenticated,
      'hasUser': user != null,
      'hasSession': session != null,
      'hasToken': token != null,
      'userEmail': user?.email,
      'userId': user?.id,
      'tokenLength': token?.length,
    };

    if (session?.expiresAt != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        session!.expiresAt! * 1000,
      );
      final now = DateTime.now();
      status['tokenExpiresAt'] = expiresAt.toIso8601String();
      status['tokenExpired'] = expiresAt.isBefore(now);
      status['tokenExpiresInMinutes'] = expiresAt.difference(now).inMinutes;
    }

    return status;
  }

  Future<bool> testAuthentication() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      await ensureAuthenticated();
      await getProfile();
      return true;
    } catch (e) {
      return false;
    }
  }
}
