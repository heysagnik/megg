class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final List<String> images;
  final String description;
  final List<String> sizes;
  final List<String> colors;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.images,
    required this.description,
    required this.sizes,
    required this.colors,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] ?? '',
      sizes: (json['sizes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      colors: json['color'] != null
          ? [json['color'].toString()]
          : (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'images': images,
      'description': description,
      'sizes': sizes,
      'colors': colors,
    };
  }
}
