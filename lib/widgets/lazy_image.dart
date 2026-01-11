import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Lazy loading image widget following MEGG design system.
/// Features: Placeholder shimmer, error state, fade-in animation.
class LazyImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final Duration fadeInDuration;
  final Widget? errorWidget;

  const LazyImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderColor,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    final child = CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => _buildShimmer(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorState(),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return child;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey[100],
    );
  }

  Widget _buildShimmer() {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey[100],
      child: const _ShimmerEffect(),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey[400],
        size: 32,
      ),
    );
  }
}

/// Minimal shimmer effect following design system (no shadows, flat design)
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey[100]!,
                Colors.grey[50]!,
                Colors.grey[100]!,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hero image with lazy loading for product detail screens
class LazyHeroImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final VoidCallback? onTap;

  const LazyHeroImage({
    super.key,
    required this.imageUrl,
    this.height = 550,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: LazyImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          height: height,
        ),
      ),
    );
  }
}

/// Thumbnail image for lists and grids
class LazyThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const LazyThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: LazyImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Avatar image for user profiles
class LazyAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;

  const LazyAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: fallbackText != null
            ? Text(
                fallbackText!.isNotEmpty ? fallbackText![0].toUpperCase() : '',
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              )
            : Icon(Icons.person_outline, size: radius, color: Colors.grey[500]),
      );
    }

    return ClipOval(
      child: LazyImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      ),
    );
  }
}
