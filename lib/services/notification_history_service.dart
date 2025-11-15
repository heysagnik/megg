import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';

/// Individual notification item
class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String? link;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    this.link,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      link: json['link'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Response model for notification history
class NotificationHistoryResponse {
  final List<NotificationItem> notifications;
  final int total;
  final int page;

  NotificationHistoryResponse({
    required this.notifications,
    required this.total,
    required this.page,
  });

  factory NotificationHistoryResponse.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryResponse(
      notifications: (json['notifications'] as List)
          .map((item) => NotificationItem.fromJson(item))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
    );
  }
}

/// Service to fetch notification history from backend API
class NotificationHistoryService {
  static final NotificationHistoryService _instance =
      NotificationHistoryService._internal();
  factory NotificationHistoryService() => _instance;
  NotificationHistoryService._internal();

  /// Fetch notifications from backend
  ///
  /// Backend endpoint: GET /api/fcm?page=1&limit=20
  /// Returns: {notifications: [...], total, page}
  Future<NotificationHistoryResponse> fetchNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/fcm').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      debugPrint('📥 Fetching notifications: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Fetched ${data['notifications'].length} notifications');
        return NotificationHistoryResponse.fromJson(data);
      } else {
        throw Exception(
          'Failed to fetch notifications: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      rethrow;
    }
  }
}
