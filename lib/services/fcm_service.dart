import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Top-level function for background message handling
/// Required by FCM to process notifications when app is terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background notification: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
}

/// FCM Service using Topic-Based Messaging
/// 
/// Architecture:
/// - All users subscribe to "all-users" topic
/// - No per-device token registration required
/// - Backend sends to topic, Firebase handles delivery
/// - Simpler, more scalable, no token management
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Topic that all users subscribe to
  static const String _allUsersTopic = 'all-users';
  
  // Global navigator key for deep linking
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Initialize FCM with topic subscription
  /// No token registration - just subscribe to "all-users" topic
  Future<void> initialize() async {
    debugPrint('🚀 Initializing FCM Service...');

    // Request notification permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('⚠️ Provisional notification permission granted');
    } else {
      debugPrint('❌ Notification permission denied');
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Subscribe to all-users topic
    await _subscribeToAllUsersTopic();

    // Handle foreground messages (app is open and visible)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from terminated state via notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App launched from notification');
      _handleNotificationTap(initialMessage);
    }

    debugPrint('✅ FCM Service initialized successfully');
  }

  /// Subscribe to the all-users topic
  /// This replaces per-device token registration
  Future<void> _subscribeToAllUsersTopic() async {
    try {
      await _firebaseMessaging.subscribeToTopic(_allUsersTopic);
      debugPrint('✅ Subscribed to topic: $_allUsersTopic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from all-users topic (e.g., on logout)
  Future<void> unsubscribe() async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(_allUsersTopic);
      debugPrint('✅ Unsubscribed from topic: $_allUsersTopic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Initialize local notifications plugin for Android
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'megg_notifications',
      'Megg Notifications',
      description: 'Notifications for new products, offers, and updates',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground notification received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Show notification even when app is in foreground
    _showLocalNotification(message);
  }

  /// Show local notification using flutter_local_notifications
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'megg_notifications',
      'Megg Notifications',
      channelDescription: 'Notifications for new products, offers, and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      ticker: 'New notification from Megg',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['link'],
    );
  }

  /// Handle notification tap (background/terminated state)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped');
    final link = message.data['link'] as String?;
    
    if (link != null && link.isNotEmpty) {
      debugPrint('   Opening link: $link');
      _openLink(link);
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      debugPrint('   Opening link: ${response.payload}');
      _openLink(response.payload!);
    }
  }

  /// Open link in external browser
  Future<void> _openLink(String link) async {
    try {
      String finalLink = link;
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        finalLink = 'https://$link';
      }

      final uri = Uri.parse(finalLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('❌ Cannot launch URL: $link');
      }
    } catch (e) {
      debugPrint('❌ Error opening link: $e');
    }
  }
}
