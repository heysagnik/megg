import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _notificationsEnabled = true;

  static const String _notificationPrefKey = 'notifications_enabled';

  bool get notificationsEnabled => _notificationsEnabled;

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load notifications');
    }
  }

  Future<void> initialize() async {
    await _loadNotificationPreference();

    if (!_notificationsEnabled) return;

    _channel = _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            if (!_notificationsEnabled) return;

            final newRow = payload.newRecord;
            final title = newRow['title'] as String?;
            final description = newRow['description'] as String?;
            final link = newRow['link'] as String?;

            if (title != null && description != null) {
              _showInAppNotification(title, description, link);
            }
          },
        )
        .subscribe();
  }

  Future<void> showPermissionDialogIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasAskedBefore =
        prefs.getBool('notification_permission_asked') ?? false;

    if (hasAskedBefore) return;

    await prefs.setBool('notification_permission_asked', true);

    if (!context.mounted) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.bell,
                  size: 32,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ENABLE NOTIFICATIONS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Stay updated with new arrivals, exclusive offers, and style tips.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.grey[700],
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'ENABLE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'NOT NOW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldEnable == true) {
      _notificationsEnabled = true;
      await prefs.setBool(_notificationPrefKey, true);
      // Initialize realtime if not already done
      if (_channel == null) {
        initialize();
      }
    } else {
      _notificationsEnabled = false;
      await prefs.setBool(_notificationPrefKey, false);
      _channel?.unsubscribe();
      _channel = null;
    }
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationPrefKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPrefKey, enabled);

    if (enabled && _channel == null) {
      initialize();
    } else if (!enabled && _channel != null) {
      _channel?.unsubscribe();
      _channel = null;
    }
  }

  void _showInAppNotification(String title, String description, String? link) {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _NotificationBanner(
        title: title,
        description: description,
        link: link,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String description;
  final String? link;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.description,
    required this.link,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  Future<void> _handleTap() async {
    if (widget.link != null && widget.link!.isNotEmpty) {
      try {
        final uri = Uri.parse(widget.link!);
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        // Silently fail if link is invalid
      }
    }
    _handleDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: _handleTap,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.bell,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.description,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _handleDismiss,
                            child: Icon(
                              PhosphorIconsRegular.x,
                              color: Colors.white.withOpacity(0.6),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
