import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class FilterSortBar extends StatelessWidget {
  final String sortBy;
  final int resultCount;
  final bool isGridView;
  final VoidCallback onSortTap;
  final VoidCallback onFilterTap;
  final VoidCallback onViewToggle;
  final bool isSticky;
  final int? activeFilterCount;

  const FilterSortBar({
    super.key,
    required this.sortBy,
    required this.resultCount,
    required this.isGridView,
    required this.onSortTap,
    required this.onFilterTap,
    required this.onViewToggle,
    this.isSticky = false,
    this.activeFilterCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: isSticky
              ? BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5)
              : BorderSide.none,
          bottom: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5),
        ),
        boxShadow: isSticky
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildButton(
                  context,
                  icon: PhosphorIconsRegular.arrowsDownUp,
                  label: 'SORT',
                  onTap: onSortTap,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.black.withOpacity(0.08),
              ),
              Expanded(
                child: _buildButton(
                  context,
                  icon: PhosphorIconsRegular.sliders,
                  label: 'FILTER',
                  onTap: onFilterTap,
                  badge: activeFilterCount != null && activeFilterCount! > 0
                      ? activeFilterCount
                      : null,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.black.withOpacity(0.08),
              ),
              Expanded(
                child: _buildButton(
                  context,
                  icon: isGridView
                      ? PhosphorIconsRegular.list
                      : PhosphorIconsRegular.gridFour,
                  label: isGridView ? 'LIST' : 'GRID',
                  onTap: onViewToggle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: Colors.black),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subcategory filter chips below app bar
class SubcategoryFilterBar extends StatelessWidget {
  final List<String> subcategories;
  final String? selectedSubcategory;
  final ValueChanged<String?> onSubcategorySelected;

  const SubcategoryFilterBar({
    super.key,
    required this.subcategories,
    required this.selectedSubcategory,
    required this.onSubcategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (subcategories.isEmpty) return const SizedBox.shrink();

    // Reorder subcategories so selected one appears first
    final orderedSubcategories = <String>[];
    if (selectedSubcategory != null && subcategories.contains(selectedSubcategory)) {
      orderedSubcategories.add(selectedSubcategory!);
      orderedSubcategories.addAll(
        subcategories.where((s) => s != selectedSubcategory),
      );
    } else {
      orderedSubcategories.addAll(subcategories);
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: orderedSubcategories.length + 1, // +1 for "All" chip
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" chip
            return _buildChip(
              label: 'All',
              isSelected: selectedSubcategory == null,
              onTap: () => onSubcategorySelected(null),
            );
          }

          final subcategory = orderedSubcategories[index - 1];
          return _buildChip(
            label: subcategory,
            isSelected: selectedSubcategory == subcategory,
            onTap: () => onSubcategorySelected(subcategory),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black.withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
