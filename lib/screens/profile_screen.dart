import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/product.dart';
import '../models/reel.dart';
import '../services/auth_service.dart';
import '../services/wishlist_service.dart';
import '../services/reel_service.dart';
import '../services/cache_service.dart';
import '../widgets/aesthetic_app_bar.dart';
import 'product_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';
import '../widgets/product_widget.dart';
import 'liked_reels_screen.dart';
import 'wishlist_screen.dart';
import 'favourite_reels_grid_screen.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final WishlistService _wishlistService = WishlistService();
  final ReelService _reelService = ReelService();

  List<Product> _wishlist = [];
  List<Reel> _likedReels = [];
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;
  final Set<String> _wishlistIds = {};
  Timer? _wishlistRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Immediately show cached data (no loading), then refresh in background
    _primeFromCacheThenRefresh();
    // Periodically refresh wishlist cache in background while on this screen
    _wishlistRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshWishlistInBackground(),
    );
  }

  @override
  void dispose() {
    _wishlistRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData({bool forceRefresh = false}) async {
    if (!_authService.isAuthenticated) {
      setState(() {
        _errorMessage = null;
        _userProfile = null;
        _wishlist = [];
        _wishlistIds.clear();
      });
      return;
    }

    try {
      // Use cached data by default, force refresh when specified
      final profileFuture = _authService.getProfile();
      final wishlistFuture = _wishlistService.getWishlist(
        forceRefresh: forceRefresh,
      );

      final results = await Future.wait([profileFuture, wishlistFuture]);

      if (!mounted) return;

      setState(() {
        _userProfile = results[0] as Map<String, dynamic>;
        _wishlist = results[1] as List<Product>;
        _wishlistIds.clear();
        _wishlistIds.addAll(_wishlist.map((p) => p.id));
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Quickly set UI from cached wishlist, then trigger background refresh
  Future<void> _primeFromCacheThenRefresh() async {
    try {
      // Set basic user data from auth immediately (no network)
      _userProfile ??= {
        'name': _authService.currentUser?.userMetadata?['name'] ?? 'User',
        'email': _authService.currentUser?.email ?? '',
      };

      // Read cached wishlist (if any) directly for instant UI
      final cached = await CacheService().getListCache('wishlist');
      if (cached != null) {
        final cachedProducts = cached
            .map((json) => Product.fromJson(json))
            .toList(growable: false);
        if (mounted) {
          setState(() {
            _wishlist = cachedProducts;
            _wishlistIds
              ..clear()
              ..addAll(_wishlist.map((p) => p.id));
          });
        }
      } else {
        // If no full product cache, try to load from wishlist IDs cache
        final cachedIds = await _wishlistService.getWishlistIds();
        if (mounted && cachedIds.isNotEmpty) {
          setState(() {
            _wishlistIds
              ..clear()
              ..addAll(cachedIds);
          });
        }
      }
    } catch (e) {
      // Silently ignore cache errors in production; UI will refresh from network
    } finally {
      // Regardless of cache, refresh in background without loaders
      _refreshWishlistInBackground();
      _refreshLikedReelsInBackground();
    }
  }

  Future<void> _refreshLikedReelsInBackground() async {
    if (!_authService.isAuthenticated) return;
    try {
      final reels = await _reelService.getLikedReels();
      if (!mounted) return;
      setState(() {
        _likedReels = reels;
      });
    } catch (e) {
      // Keep showing cached UI on errors
    }
  }

  Future<void> _refreshWishlistInBackground() async {
    try {
      // This will work for both authenticated and non-authenticated users
      final updated = await _wishlistService.getWishlist(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _wishlist = updated;
        _wishlistIds
          ..clear()
          ..addAll(_wishlist.map((p) => p.id));
      });
    } catch (e) {
      // Keep showing cached UI on errors
    }
  }

  Future<void> _handleWishlistToggle(String productId) async {
    final wasInWishlist = _wishlistIds.contains(productId);

    // Optimistically update UI
    setState(() {
      if (wasInWishlist) {
        _wishlistIds.remove(productId);
        _wishlist.removeWhere((p) => p.id == productId);
      }
    });

    try {
      if (wasInWishlist) {
        await _wishlistService.removeFromWishlist(productId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('REMOVED FROM WISHLIST'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.black,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (wasInWishlist) {
            _wishlistIds.add(productId);
            // Re-fetch to restore the full product data
            _loadProfileData();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove from wishlist'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearAllWishlist() async {
    if (_wishlist.isEmpty) return;

    // Store products for potential revert
    final productsToRemove = List<Product>.from(_wishlist);
    final idsToRemove = List<String>.from(_wishlistIds);

    // Optimistically update UI
    setState(() {
      _wishlist.clear();
      _wishlistIds.clear();
    });

    try {
      // Remove all items from server
      for (final product in productsToRemove) {
        await _wishlistService.removeFromWishlist(product.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ALL ITEMS REMOVED'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      // Revert on error
      if (!mounted) return;

      setState(() {
        _wishlist.addAll(productsToRemove);
        _wishlistIds.addAll(idsToRemove);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ERROR: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AestheticAppBar(
        title: 'PROFILE',
        actions: [
          if (_authService.isAuthenticated)
            IconButton(
              icon: Icon(PhosphorIconsRegular.gear, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              splashRadius: 20,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildProfileHeader(),
          const SizedBox(height: 16),

          // Sign Out / Sign In button right below profile
          if (_authService.isAuthenticated) ...[
            _buildSignOutButton(),
          ] else ...[
            _buildSignInButton(),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.black.withOpacity(0.08),
            ),
          ),

          // Wishlist Section with VIEW ALL
          _buildWishlist(),

          const SizedBox(height: 24),

          // Favourite Reels Section (only for authenticated users)
          if (_authService.isAuthenticated) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.black.withOpacity(0.08),
              ),
            ),
            const SizedBox(height: 16),
            _buildFavouriteReelsSection(),
          ],

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return TextButton(
      onPressed: _handleLogout,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: Colors.grey[600],
      ),
      child: const Text(
        'SIGN OUT',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildFavouriteReelsSection() {
    final size = MediaQuery.of(context).size;
    final double itemWidth = (size.width * 0.28).clamp(100.0, 140.0);
    final double itemHeight = itemWidth * 1.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'FAVOURITE REELS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              if (_likedReels.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FavouriteReelsGridScreen(initialReels: _likedReels),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_likedReels.isEmpty)
          _buildEmptyReelsState()
        else
          SizedBox(
            height: itemHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _likedReels.length > 10 ? 10 : _likedReels.length,
              itemBuilder: (context, index) {
                final reel = _likedReels[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LikedReelsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: itemWidth,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Colors.grey[100]),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        reel.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                reel.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Icon(
                                        PhosphorIconsRegular.videoCamera,
                                        size: 24,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    PhosphorIconsRegular.videoCamera,
                                    size: 24,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                        // Gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Play icon - subtle
                        Center(
                          child: Icon(
                            PhosphorIconsRegular.play,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                        ),
                        // Views count at bottom
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.play,
                                color: Colors.white.withOpacity(0.9),
                                size: 10,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(reel.views),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
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
      ],
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

  Widget _buildEmptyReelsState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              PhosphorIconsRegular.videoCamera,
              size: 40,
              color: Colors.grey[350],
            ),
            const SizedBox(height: 16),
            const Text(
              'NO FAVOURITE REELS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Like reels to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'ERROR LOADING PROFILE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadProfileData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = _authService.currentUser;
    final userName = _authService.isAuthenticated
        ? (_userProfile?['name'] ?? user?.userMetadata?['name'] ?? 'User')
        : 'GUEST';
    final userEmail = _authService.isAuthenticated ? (user?.email ?? '') : '';
    final initials = _getInitials(userName);

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[50],
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
            image: user?.userMetadata?['avatar_url'] != null
                ? DecorationImage(
                    image: NetworkImage(user!.userMetadata!['avatar_url']),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: user?.userMetadata?['avatar_url'] == null
              ? Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      color: Colors.black,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          userName.toUpperCase(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 3,
            color: Colors.black,
          ),
        ),
        if (userEmail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            userEmail.toLowerCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildWishlist() {
    final size = MediaQuery.of(context).size;
    final double itemWidth = (size.width * 0.45).clamp(160.0, 220.0);
    final double height = itemWidth * 1.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'WISHLIST',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              if (_wishlist.isNotEmpty) ...[
                TextButton(
                  onPressed: _clearAllWishlist,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.grey[500],
                  ),
                  child: const Text(
                    'CLEAR',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WishlistScreen(initialWishlist: _wishlist),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_wishlist.isEmpty)
          _buildEmptyState()
        else
          SizedBox(
            height: height,
            child: _WishlistHorizontalList(
              products: _wishlist,
              wishlistIds: _wishlistIds,
              itemWidth: itemWidth,
              onProductTap: (product) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductScreen(product: product),
                  ),
                );
              },
              onWishlistToggle: _handleWishlistToggle,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          children: [
            Icon(PhosphorIconsRegular.heart, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 24),
            const Text(
              'NO ITEMS IN WISHLIST',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start exploring and add items',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                letterSpacing: 0.3,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          );
        },
        child: Container(
          height: 56,
          decoration: const BoxDecoration(color: Colors.black),
          child: const Center(
            child: Text(
              'SIGN IN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'SIGN OUT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 14, letterSpacing: 0.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text(
              'SIGN OUT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.signOut();

      if (!mounted) return;

      // Navigate to welcome screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SIGNED OUT SUCCESSFULLY'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SIGN OUT FAILED: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ============================================================================
// WISHLIST HORIZONTAL LIST
// ============================================================================

class _WishlistHorizontalList extends StatefulWidget {
  final List<Product> products;
  final Set<String> wishlistIds;
  final double itemWidth;
  final Function(Product) onProductTap;
  final Function(String) onWishlistToggle;

  const _WishlistHorizontalList({
    required this.products,
    required this.wishlistIds,
    required this.itemWidth,
    required this.onProductTap,
    required this.onWishlistToggle,
  });

  @override
  State<_WishlistHorizontalList> createState() =>
      _WishlistHorizontalListState();
}

class _WishlistHorizontalListState extends State<_WishlistHorizontalList> {
  final Map<String, PageController> _pageControllers = {};

  @override
  void initState() {
    super.initState();
    _initializePageControllers();
  }

  void _initializePageControllers() {
    for (final product in widget.products) {
      if (product.images.length > 1) {
        _pageControllers.putIfAbsent(product.id, () => PageController());
      }
    }
  }

  @override
  void didUpdateWidget(_WishlistHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.products != oldWidget.products) {
      _initializePageControllers();
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
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.products.length,
      itemBuilder: (context, index) {
        final product = widget.products[index];
        return SizedBox(
          width: widget.itemWidth,
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: ProductCard(
              product: product,
              isListView: false,
              onTap: () => widget.onProductTap(product),
              isWishlisted: widget.wishlistIds.contains(product.id),
              pageController: _pageControllers[product.id],
              onWishlistToggle: widget.onWishlistToggle,
            ),
          ),
        );
      },
    );
  }
}
