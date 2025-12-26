import '../models/product.dart';

/// AI Analysis result from image recognition API
class AIAnalysisResult {
  final String primaryColor;
  final String? secondaryColor;
  final String pattern;
  final String category;
  final List<String> matchingColors;
  final List<String> targetCategories;
  final String targetCategoryType;
  final List<Product> products;

  AIAnalysisResult({
    required this.primaryColor,
    this.secondaryColor,
    required this.pattern,
    required this.category,
    required this.matchingColors,
    required this.targetCategories,
    required this.targetCategoryType,
    required this.products,
  });

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>? ?? {};
    final productsList = json['products'] as List<dynamic>? ?? [];

    return AIAnalysisResult(
      primaryColor: analysis['primary_color'] as String? ?? 'unknown',
      secondaryColor: analysis['secondary_color'] as String?,
      pattern: analysis['pattern'] as String? ?? 'solid',
      category: analysis['category'] as String? ?? 'Unknown',
      matchingColors: (analysis['matching_colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      targetCategories: (analysis['target_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      targetCategoryType: analysis['target_category_type'] as String? ?? 'mixed',
      products: productsList.map((p) => Product.fromJson(p)).toList(),
    );
  }
}
