import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/color_combo.dart';
import '../services/color_combo_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_download_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/loader.dart';
import '../widgets/offline_banner.dart';
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
  Map<String, String> _localImagePaths = {}; // comboId -> local path
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCombos();
  }

  Future<void> _loadCombos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _isOfflineMode = false;
      });

      final hasOfflineContent = OfflineDownloadService().isOfflineModeEnabled;
      
      if (hasOfflineContent) {
        debugPrint('[ComboList] Using local-first: loading from offline cache');
        await _loadOfflineCombos();
        return;
      }

      // No local content, try network
      final isOffline = ConnectivityService().isOffline;
      if (isOffline) {
        setState(() {
          _isLoading = false;
          _error = 'No internet connection and no offline content available';
        });
        return;
      }

      try {
        final combos = await _comboService.getCombosByGroup(widget.groupType);

        if (!mounted) return;

        setState(() {
          _combos = combos;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('[ComboList] Network failed: $e');
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

  Future<void> _loadOfflineCombos() async {
    final offlineCombos = await OfflineDownloadService().getOfflineCombos();
    
    if (offlineCombos.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Color combos not available offline';
      });
      return;
    }

    // Filter by group type if applicable
    final filteredCombos = offlineCombos.where((c) {
      final group = c['group_type'] ?? c['occasion'] ?? '';
      return group.toString().toLowerCase() == widget.groupType.toLowerCase();
    }).toList();

    // Build local image paths map
    final localPaths = <String, String>{};
    for (final combo in filteredCombos) {
      final id = combo['id'] as String;
      final localPath = combo['local_image_path'] as String?;
      if (localPath != null) {
        localPaths[id] = localPath;
      }
    }

    // Convert to ColorCombo objects
    final combos = filteredCombos.map((c) => ColorCombo.fromJson(c)).toList();

    if (!mounted) return;

    setState(() {
      _combos = combos;
      _localImagePaths = localPaths;
      _isLoading = false;
      _isOfflineMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.groupType.toUpperCase();

    return Scaffold(
      appBar: AestheticAppBar(title: displayTitle, showBackButton: true),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const Center(child: Loader());
          }

          if (_error != null) {
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

          if (_combos.isEmpty) {
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
                    'NO COLOR COMBOS AVAILABLE',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
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
          );
        },
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

    // Check for local image path (offline mode)
    final localImagePath = _localImagePaths[combo.id];

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
              child: _buildComboImage(combo, localImagePath),
            ),

            // Color Swatches & Names (Vertical)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First color swatch + name
                  _buildColorSwatchWithName(
                    colorA,
                    colorNames.isNotEmpty ? colorNames[0] : '',
                  ),
                  if (colorB != null) ...[
                    const SizedBox(height: 6),
                    // Second color swatch + name
                    _buildColorSwatchWithName(
                      colorB,
                      colorNames.length > 1 ? colorNames[1] : '',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboImage(ColorCombo combo, String? localImagePath) {
    // Use local image if available (offline mode)
    if (localImagePath != null && File(localImagePath).existsSync()) {
      return Image.file(
        File(localImagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    }

    // Use network image
    if (combo.modelImage.isNotEmpty) {
      return Image.network(
        combo.modelImage,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
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
        Expanded(
          child: Text(
            colorName.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.8,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
