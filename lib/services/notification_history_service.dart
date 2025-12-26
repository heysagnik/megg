import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';

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

class NotificationHistoryService {
  static final NotificationHistoryService _instance = NotificationHistoryService._internal();
  factory NotificationHistoryService() => _instance;
  NotificationHistoryService._internal();

  static const int _kDefaultLimit = 20;

  Future<NotificationHistoryResponse> fetchNotifications({
    int page = 1,
    int limit = _kDefaultLimit,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/fcm').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      debugPrint('Fetching notifications: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // API returns data wrapped in 'data' object
        final data = responseData['data'] ?? responseData;
        debugPrint('Fetched ${data['notifications']?.length ?? 0} notifications');
        return NotificationHistoryResponse.fromJson(data);
      } else {
        throw Exception('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      rethrow;
    }
  }
}
