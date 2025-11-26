import 'package:flutter/material.dart';
import '../models/color_combo.dart';
import '../screens/color_combo_detail_screen.dart';

class RecommendedCombosSection extends StatelessWidget {
  final List<ColorCombo> recommendations;
  final bool isLoading;

  const RecommendedCombosSection({
    super.key,
    required this.recommendations,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'MORE COLOR COMBOS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final combo = recommendations[index];
              return _buildRecommendationCard(context, combo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(BuildContext context, ColorCombo combo) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ColorComboDetailScreen(comboId: combo.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                image: combo.modelImage.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(combo.modelImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: combo.modelImage.isEmpty
                  ? const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            combo.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (combo.colorA != null) _buildColorDot(combo.colorA!),
              if (combo.colorB != null) ...[
                const SizedBox(width: 4),
                _buildColorDot(combo.colorB!),
              ],
              if (combo.comboColors.isNotEmpty) ...[
                const SizedBox(width: 4),
                ...combo.comboColors.take(3).map((c) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _buildColorDot(c),
                    )),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorDot(String hexColor) {
    Color color;
    try {
      final cleanHex = hexColor.replaceAll('#', '');
      color = Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      color = Colors.grey;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
    );
  }
}
