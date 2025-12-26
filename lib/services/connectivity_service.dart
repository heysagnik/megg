import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to track network connectivity status.
/// Provides instant checks and reactive streams for offline-aware UI.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isOnline = true;
  bool _isInitialized = false;

  /// Whether the device currently has network connectivity
  bool get isOnline => _isOnline;
  
  /// Whether the device is currently offline
  bool get isOffline => !_isOnline;

  /// Initialize the connectivity service
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check initial status
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      debugPrint('[Connectivity] Initial check failed: $e');
      // Assume online if we can't check
      _isOnline = true;
    }

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // We're online if we have any connection other than 'none'
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      debugPrint('[Connectivity] Status changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      notifyListeners();
    }
  }

  /// Check connectivity with a quick internet ping (optional)
  Future<bool> checkRealConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _isOnline;
    } catch (e) {
      return _isOnline;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
