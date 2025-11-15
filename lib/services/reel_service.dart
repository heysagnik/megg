import '../models/reel.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ReelService {
  static final ReelService _instance = ReelService._internal();
  factory ReelService() => _instance;
  ReelService._internal();

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  Future<List<Reel>> getReels({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        '/reels',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
      );

      if (response['data'] != null) {
        return (response['data'] as List)
            .map((json) => Reel.fromJson(json))
            .toList();
      } else if (response['reels'] != null) {
        return (response['reels'] as List)
            .map((json) => Reel.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch reels: ${e.toString()}');
    }
  }

  Future<List<Reel>> getReelsByCategory(String category) async {
    try {
      final response = await _apiClient.get('/reels/category/$category');

      if (response['data'] != null) {
        return (response['data'] as List)
            .map((json) => Reel.fromJson(json))
            .toList();
      } else if (response['reels'] != null) {
        return (response['reels'] as List)
            .map((json) => Reel.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch category reels: ${e.toString()}');
    }
  }

  Future<Reel> getReelDetails(String reelId) async {
    try {
      final response = await _apiClient.get('/reels/$reelId');
      final data = response['data'] ?? response['reel'];
      return Reel.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch reel details: ${e.toString()}');
    }
  }

  Future<void> incrementViews(String reelId) async {
    try {
      await _apiClient.post('/reels/$reelId/view');
    } catch (e) {}
  }

  Future<void> toggleLike(String reelId, {required bool like}) async {
    try {
      await _authService.ensureAuthenticated();

      await _apiClient.post(
        '/reels/$reelId/like',
        body: like ? null : {'like': false},
        requiresAuth: true,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Reel>> getLikedReels() async {
    try {
      await _authService.ensureAuthenticated();

      final response = await _apiClient.get('/reels/liked', requiresAuth: true);

      if (response['data'] != null) {
        return (response['data'] as List)
            .map((json) => Reel.fromJson(json))
            .toList();
      } else if (response['reels'] != null) {
        return (response['reels'] as List)
            .map((json) => Reel.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch liked reels: ${e.toString()}');
    }
  }

  Future<Set<String>> getLikedReelIds() async {
    try {
      final likedReels = await getLikedReels();
      return likedReels.map((reel) => reel.id).toSet();
    } catch (e) {
      return {};
    }
  }

  @Deprecated('Use toggleLike instead')
  Future<void> likeReel(String reelId) async {
    await toggleLike(reelId, like: true);
  }

  Future<Map<String, dynamic>> createReel(Map<String, dynamic> reelData) async {
    try {
      await _authService.ensureAuthenticated();

      final response = await _apiClient.post(
        '/reels',
        body: reelData,
        requiresAuth: true,
      );

      return response['reel'] ?? {};
    } catch (e) {
      throw Exception('Failed to create reel: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateReel(
    String reelId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _authService.ensureAuthenticated();

      final response = await _apiClient.put(
        '/reels/$reelId',
        body: updates,
        requiresAuth: true,
      );

      return response['reel'] ?? {};
    } catch (e) {
      throw Exception('Failed to update reel: ${e.toString()}');
    }
  }

  Future<void> deleteReel(String reelId) async {
    try {
      await _authService.ensureAuthenticated();

      await _apiClient.delete('/reels/$reelId', requiresAuth: true);
    } catch (e) {
      throw Exception('Failed to delete reel: ${e.toString()}');
    }
  }
}
