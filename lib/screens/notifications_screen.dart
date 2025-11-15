import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_history_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/loader.dart';

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
            content: Text('UNABLE TO OPEN LINK'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AestheticAppBar(title: 'NOTIFICATIONS'),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const Center(child: Loader());
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UNABLE TO LOAD',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadNotifications,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            );
          }

          if (_notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.bellSlash,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NO NOTIFICATIONS',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadNotifications(loadMore: false),
            color: Colors.black,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _notifications.length + (_hasMore() ? 1 : 0),
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                // Load more indicator
                if (index == _notifications.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: TextButton(
                        onPressed: () => _loadNotifications(loadMore: true),
                        child: const Text('LOAD MORE'),
                      ),
                    ),
                  );
                }

                final notification = _notifications[index];

                return InkWell(
                  onTap:
                      notification.link != null && notification.link!.isNotEmpty
                      ? () => _openLink(notification.link)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.bell,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              if (notification.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  notification.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    letterSpacing: 0.3,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                _formatTimeAgo(notification.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (notification.link != null &&
                            notification.link!.isNotEmpty)
                          Icon(
                            PhosphorIconsRegular.caretRight,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
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
