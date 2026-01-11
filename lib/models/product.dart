import 'dart:convert';

class Product {
  final String id;
  final String name;
  final double price;
  final String brand;
  final List<String> images;
  final String category;
  final String? subcategory;
  final String color;
  final String? description;
  final String? affiliateLink;
  final List<String> fabric;
  final int clicks;
  final int popularity;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.brand,
    required this.images,
    required this.category,
    this.subcategory,
    required this.color,
    this.description,
    this.affiliateLink,
    this.fabric = const [],
    this.clicks = 0,
    this.popularity = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse price - handle both string and numeric values
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      }
      return 0.0;
    }

   
    String extractImageUrl(String imageString, {String preferredSize = 'medium'}) {
      final trimmed = imageString.trim();
      
      // Check if it's a JSON string (starts with '{')
      if (trimmed.startsWith('{')) {
        try {
          final Map<String, dynamic> imageJson = jsonDecode(trimmed);
          // Try preferred size first, then fallback in order
          final sizes = [preferredSize, 'medium', 'large', 'original', 'thumb'];
          for (final size in sizes) {
            if (imageJson.containsKey(size) && imageJson[size] != null && imageJson[size].toString().isNotEmpty) {
              return imageJson[size].toString();
            }
          }
        } catch (e) {
          // If JSON parsing fails, return the original string
          return trimmed;
        }
      }
      
      // Return as-is if it's already a plain URL
      return trimmed;
    }

    // Parse images - handle list of stringified JSON or plain URLs
    List<String> parseImages(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((e) => extractImageUrl(e.toString()))
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        return [extractImageUrl(value)];
      }
      return [];
    }

    // Parse fabric list
    List<String> parseFabric(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      if (value is String && value.isNotEmpty) {
        return [value];
      }
      return [];
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Product',
      price: parsePrice(json['price']),
      brand: json['brand']?.toString() ?? 'Unknown Brand',
      images: parseImages(json['images']),
      category: json['category']?.toString() ?? 'Uncategorized',
      subcategory: json['subcategory']?.toString(),
      color: json['color']?.toString() ?? '',
      description: json['description']?.toString(),
      affiliateLink: json['affiliate_link']?.toString(),
      fabric: parseFabric(json['fabric']),
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price.toString(),
      'brand': brand,
      'images': images,
      'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      'color': color,
      if (description != null) 'description': description,
      if (affiliateLink != null) 'affiliate_link': affiliateLink,
      if (fabric.isNotEmpty) 'fabric': fabric,
      'clicks': clicks,
      'popularity': popularity,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product(id: $id, name: $name, brand: $brand)';
}
