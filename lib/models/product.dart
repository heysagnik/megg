class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String brand;
  final List<String> images;
  final String category;
  final String? subcategory;
  final String color;
  final List<String> suggestedColors;
  final String affiliateLink;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.brand,
    required this.images,
    required this.category,
    this.subcategory,
    required this.color,
    this.suggestedColors = const [],
    required this.affiliateLink,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      brand: json['brand'] ?? '',
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      category: json['category'] ?? '',
      subcategory: json['subcategory']?.toString(),
      color: json['color']?.toString() ?? '',
      suggestedColors:
          (json['suggested_colors'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      affiliateLink: json['affiliate_link']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'brand': brand,
      'images': images,
      'category': category,
      'subcategory': subcategory,
      'color': color,
      'suggested_colors': suggestedColors,
      'affiliate_link': affiliateLink,
    };
  }
}
