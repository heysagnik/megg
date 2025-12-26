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

    // Parse images - handle both list and single string
    List<String> parseImages(dynamic value) {
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
