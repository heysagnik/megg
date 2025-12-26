import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_history_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/loader.dart';
import '../widgets/custom_refresh_indicator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationHistoryService _historyService =
      NotificationHistoryService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalItems = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final response = await _historyService.fetchNotifications(
        page: page,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        if (loadMore) {
          _notifications.addAll(response.notifications);
          _currentPage = page;
        } else {
          _notifications = response.notifications;
          _currentPage = 1;
        }
        _totalItems = response.total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openLink(String? link) async {
    if (link == null || link.isEmpty) return;

    try {
      String finalLink = link;
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        finalLink = 'https://$link';
      }

      final uri = Uri.parse(finalLink);
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'UNABLE TO OPEN LINK',
              style: TextStyle(letterSpacing: 1),
            ),
            backgroundColor: Colors.black,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(
        title: 'NOTIFICATIONS',
        showBackButton: true,
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading && _notifications.isEmpty) {
            return const Center(child: Loader());
          }

          if (_error != null && _notifications.isEmpty) {
            return _buildErrorState();
          }

          if (_notifications.isEmpty) {
            return _buildEmptyState();
          }

          return _buildNotificationsList();
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                PhosphorIconsRegular.warningCircle,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'UNABLE TO LOAD',
              style: TextStyle(
                fontFamily: 'FuturaCyrillicBook',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please check your connection',
              style: TextStyle(
                fontFamily: 'FuturaCyrillicBook',
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: _loadNotifications,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 1),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: const Text(
                  'RETRY',
                  style: TextStyle(
                    fontFamily: 'FuturaCyrillicBook',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Icon(
                PhosphorIconsRegular.bellSlash,
                size: 48,
                color: Colors.grey[350],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'NO NOTIFICATIONS',
              style: TextStyle(
                fontFamily: 'FuturaCyrillicBook',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re all caught up',
              style: TextStyle(
                fontFamily: 'FuturaCyrillicBook',
                fontSize: 13,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return CustomRefreshIndicator(
      onRefresh: () => _loadNotifications(loadMore: false),
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length + (_hasMore() ? 1 : 0),
        itemBuilder: (context, index) {
          // Load more button at bottom
          if (index == _notifications.length) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _loadNotifications(loadMore: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(
                        color: Colors.black.withOpacity(0.2),
                        width: 1,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'LOAD MORE',
                            style: TextStyle(
                              fontFamily: 'FuturaCyrillicBook',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification, int index) {
    final hasLink = notification.link != null && notification.link!.isNotEmpty;

    return InkWell(
      onTap: hasLink ? () => _openLink(notification.link) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bell icon with square container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: Colors.black,
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsRegular.bell,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'FuturaCyrillicBook',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      notification.description,
                      style: TextStyle(
                        fontFamily: 'FuturaCyrillicBook',
                        fontSize: 12,
                        color: Colors.grey[700],
                        letterSpacing: 0.3,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _formatTimeAgo(notification.createdAt).toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'FuturaCyrillicBook',
                          fontSize: 10,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      if (hasLink) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'TAP TO VIEW',
                          style: TextStyle(
                            fontFamily: 'FuturaCyrillicBook',
                            fontSize: 10,
                            color: Colors.grey[600],
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Arrow indicator for links
            if (hasLink) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  PhosphorIconsRegular.arrowRight,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasMore() {
    return _notifications.length < _totalItems;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
