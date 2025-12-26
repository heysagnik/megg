import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/category_reels_screen.dart';

/// Service for handling deep links to the app
/// Supports:
/// - Custom scheme: megg://guides/{category}/{reelId}
/// - HTTPS links: https://megg.app/guides/{category}/{reelId}
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isInitialized = false;
  bool _isAppReady = false;
  Uri? _pendingDeepLink;

  /// Initialize the deep link service
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    
    // If already initialized, just update navigator and return
    // (warm start scenario - app already running)
    if (_isInitialized) {
      debugPrint('[DeepLink] Already initialized, skipping');
      return;
    }
    
    debugPrint('[DeepLink] Initializing service...');

    // Handle initial link (cold start)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        debugPrint('[DeepLink] Initial link found: $initialLink');
        _pendingDeepLink = initialLink;
      }
    } catch (e) {
      debugPrint('[DeepLink] Error getting initial link: $e');
    }

    // Listen for incoming links (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('[DeepLink] Received link: $uri');
        debugPrint('[DeepLink] _isAppReady: $_isAppReady, _isInitialized: $_isInitialized');
        
        // If app is ready OR service was already used before (warm start), handle immediately
        if (_isAppReady) {
          _handleDeepLink(uri);
        } else {
          // During cold start, queue for later
          debugPrint('[DeepLink] App not ready, queueing link');
          _pendingDeepLink = uri;
          
          // Try to process after a short delay (in case setAppReady was missed)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_pendingDeepLink != null && _navigatorKey?.currentState != null) {
              debugPrint('[DeepLink] Delayed processing of pending link');
              _handleDeepLink(_pendingDeepLink!);
              _pendingDeepLink = null;
            }
          });
        }
      },
      onError: (e) {
        debugPrint('[DeepLink] Stream error: $e');
      },
    );

    _isInitialized = true;
    debugPrint('[DeepLink] Service initialized');
  }

  /// Call when app is ready to navigate (after splash screen)
  void setAppReady() {
    debugPrint('[DeepLink] App is now ready for navigation');
    _isAppReady = true;
    
    // Handle any pending link
    if (_pendingDeepLink != null) {
      debugPrint('[DeepLink] Processing pending link: $_pendingDeepLink');
      _handleDeepLink(_pendingDeepLink!);
      _pendingDeepLink = null;
    }
  }

  /// Parse and handle a deep link URI
  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLink] Handling URI: $uri');
    debugPrint('[DeepLink] Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}');
    debugPrint('[DeepLink] Path segments: ${uri.pathSegments}');
    
    List<String> segments;
    
    if (uri.scheme == 'megg' && uri.host.isNotEmpty) {
      segments = [uri.host, ...uri.pathSegments];
      debugPrint('[DeepLink] Custom scheme - combined segments: $segments');
    } else {
      segments = uri.pathSegments;
    }
    
    if (segments.isEmpty) {
      debugPrint('[DeepLink] No segments to process');
      return;
    }

    _processSegments(segments);
  }

  void _processSegments(List<String> segments) {
    debugPrint('[DeepLink] Processing segments: $segments');
    
    // Check for guides/category/reelId pattern
    if (segments.isNotEmpty && segments.first == 'guides' && segments.length >= 2) {
      final category = segments[1];
      final reelId = segments.length >= 3 ? segments[2] : null;
      
      debugPrint('[DeepLink] -> Category: $category, ReelId: $reelId');
      _navigateToReels(category, reelId);
    } else {
      debugPrint('[DeepLink] Unknown path pattern: $segments');
    }
  }

  /// Navigate to the CategoryReelsScreen
  void _navigateToReels(String category, String? initialReelId) {
    // Add a small delay to ensure navigation stack is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      final navigator = _navigatorKey?.currentState;
      if (navigator == null) {
        debugPrint('[DeepLink] ERROR: Navigator not available!');
        return;
      }

      debugPrint('[DeepLink] Pushing CategoryReelsScreen on top of current route...');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => CategoryReelsScreen(
            category: category,
            initialReelId: initialReelId,
          ),
        ),
      );
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
