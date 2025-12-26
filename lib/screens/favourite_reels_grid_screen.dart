import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/reel.dart';
import '../services/reel_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import 'liked_reels_screen.dart';

class FavouriteReelsGridScreen extends StatefulWidget {
  final List<Reel> initialReels;

  const FavouriteReelsGridScreen({super.key, required this.initialReels});

  @override
  State<FavouriteReelsGridScreen> createState() =>
      _FavouriteReelsGridScreenState();
}

class _FavouriteReelsGridScreenState extends State<FavouriteReelsGridScreen> {
  final ReelService _reelService = ReelService();
  late List<Reel> _reels;

  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _reels = List.from(widget.initialReels);
    _extractCategories();
  }

  void _extractCategories() {
    final categories = _reels.map((r) => r.category).toSet().toList();
    categories.sort();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _refreshReels() async {
    try {
      final updated = await _reelService.getLikedReels();
      if (!mounted) return;
      setState(() {
        _reels = updated;
        _extractCategories();
      });
    } catch (e) {
      // Keep showing current UI on errors
    }
  }

  void _openReelPlayer(int index, List<Reel> reels) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LikedReelsScreen(
          initialIndex: index,
          initialReels: reels,
        ),
      ),
    );
  }

  List<Reel> get _filteredReels {
    if (_selectedCategory == null) return _reels;
    return _reels.where((r) => r.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: 'FAVOURITE REELS',
        showBackButton: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_reels.length} REELS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_categories.isNotEmpty) _buildCategoryFilter(),
          Expanded(
            child: _reels.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshReels,
                    color: Colors.black,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: _filteredReels.length,
                      itemBuilder: (context, index) {
                        final reel = _filteredReels[index];
                        return GestureDetector(
                          onTap: () => _openReelPlayer(index, _filteredReels),
                          child: Container(
                            color: Colors.grey[100],
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                reel.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        reel.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(
                                              PhosphorIconsRegular.videoCamera,
                                              size: 32,
                                              color: Colors.grey[400],
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Icon(
                                          PhosphorIconsRegular.videoCamera,
                                          size: 32,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                // Play icon overlay
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      PhosphorIconsRegular.play,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                // Views count at bottom
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PhosphorIconsRegular.play,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatCount(reel.views),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 4,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? 'All' : _categories[index - 1];
          final isSelected = isAll
              ? _selectedCategory == null
              : _selectedCategory == category;

          return Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = isAll ? null : category;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.videoCamera,
            size: 64,
            color: Colors.grey[350],
          ),
          const SizedBox(height: 24),
          const Text(
            'NO FAVOURITE REELS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Like reels to see them here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              letterSpacing: 0.3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'GO BACK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
