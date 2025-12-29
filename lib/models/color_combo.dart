import 'dart:convert';

class ColorCombo {
  final String id;
  final String name;
  // Legacy primary color (kept for backward compatibility)
  final String primaryColor;
  // Legacy additional colors (kept for backward compatibility)
  final List<String> comboColors;
  // New API fields
  final String? colorA;
  final String? colorB;
  final String groupType;
  final String modelImage;
  final List<String> productIds;
  final DateTime createdAt;

  ColorCombo({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.comboColors,
    this.colorA,
    this.colorB,
    required this.groupType,
    required this.modelImage,
    required this.productIds,
    required this.createdAt,
  });

  /// Parses the model_image JSON string and returns the image URLs map
  Map<String, String>? get modelImageUrls {
    if (modelImage.isEmpty) return null;
    try {
      final decoded = json.decode(modelImage);
      if (decoded is Map) {
        return Map<String, String>.from(decoded);
      }
    } catch (_) {
      // If parsing fails, modelImage might be a direct URL (legacy format)
    }
    return null;
  }

  /// Returns the thumbnail image URL (smallest size)
  String get modelImageThumb {
    final urls = modelImageUrls;
    if (urls != null && urls['thumb'] != null) {
      return urls['thumb']!;
    }
    // Fall back to raw modelImage for legacy support
    return modelImage;
  }

  /// Returns the medium image URL
  String get modelImageMedium {
    final urls = modelImageUrls;
    if (urls != null && urls['medium'] != null) {
      return urls['medium']!;
    }
    return modelImage;
  }

  /// Returns the large image URL (full size)
  String get modelImageLarge {
    final urls = modelImageUrls;
    if (urls != null && urls['large'] != null) {
      return urls['large']!;
    }
    return modelImage;
  }

  factory ColorCombo.fromJson(Map<String, dynamic> json) {
    // Support both legacy and new API shapes
    final legacyPrimary = json['primary_color'] as String?;
    final legacyComboColors =
        (json['combo_colors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final newColorA = json['color_a'] as String?;
    final newColorB = json['color_b'] as String?;

    return ColorCombo(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled Combo',
      // Prefer legacy primary_color if provided, else fall back to color_a
      primaryColor: legacyPrimary ?? newColorA ?? '#000000',
      comboColors: legacyComboColors,
      colorA: newColorA,
      colorB: newColorB,
      groupType: json['group_type'] as String? ?? 'casual',
      modelImage: _parseModelImage(json['model_image']),
      productIds:
          (json['product_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      // Preserve legacy fields
      'primary_color': primaryColor,
      'combo_colors': comboColors,
      // Include new fields when available
      if (colorA != null) 'color_a': colorA,
      if (colorB != null) 'color_b': colorB,
      'group_type': groupType,
      'model_image': modelImage,
      'product_ids': productIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String _parseModelImage(dynamic image) {
    if (image == null) return '';
    if (image is String) return image;
    if (image is Map) {
      try {
        return json.encode(image);
      } catch (_) {
        return '';
      }
    }
    return '';
  }
}
