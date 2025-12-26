class Reel {
  final String id;
  final String category;
  final String videoUrl;
  final String thumbnailUrl;
  final String? affiliateLink;
  final List<String> productIds;
  final int views;
  final int likes;
  final DateTime createdAt;

  Reel({
    required this.id,
    required this.category,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.affiliateLink,
    this.productIds = const [],
    required this.views,
    required this.likes,
    required this.createdAt,
  });

  /// Check if reel has linked products
  bool get hasProducts => productIds.isNotEmpty;

  factory Reel.fromJson(Map<String, dynamic> json) {
    // Parse product_ids from API response
    List<String> parsedProductIds = [];
    if (json['product_ids'] != null) {
      if (json['product_ids'] is List) {
        parsedProductIds = (json['product_ids'] as List)
            .map((id) => id.toString())
            .toList();
      }
    }

    return Reel(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      affiliateLink: json['affiliate_link']?.toString(),
      productIds: parsedProductIds,
      views: json['views'] is num ? (json['views'] as num).toInt() : 0,
      likes: json['likes'] is num ? (json['likes'] as num).toInt() : 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'affiliate_link': affiliateLink,
      'product_ids': productIds,
      'views': views,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Reel copyWith({
    String? id,
    String? category,
    String? videoUrl,
    String? thumbnailUrl,
    String? affiliateLink,
    List<String>? productIds,
    int? views,
    int? likes,
    DateTime? createdAt,
  }) {
    return Reel(
      id: id ?? this.id,
      category: category ?? this.category,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      affiliateLink: affiliateLink ?? this.affiliateLink,
      productIds: productIds ?? this.productIds,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
