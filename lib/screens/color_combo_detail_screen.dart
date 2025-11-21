import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/color_combo.dart';
import '../models/product.dart';
import '../services/color_combo_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/loader.dart';
import '../widgets/product_widget.dart';
import 'product_screen.dart';

class ColorComboDetailScreen extends StatefulWidget {
  final String comboId;

  const ColorComboDetailScreen({super.key, required this.comboId});

  @override
  State<ColorComboDetailScreen> createState() => _ColorComboDetailScreenState();
}

class _ColorComboDetailScreenState extends State<ColorComboDetailScreen> {
  final ColorComboService _comboService = ColorComboService();

  ColorCombo? _combo;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  final Map<String, PageController> _pageControllers = {};

  @override
  void initState() {
    super.initState();
    _loadComboData();
  }

  Future<void> _loadComboData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data = await _comboService.getColorComboWithProducts(
        widget.comboId,
      );

      if (!mounted) return;

      setState(() {
        _combo = data['combo'] as ColorCombo;
        _products = data['products'] as List<Product>;
        _isLoading = false;
      });

      // Initialize page controllers for product images
      for (final product in _products) {
        _pageControllers.putIfAbsent(product.id, () => PageController());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: _combo?.name.toUpperCase() ?? 'COLOR COMBO',
        showBackButton: true,
      ),
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
                      PhosphorIconsRegular.warningCircle,
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
                      onPressed: _loadComboData,
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

          if (_combo == null) {
            return Center(
              child: Text(
                'COMBO NOT FOUND',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 2,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModelImage(),
                const SizedBox(height: 24),
                _buildColorPalette(),
                const SizedBox(height: 32),
                _buildProductsSection(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelImage() {
    if (_combo!.modelImage.isEmpty) {
      return Container(
        width: double.infinity,
        height: 400,
        color: Colors.grey[100],
        child: Icon(
          PhosphorIconsRegular.palette,
          size: 80,
          color: Colors.grey[400],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 450,
      child: Image.network(
        _combo!.modelImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[100],
            child: Icon(
              PhosphorIconsRegular.image,
              size: 80,
              color: Colors.grey[400],
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorPalette() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Text(
              _combo!.groupType.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section title
          const Text(
            'COLOR PALETTE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),

          // Color swatches with hex codes
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              
              if (_combo!.colorA != null && _combo!.colorA!.isNotEmpty)
                _buildColorSwatchWithLabel(_combo!.colorA!, 'PRIMARY'),
              if (_combo!.colorB != null && _combo!.colorB!.isNotEmpty)
                _buildColorSwatchWithLabel(_combo!.colorB!, 'SECONDARY'),

             
              ..._combo!.comboColors.asMap().entries.map(
                (entry) => _buildColorSwatchWithLabel(
                  entry.value,
                  'COMBO ${entry.key + 1}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatchWithLabel(String hexColor, String label) {
    Color color;
    String displayHex = hexColor.toUpperCase();

    try {
      final cleanHex = hexColor.replaceAll('#', '');
      color = Color(int.parse('FF$cleanHex', radix: 16));
      if (!displayHex.startsWith('#')) {
        displayHex = '#$displayHex';
      }
    } catch (e) {
      color = Colors.grey;
      displayHex = '#CCCCCC';
    }

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayHex,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
            letterSpacing: 0.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'SHOP THIS LOOK',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_products.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_products.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.package,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NO PRODUCTS AVAILABLE',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ProductCard(
                  product: product,
                  isListView: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductScreen(product: product),
                      ),
                    );
                  },
                  pageController: _pageControllers[product.id],
                );
              },
            ),
          ),
      ],
    );
  }
}
