import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  late final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _allUsersTopic = 'all-users';

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    debugPrint('Initializing FCM Service');

    _firebaseMessaging = FirebaseMessaging.instance;

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Notification permission: granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('Notification permission: provisional');
    } else {
      debugPrint('Notification permission: denied');
      return;
    }

    await _initializeLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _subscribeToAllUsersTopic();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification');
      _handleNotificationTap(initialMessage);
    }

    debugPrint('FCM Service initialized successfully');
  }

  Future<void> _subscribeToAllUsersTopic() async {
    try {
      await _firebaseMessaging.subscribeToTopic(_allUsersTopic);
      debugPrint('Subscribed to topic: $_allUsersTopic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribe() async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(_allUsersTopic);
      debugPrint('Unsubscribed from topic: $_allUsersTopic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
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

    const androidChannel = AndroidNotificationChannel(
      'megg_notifications',
      'Megg Notifications',
      description: 'Notifications for new products, offers, and updates',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground notification received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    _showLocalNotification(message);
  }

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

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped');
    final link = message.data['link'] as String?;

    if (link != null && link.isNotEmpty) {
      debugPrint('Opening link: $link');
      _openLink(link);
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped');

    if (response.payload != null && response.payload!.isNotEmpty) {
      debugPrint('Opening link: ${response.payload}');
      _openLink(response.payload!);
    }
  }

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
        debugPrint('Cannot launch URL: $link');
      }
    } catch (e) {
      debugPrint('Error opening link: $e');
    }
  }
}
