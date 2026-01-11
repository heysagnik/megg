// import 'dart:io'; // OFFLINE FEATURE DISABLED
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/color_combo.dart';
import '../services/color_combo_service.dart';
import '../services/connectivity_service.dart';
// import '../services/offline_download_service.dart'; // OFFLINE FEATURE DISABLED
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/custom_refresh_indicator.dart';
import '../widgets/loader.dart';
import '../widgets/lazy_image.dart';
import 'color_combo_detail_screen.dart';

class ColorComboListScreen extends StatefulWidget {
  final String groupType;

  const ColorComboListScreen({super.key, required this.groupType});

  @override
  State<ColorComboListScreen> createState() => _ColorComboListScreenState();
}

class _ColorComboListScreenState extends State<ColorComboListScreen> {
  final ColorComboService _comboService = ColorComboService();

  List<ColorCombo> _combos = [];
  // Map<String, String> _localImagePaths = {}; // OFFLINE FEATURE DISABLED
  bool _isLoading = true;
  // bool _isOfflineMode = false; // OFFLINE FEATURE DISABLED
  String? _error;

  // Color filter state
  List<String> _availableColorsA = [];
  List<String> _availableColorsB = [];
  List<String> _availableColorsC = [];
  String? _selectedColorA;
  String? _selectedColorB;
  String? _selectedColorC;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadCombos();
  }

  Future<void> _loadCombos({bool withFilters = false}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // OFFLINE FEATURE DISABLED - Always use network
      try {
        final result = await _comboService.getColorCombosWithMeta(
          group: widget.groupType,
          colorA: _selectedColorA,
          colorB: _selectedColorB,
          colorC: _selectedColorC,
          forceRefresh: true,
        );

        if (!mounted) return;

        setState(() {
          _combos = result.combos;
          if (!withFilters) {
            _availableColorsA = result.colorsA;
            _availableColorsB = result.colorsB;
            _availableColorsC = result.colorsC;
          }
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Failed to load color combos';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /* OFFLINE FEATURE DISABLED
  Future<void> _loadOfflineCombos() async {
    ...
  }
  */

  void _applyFilter(String? colorA, String? colorB, String? colorC) {
    setState(() {
      _selectedColorA = colorA;
      _selectedColorB = colorB;
      _selectedColorC = colorC;
    });
    _loadCombos(withFilters: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedColorA = null;
      _selectedColorB = null;
      _selectedColorC = null;
    });
    _loadCombos();
  }

  bool get _hasActiveFilters => 
      _selectedColorA != null || _selectedColorB != null || _selectedColorC != null;

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.groupType.toUpperCase();

    return Scaffold(
      appBar: AestheticAppBar(
        title: displayTitle, 
        showBackButton: true,
        actions: [
          if (_availableColorsA.isNotEmpty || _availableColorsB.isNotEmpty)
            IconButton(
              icon: Stack(
                children: [
                  Icon(
                    _showFilters ? PhosphorIconsFill.funnel : PhosphorIconsRegular.funnel,
                    size: 20,
                    color: _hasActiveFilters ? Colors.black : Colors.grey[700],
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                setState(() => _showFilters = !_showFilters);
              },
              splashRadius: 20,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Color filter bar
          if (_showFilters)
            _buildColorFilterBar(),
          
          // Main content
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: Loader());
                }

                if (_error != null) {
                  return _buildErrorState();
                }

                if (_combos.isEmpty) {
                  return _buildEmptyState();
                }

                return CustomRefreshIndicator(
                  onRefresh: () => _loadCombos(withFilters: _hasActiveFilters),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _combos.length,
                    itemBuilder: (context, index) {
                      final combo = _combos[index];
                      return _buildComboCard(context, combo);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter label with clear button
          Row(
            children: [
              Text(
                'FILTER BY COLOR',
                style: TextStyle(
                  fontFamily: 'FuturaCyrillicBook',
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    'CLEAR',
                    style: TextStyle(
                      fontFamily: 'FuturaCyrillicBook',
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Color rows
          if (_availableColorsA.isNotEmpty) ...[
            _buildColorRow('TOP', _availableColorsA, _selectedColorA, (color) {
              _applyFilter(color, _selectedColorB, _selectedColorC);
            }),
            const SizedBox(height: 10),
          ],
          if (_availableColorsB.isNotEmpty) ...[
            _buildColorRow('BOTTOM', _availableColorsB, _selectedColorB, (color) {
              _applyFilter(_selectedColorA, color, _selectedColorC);
            }),
          ],
          if (_availableColorsC.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildColorRow('ACCENT', _availableColorsC, _selectedColorC, (color) {
              _applyFilter(_selectedColorA, _selectedColorB, color);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, List<String> colors, String? selected, Function(String?) onSelect) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'FuturaCyrillicBook',
              fontSize: 9,
              letterSpacing: 1,
              color: Colors.grey[500],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map((hex) {
                final isSelected = selected == hex;
                return GestureDetector(
                  onTap: () => onSelect(isSelected ? null : hex),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: _isLightColor(hex) ? Colors.black : Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  bool _isLightColor(String hex) {
    final color = _hexToColor(hex);
    final luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
    return luminance > 186;
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'UNABLE TO LOAD',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _loadCombos,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            _hasActiveFilters 
                ? 'NO COMBOS MATCH FILTERS'
                : 'NO COLOR COMBOS AVAILABLE',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              letterSpacing: 2,
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _clearFilters,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text(
                'CLEAR FILTERS',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComboCard(BuildContext context, ColorCombo combo) {
    // Split combo name by '+' to get individual color names
    final colorNames = combo.name.split('+').map((s) => s.trim()).toList();
    final colorA = combo.colorA ?? combo.primaryColor;
    final colorB =
        combo.colorB ??
        (combo.comboColors.isNotEmpty ? combo.comboColors.first : null);
    final colorC = combo.colorC;

    // OFFLINE FEATURE DISABLED - always use network images

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ColorComboDetailScreen(comboId: combo.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model Image
            Expanded(
              child: _buildComboImage(combo),
            ),

            // Color Swatches & Names
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row with Color A and Color C (if exists) side by side
                  Row(
                    children: [
                      if (colorA != null)
                        Expanded(
                          child: _buildColorSwatchWithName(
                            colorA,
                            colorNames.isNotEmpty ? colorNames[0] : 'Color A',
                          ),
                        ),
                      if (colorC != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildColorSwatchWithName(
                            colorC,
                            colorNames.length > 2 ? colorNames[2] : 'Color C',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Color B below
                  if (colorB != null)
                    _buildColorSwatchWithName(
                      colorB,
                      colorNames.length > 1 ? colorNames[1] : 'Color B',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboImage(ColorCombo combo) {
    if (combo.modelImageMedium.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          
          final baseWidth = 180.0;
          final cardWidth = constraints.maxWidth;
          
          final scale = 1.2;
          
          final cardHeight = constraints.maxHeight;
          final offsetY = -(cardHeight * 0.08); // 8% of card height
          
          return SizedBox.expand(
            child: ClipRect(
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: LazyImage(
                    imageUrl: combo.modelImageMedium,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      child: Icon(
        PhosphorIconsRegular.palette,
        color: Colors.grey[400],
        size: 40,
      ),
    );
  }

  Widget _buildColorSwatchWithName(String hexColor, String colorName) {
    Color color;
    try {
      // Handle both #RRGGBB and RRGGBB formats
      final cleanHex = hexColor.replaceAll('#', '');
      color = Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      color = Colors.grey;
    }

    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.rectangle,
            border: Border.all(
              color: Colors.black.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            colorName.toUpperCase(),
            style: TextStyle(
              fontFamily: 'FuturaCyrillicBook',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
