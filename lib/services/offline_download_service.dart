import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Download status enum
enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
}

/// Progress info for UI
class DownloadProgress {
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final int colorCombosDownloaded;
  final int colorCombosTotal;
  final int reelsDownloaded;
  final int reelsTotal;
  final String currentItem;
  final DownloadStatus status;
  final String? errorMessage;

  const DownloadProgress({
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.colorCombosDownloaded = 0,
    this.colorCombosTotal = 0,
    this.reelsDownloaded = 0,
    this.reelsTotal = 0,
    this.currentItem = '',
    this.status = DownloadStatus.idle,
    this.errorMessage,
  });

  DownloadProgress copyWith({
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    int? colorCombosDownloaded,
    int? colorCombosTotal,
    int? reelsDownloaded,
    int? reelsTotal,
    String? currentItem,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadProgress(
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      colorCombosDownloaded: colorCombosDownloaded ?? this.colorCombosDownloaded,
      colorCombosTotal: colorCombosTotal ?? this.colorCombosTotal,
      reelsDownloaded: reelsDownloaded ?? this.reelsDownloaded,
      reelsTotal: reelsTotal ?? this.reelsTotal,
      currentItem: currentItem ?? this.currentItem,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  String get downloadedMB => '${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  String get totalMB => '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Offline Download Service
/// Manages downloading color combos and reels for offline viewing.
class OfflineDownloadService extends ChangeNotifier {
  static final OfflineDownloadService _instance = OfflineDownloadService._internal();
  factory OfflineDownloadService() => _instance;
  OfflineDownloadService._internal();

  static const String _kOfflineEnabledKey = 'offline_mode_enabled';
  static const String _kDownloadCompleteKey = 'offline_download_complete';
  static const String _kFirstSignInPromptShownKey = 'offline_first_prompt_shown';
  static const int _kReelsPageSize = 10;

  final ApiClient _apiClient = ApiClient();
  // Separate Dio for file downloads (needs longer timeouts)
  final Dio _downloadDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  DownloadProgress _progress = const DownloadProgress();
  CancelToken? _cancelToken;
  bool _isInitialized = false;

  /// Current download progress
  DownloadProgress get progress => _progress;

  /// Whether offline mode is enabled
  bool get isOfflineModeEnabled => _progress.status == DownloadStatus.completed;

  /// Whether download is in progress
  bool get isDownloading => _progress.status == DownloadStatus.downloading;

  /// Initialize service
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final prefs = await SharedPreferences.getInstance();
    final isComplete = prefs.getBool(_kDownloadCompleteKey) ?? false;

    if (isComplete) {
      _progress = _progress.copyWith(status: DownloadStatus.completed);
      notifyListeners();
    }
  }

  /// Check if first sign-in prompt should be shown
  Future<bool> shouldShowFirstSignInPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kFirstSignInPromptShownKey) ?? false);
  }

