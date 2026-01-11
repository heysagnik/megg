import 'package:flutter/material.dart';


class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
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
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.grey[200]!,
                    Colors.grey[100]!,
                    Colors.grey[200]!,
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
        ),
      ),
    );
  }
}

/// Skeleton for outfit carousel
class OutfitCarouselSkeleton extends StatelessWidget {
  final double height;

  const OutfitCarouselSkeleton({super.key, this.height = 500});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          const ShimmerBox(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: 200,
                  height: 32,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: 120,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for horizontal product scroll
class ProductScrollSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double itemHeight;

  const ProductScrollSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemWidth = 160,
    this.itemHeight = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: const ShimmerBox()),
                const SizedBox(height: 12),
                ShimmerBox(
                  width: 80,
                  height: 10,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 140,
                  height: 12,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 60,
                  height: 14,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for product grid
class ProductGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double childAspectRatio;

  const ProductGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 4,
    this.childAspectRatio = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: const ShimmerBox()),
            const SizedBox(height: 12),
            ShimmerBox(
              width: 60,
              height: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 6),
            ShimmerBox(
              width: 100,
              height: 12,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 6),
            ShimmerBox(
              width: 50,
              height: 14,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        );
      },
    );
  }
}

/// Skeleton for section header
class SectionHeaderSkeleton extends StatelessWidget {
  const SectionHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShimmerBox(
            width: 140,
            height: 16,
            borderRadius: BorderRadius.circular(4),
          ),
          ShimmerBox(
            width: 60,
            height: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for category chips
class CategoryChipsSkeleton extends StatelessWidget {
  final int itemCount;

  const CategoryChipsSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Column(
            children: [
              ShimmerBox(
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(32),
              ),
              const SizedBox(height: 8),
              ShimmerBox(
                width: 48,
                height: 10,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full home screen skeleton
class HomeScreenSkeleton extends StatelessWidget {
  final double outfitHeight;

  const HomeScreenSkeleton({super.key, this.outfitHeight = 500});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutfitCarouselSkeleton(height: outfitHeight),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerBox(
              width: 140,
              height: 16,
            ),
          ),
          const SizedBox(height: 16),
          const CategoryChipsSkeleton(),
          const SizedBox(height: 32),
          const SectionHeaderSkeleton(),
          const SizedBox(height: 16),
          const ProductScrollSkeleton(),
          const SizedBox(height: 32),
          const SectionHeaderSkeleton(),
          const SizedBox(height: 16),
          const ProductGridSkeleton(itemCount: 4),
        ],
      ),
    );
  }
}