  /// Mark first sign-in prompt as shown
  Future<void> markFirstSignInPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFirstSignInPromptShownKey, true);
  }

  /// Get offline directory path
  Future<Directory> _getOfflineDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${appDir.path}/offline');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  /// Get color combos directory
  Future<Directory> _getColorCombosDirectory() async {
    final offlineDir = await _getOfflineDirectory();
    final combosDir = Directory('${offlineDir.path}/color-combos');
    if (!await combosDir.exists()) {
      await combosDir.create(recursive: true);
    }
    return combosDir;
  }

  /// Get reels directory
  Future<Directory> _getReelsDirectory() async {
    final offlineDir = await _getOfflineDirectory();
    final reelsDir = Directory('${offlineDir.path}/reels');
    if (!await reelsDir.exists()) {
      await reelsDir.create(recursive: true);
    }
    return reelsDir;
  }

  /// Start downloading all offline content
  Future<void> startDownload() async {
    if (_progress.status == DownloadStatus.downloading) return;

    _cancelToken = CancelToken();
    _progress = _progress.copyWith(
      status: DownloadStatus.downloading,
      progress: 0.0,
      downloadedBytes: 0,
      currentItem: 'Preparing...',
    );
    notifyListeners();

    try {
      // Phase 1: Download color combos
      await _downloadColorCombos();

      if (_cancelToken?.isCancelled ?? false) return;

      // Phase 2: Download reels
      await _downloadReels();

      if (_cancelToken?.isCancelled ?? false) return;

      // Mark complete
      _progress = _progress.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        currentItem: 'Complete',
      );
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDownloadCompleteKey, true);
      await prefs.setBool(_kOfflineEnabledKey, true);

      debugPrint('[Offline] Download complete!');
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _progress = _progress.copyWith(
          status: DownloadStatus.idle,
          currentItem: 'Cancelled',
        );
      } else {
        debugPrint('[Offline] Download error: $e');
        _progress = _progress.copyWith(
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        );
      }
      notifyListeners();
    }
  }

  /// Download all color combos and their images
  Future<void> _downloadColorCombos() async {
    _progress = _progress.copyWith(currentItem: 'Fetching color combos...');
    notifyListeners();

    // Fetch color combos JSON
    final response = await _apiClient.dio.get(
      '${_apiClient.vercelBaseUrl}/color-combos',
      cancelToken: _cancelToken,
    );

    final data = response.data['data'] as List;
    final combosDir = await _getColorCombosDirectory();

    // Save metadata as proper JSON
    final metadataFile = File('${combosDir.path}/metadata.json');
    await metadataFile.writeAsString(jsonEncode(response.data));

    _progress = _progress.copyWith(colorCombosTotal: data.length);
    notifyListeners();

    // Download each model image
    for (int i = 0; i < data.length; i++) {
      if (_cancelToken?.isCancelled ?? false) return;

      final combo = data[i];
      final id = combo['id'] as String;
      final modelImageRaw = combo['model_image'] as String?;

      // Parse the model_image JSON to get the actual image URL
      String? modelImageUrl;
      if (modelImageRaw != null && modelImageRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(modelImageRaw);
          if (parsed is Map) {
            // Prefer 'large' size for offline, fall back to 'medium' or 'thumb'
            modelImageUrl = parsed['large'] ?? parsed['medium'] ?? parsed['thumb'];
          }
        } catch (_) {
          // If parsing fails, assume it's a direct URL (legacy format)
          modelImageUrl = modelImageRaw;
        }
      }

      if (modelImageUrl != null && modelImageUrl.isNotEmpty) {
        _progress = _progress.copyWith(
          currentItem: 'Combo ${i + 1}/${data.length}',
          colorCombosDownloaded: i,
        );
        notifyListeners();

        try {
          final extension = modelImageUrl.contains('.webp') ? 'webp' : 'jpg';
          final imagePath = '${combosDir.path}/${id}_model.$extension';

          await _downloadDio.download(
            modelImageUrl,
            imagePath,
            cancelToken: _cancelToken,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                _progress = _progress.copyWith(
                  downloadedBytes: _progress.downloadedBytes + received,
                );
              }
            },
          );
        } catch (e) {
          // Continue with next image
        }
      }

      _progress = _progress.copyWith(colorCombosDownloaded: i + 1);
      notifyListeners();
    }
  }

  /// Download all reels (paginated)
  Future<void> _downloadReels() async {
    _progress = _progress.copyWith(currentItem: 'Fetching reels...');
    notifyListeners();

    final reelsDir = await _getReelsDirectory();
    List<dynamic> allReels = [];

    // First, get total count
    final firstResponse = await _apiClient.dio.get(
      '${_apiClient.vercelBaseUrl}/reels',
      queryParameters: {'limit': _kReelsPageSize, 'page': 1},
      cancelToken: _cancelToken,
    );

    final pagination = firstResponse.data['pagination'];
    final totalReels = pagination['total'] as int;
    final totalPages = pagination['totalPages'] as int;

    _progress = _progress.copyWith(
      reelsTotal: totalReels,
      totalBytes: totalReels * 8 * 1024 * 1024, // Estimate ~8MB per reel
    );
    notifyListeners();

    // Add first page data
    allReels.addAll(firstResponse.data['data'] as List);

    // Fetch remaining pages
    for (int page = 2; page <= totalPages; page++) {
      if (_cancelToken?.isCancelled ?? false) return;

      final response = await _apiClient.dio.get(
        '${_apiClient.vercelBaseUrl}/reels',
        queryParameters: {'limit': _kReelsPageSize, 'page': page},
        cancelToken: _cancelToken,
      );
      allReels.addAll(response.data['data'] as List);
    }

    // Save metadata as proper JSON
    final metadataFile = File('${reelsDir.path}/metadata.json');
    await metadataFile.writeAsString(jsonEncode(allReels));

    // Download each reel video and thumbnail
    for (int i = 0; i < allReels.length; i++) {
      if (_cancelToken?.isCancelled ?? false) return;

      final reel = allReels[i];
      final id = reel['id'] as String;
      final videoUrl = reel['video_url'] as String?;
      final thumbnailUrl = reel['thumbnail_url'] as String?;

      _progress = _progress.copyWith(
        currentItem: 'Reel ${i + 1}/${allReels.length}',
        reelsDownloaded: i,
        progress: (i / allReels.length) * 0.9 + 0.1, // 10-100%
      );
      notifyListeners();

      // Download video
      if (videoUrl != null && videoUrl.isNotEmpty) {
        try {
          final videoPath = '${reelsDir.path}/${id}_video.mp4';
          
          await _downloadDio.download(
            videoUrl,
            videoPath,
            cancelToken: _cancelToken,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                final itemProgress = received / total;
                _progress = _progress.copyWith(
                  downloadedBytes: (i * 8 * 1024 * 1024) + (itemProgress * 8 * 1024 * 1024).toInt(),
                );
                notifyListeners();
              }
            },
          );
        } catch (e) {
          // Continue with next reel
        }
      }

      // Download thumbnail
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        try {
          final thumbPath = '${reelsDir.path}/${id}_thumb.jpg';
          await _downloadDio.download(
            thumbnailUrl,
            thumbPath,
            cancelToken: _cancelToken,
          );
        } catch (e) {
          // Continue with next thumbnail
        }
      }

      _progress = _progress.copyWith(reelsDownloaded: i + 1);
      notifyListeners();
    }
  }

  /// Cancel ongoing download
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _progress = _progress.copyWith(
      status: DownloadStatus.idle,
      currentItem: 'Cancelled',
    );
    notifyListeners();
  }

  /// Clear all offline data
  Future<void> clearOfflineData() async {
    cancelDownload();

    try {
      final offlineDir = await _getOfflineDirectory();
      if (await offlineDir.exists()) {
        await offlineDir.delete(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDownloadCompleteKey);
      await prefs.remove(_kOfflineEnabledKey);

      _progress = const DownloadProgress();
      notifyListeners();

      debugPrint('[Offline] Cleared all offline data');
    } catch (e) {
      debugPrint('[Offline] Error clearing data: $e');
    }
  }

  /// Get local path for a color combo image
  Future<String?> getLocalComboImagePath(String comboId) async {
    if (_progress.status != DownloadStatus.completed) return null;

    final combosDir = await _getColorCombosDirectory();
    final webpPath = '${combosDir.path}/${comboId}_model.webp';
    final jpgPath = '${combosDir.path}/${comboId}_model.jpg';

    if (await File(webpPath).exists()) return webpPath;
    if (await File(jpgPath).exists()) return jpgPath;
    return null;
  }

  /// Get a single offline color combo by ID
  Future<Map<String, dynamic>?> getOfflineComboById(String comboId) async {
    if (!_isInitialized) await init();
    if (_progress.status != DownloadStatus.completed) return null;

    try {
      final combos = await getOfflineCombos();
      return combos.firstWhere(
        (c) => c['id'] == comboId,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      debugPrint('[Offline] Error getting combo by ID: $e');
      return null;
    }
  }

  /// Get local path for a reel video
  Future<String?> getLocalReelVideoPath(String reelId) async {
    if (_progress.status != DownloadStatus.completed) return null;

    final reelsDir = await _getReelsDirectory();
    final videoPath = '${reelsDir.path}/${reelId}_video.mp4';

    if (await File(videoPath).exists()) return videoPath;
    return null;
  }

  /// Get local path for a reel thumbnail
  Future<String?> getLocalReelThumbnailPath(String reelId) async {
    if (_progress.status != DownloadStatus.completed) return null;

    final reelsDir = await _getReelsDirectory();
    final thumbPath = '${reelsDir.path}/${reelId}_thumb.jpg';

    if (await File(thumbPath).exists()) return thumbPath;
    return null;
  }

  /// Get estimated storage size
  Future<String> getStorageSize() async {
    try {
      final offlineDir = await _getOfflineDirectory();
      if (!await offlineDir.exists()) return '0 MB';

      int totalSize = 0;
      await for (final entity in offlineDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB';
    } catch (e) {
      return '0 MB';
    }
  }

  /// Get all offline color combos data
  /// Returns list of combo JSON maps with local image paths
  Future<List<Map<String, dynamic>>> getOfflineCombos() async {
    if (_progress.status != DownloadStatus.completed) return [];

    try {
      final combosDir = await _getColorCombosDirectory();
      final metadataFile = File('${combosDir.path}/metadata.json');
      
      if (!await metadataFile.exists()) return [];
      
      final content = await metadataFile.readAsString();
      // Parse the JSON - the file stores the full API response
      final dynamic parsed = _parseMetadata(content);
      
      if (parsed is Map && parsed['data'] is List) {
        final List combos = parsed['data'] as List;
        // Update each combo with local image path
        return combos.map((combo) {
          final id = combo['id'] as String;
          return {
            ...Map<String, dynamic>.from(combo as Map),
            'local_image_path': '${combosDir.path}/${id}_model.webp',
          };
        }).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('[Offline] Error reading combos: $e');
      return [];
    }
  }

  /// Get all offline reels data
  /// Returns list of reel JSON maps with local video/thumbnail paths
  Future<List<Map<String, dynamic>>> getOfflineReels() async {
    // Ensure initialized
    if (!_isInitialized) await init();
    
    debugPrint('[Offline] getOfflineReels called - status: ${_progress.status}');
    
    if (_progress.status != DownloadStatus.completed) {
      debugPrint('[Offline] Not completed, returning empty');
      return [];
    }

    try {
      final reelsDir = await _getReelsDirectory();
      final metadataFile = File('${reelsDir.path}/metadata.json');
      
      debugPrint('[Offline] Looking for metadata at: ${metadataFile.path}');
      
      if (!await metadataFile.exists()) {
        debugPrint('[Offline] Metadata file does not exist');
        return [];
      }
      
      final content = await metadataFile.readAsString();
      debugPrint('[Offline] Metadata content length: ${content.length} bytes');
      
      final dynamic parsed = _parseMetadata(content);
      
      if (parsed is List) {
        debugPrint('[Offline] Parsed ${parsed.length} reels from metadata');
        return parsed.map((reel) {
          final id = reel['id'] as String;
          return {
            ...Map<String, dynamic>.from(reel as Map),
            'local_video_path': '${reelsDir.path}/${id}_video.mp4',
            'local_thumb_path': '${reelsDir.path}/${id}_thumb.jpg',
          };
        }).toList();
      }
      
      debugPrint('[Offline] Parsed data is not a List');
      return [];
    } catch (e) {
      debugPrint('[Offline] Error reading reels: $e');
      return [];
    }
  }

  /// Parse metadata string (handles Dart toString format and JSON)
  dynamic _parseMetadata(String content) {
    try {
      // Try JSON first
      return jsonDecode(content);
    } catch (e) {
      // If not valid JSON, it might be Dart Map.toString() format
      // For safety, return empty - we should save as proper JSON
      debugPrint('[Offline] Metadata not valid JSON, returning empty');
      return [];
    }
  }

  /// Debug method to check what's downloaded
  Future<void> debugPrintDownloadedContent() async {
    debugPrint('========== OFFLINE CONTENT DEBUG ==========');
    debugPrint('Download Status: ${_progress.status}');
    debugPrint('Is Enabled: $isOfflineModeEnabled');
    
    try {
      final combosDir = await _getColorCombosDirectory();
      final reelsDir = await _getReelsDirectory();
      
      debugPrint('\n--- COMBOS DIRECTORY: ${combosDir.path} ---');
      if (await combosDir.exists()) {
        final comboFiles = combosDir.listSync();
        debugPrint('Total files: ${comboFiles.length}');
        for (var file in comboFiles.take(20)) {
          final stat = await (file as File).stat();
          debugPrint('  ${file.path.split('/').last} (${(stat.size / 1024).toStringAsFixed(1)} KB)');
        }
        if (comboFiles.length > 20) debugPrint('  ... and ${comboFiles.length - 20} more');
      } else {
        debugPrint('Directory does not exist');
      }
      
      debugPrint('\n--- REELS DIRECTORY: ${reelsDir.path} ---');
      if (await reelsDir.exists()) {
        final reelFiles = reelsDir.listSync();
        debugPrint('Total files: ${reelFiles.length}');
        for (var file in reelFiles.take(20)) {
          final stat = await (file as File).stat();
          debugPrint('  ${file.path.split('/').last} (${(stat.size / 1024 / 1024).toStringAsFixed(2)} MB)');
        }
        if (reelFiles.length > 20) debugPrint('  ... and ${reelFiles.length - 20} more');
      } else {
        debugPrint('Directory does not exist');
      }
      
      // Check metadata files
      final combosMetadata = File('${combosDir.path}/metadata.json');
      final reelsMetadata = File('${reelsDir.path}/metadata.json');
      
      debugPrint('\n--- METADATA ---');
      if (await combosMetadata.exists()) {
        final content = await combosMetadata.readAsString();
        debugPrint('Combos metadata exists: ${content.length} bytes');
        try {
          final parsed = jsonDecode(content);
          if (parsed is List) debugPrint('  Contains ${parsed.length} combo entries');
        } catch (e) {
          debugPrint('  ERROR parsing: $e');
        }
      } else {
        debugPrint('Combos metadata: NOT FOUND');
      }
      
      if (await reelsMetadata.exists()) {
        final content = await reelsMetadata.readAsString();
        debugPrint('Reels metadata exists: ${content.length} bytes');
        try {
          final parsed = jsonDecode(content);
          if (parsed is List) debugPrint('  Contains ${parsed.length} reel entries');
        } catch (e) {
          debugPrint('  ERROR parsing: $e');
        }
      } else {
        debugPrint('Reels metadata: NOT FOUND');
      }
      
      debugPrint('\n--- STORAGE SIZE ---');
      final size = await getStorageSize();
      debugPrint('Total offline storage: $size');
      
    } catch (e) {
      debugPrint('Error checking offline content: $e');
    }
    debugPrint('============================================');
  }
}

