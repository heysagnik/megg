import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel.dart';
import '../models/product.dart';
import '../services/reel_service.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_download_service.dart';
import '../widgets/loader.dart';
import '../widgets/product_widget.dart';
import 'product_screen.dart';
import 'reel_products_screen.dart';

class CategoryReelsScreen extends StatefulWidget {
  final String category;
  final String? initialReelId; // For deep linking

  const CategoryReelsScreen({
    super.key, 
    required this.category,
    this.initialReelId,
  });

  @override
  State<CategoryReelsScreen> createState() => _CategoryReelsScreenState();
}

class _CategoryReelsScreenState extends State<CategoryReelsScreen>
    with WidgetsBindingObserver {
  final ReelService _reelService = ReelService();
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();

  List<Reel> _reels = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _viewedReels = {};
  final Set<String> _likedReels = {};
  final Map<String, int> _likeCounts = {};
  int _currentPageIndex = 0;
  bool _isMutedDueToCall = false;
  final Map<int, GlobalKey<_ReelItemState>> _reelKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReels();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do nothing on lifecycle changes to keep video playing
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReels() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      List<Reel> reels = [];
      
      // Check connectivity status first
      await ConnectivityService().checkRealConnectivity();
      final isOffline = ConnectivityService().isOffline;
      final hasOfflineData = OfflineDownloadService().isOfflineModeEnabled;
      
      debugPrint('[CategoryReels] isOffline: $isOffline, hasOfflineData: $hasOfflineData');
      
      // If offline and have downloaded data, use it immediately
      if (isOffline && hasOfflineData) {
        debugPrint('[CategoryReels] Loading from offline storage...');
        final offlineReels = await OfflineDownloadService().getOfflineReels();
        debugPrint('[CategoryReels] Got ${offlineReels.length} offline reels');
        
        // Filter by category
        final categoryReels = offlineReels.where(
          (r) => (r['category'] as String?)?.toLowerCase() == widget.category.toLowerCase()
        ).toList();
        debugPrint('[CategoryReels] Filtered to ${categoryReels.length} reels for category: ${widget.category}');
        
        reels = categoryReels.map((json) {
          // Use local video path if available
          final localVideoPath = json['local_video_path'] as String?;
          return Reel.fromJson({
            ...json,
            if (localVideoPath != null) 'video_url': localVideoPath,
          });
        }).toList();
      } else {
        // Try network
        try {
          reels = await _reelService.getReelsByCategory(widget.category);
        } catch (e) {
          debugPrint('[CategoryReels] Network failed: $e');
          // Network failed, try offline data as fallback
          if (hasOfflineData) {
            final offlineReels = await OfflineDownloadService().getOfflineReels();
            final categoryReels = offlineReels.where(
              (r) => (r['category'] as String?)?.toLowerCase() == widget.category.toLowerCase()
            ).toList();
            
            reels = categoryReels.map((json) {
              final localVideoPath = json['local_video_path'] as String?;
              return Reel.fromJson({
                ...json,
                if (localVideoPath != null) 'video_url': localVideoPath,
              });
            }).toList();
          } else {
            rethrow;
          }
        }
      }

      if (!mounted) return;

      Set<String> likedReelIds = {};
      if (_authService.isAuthenticated) {
        try {
          likedReelIds = await _reelService.getLikedReelIds();
        } catch (e) {
          // Silently fail - user can still view reels without like state
        }
      }

      if (!mounted) return;

      setState(() {
        _reels = reels;
        _isLoading = false;
        _likedReels.clear();
        _likedReels.addAll(likedReelIds);

        for (var reel in reels) {
          _likeCounts[reel.id] = reel.likes;
        }
      });

      // Handle initial reel ID from deep link
      if (widget.initialReelId != null && reels.isNotEmpty) {
        final initialIndex = reels.indexWhere((r) => r.id == widget.initialReelId);
        if (initialIndex >= 0) {
          debugPrint('[Reels] Scrolling to initial reel at index $initialIndex');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(initialIndex);
            }
          });
          _trackView(reels[initialIndex].id);
        } else {
          _trackView(reels[0].id);
        }
      } else if (reels.isNotEmpty) {
        _trackView(reels[0].id);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _trackView(String reelId) {
    if (!_viewedReels.contains(reelId)) {
      _viewedReels.add(reelId);
      _reelService.incrementViews(reelId);
    }
  }

  Future<void> _toggleLike(String reelId) async {
    final isLiked = _likedReels.contains(reelId);
    final willLike = !isLiked;

    setState(() {
      if (isLiked) {
        _likedReels.remove(reelId);
        _likeCounts[reelId] = (_likeCounts[reelId] ?? 1) - 1;
        if (_likeCounts[reelId]! < 0) _likeCounts[reelId] = 0;
      } else {
        _likedReels.add(reelId);
        _likeCounts[reelId] = (_likeCounts[reelId] ?? 0) + 1;
      }
    });

    try {
      // Call API with like: true or like: false
      await _reelService.toggleLike(reelId, like: willLike);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isLiked) {
            // Was liked, tried to unlike, failed -> restore liked state
            _likedReels.add(reelId);
            _likeCounts[reelId] = (_likeCounts[reelId] ?? 0) + 1;
          } else {
            // Was not liked, tried to like, failed -> restore unliked state
            _likedReels.remove(reelId);
            _likeCounts[reelId] = (_likeCounts[reelId] ?? 1) - 1;
            if (_likeCounts[reelId]! < 0) _likeCounts[reelId] = 0;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(willLike ? 'FAILED TO LIKE' : 'FAILED TO UNLIKE'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openLink(String? link) async {
    if (link == null || link.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NO LINK AVAILABLE'),
            backgroundColor: Colors.black87,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      // Ensure link has proper scheme
      String finalLink = link;
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        finalLink = 'https://$link';
      }

      final uri = Uri.parse(finalLink);
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw 'Failed to launch URL';
        }
      } else {
        throw 'Cannot launch URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UNABLE TO OPEN LINK: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareReel(Reel reel) async {
    try {
      const String playStoreLink =
          'https://play.google.com/store/apps/details?id=com.megg.megg';
      final String categoryName = widget.category;
      final String affiliateLink = reel.affiliateLink ?? '';

      final String shareText =
          'Browse the $categoryName from here $affiliateLink. '
          'For more download this app from play store. $playStoreLink';

      await Share.share(shareText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  
  void _handleShopTap(Reel reel) {
    if (reel.hasProducts) {
      _showProductsSheet(reel);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NO PRODUCTS LINKED'),
            backgroundColor: Colors.black87,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Navigate to products page for this reel
  void _showProductsSheet(Reel reel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelProductsScreen(
          productIds: reel.productIds,
          reelCategory: reel.category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              PhosphorIconsRegular.x,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: Loader(showCaption: false));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_reels.isEmpty) {
      return _buildEmptyState();
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final reelIndex = index % _reels.length;
        final reel = _reels[reelIndex];

        if (!_reelKeys.containsKey(reelIndex)) {
          _reelKeys[reelIndex] = GlobalKey<_ReelItemState>();
        }

        return _ReelItem(
          key: _reelKeys[reelIndex],
          reel: reel,
          isLiked: _likedReels.contains(reel.id),
          likeCount: _likeCounts[reel.id] ?? reel.likes,
          onLike: () => _toggleLike(reel.id),
          onShopTap: () => _handleShopTap(reel),
          onShareTap: () => _shareReel(reel),
          isCurrentPage: reelIndex == _currentPageIndex,
          isMutedDueToCall: _isMutedDueToCall,
        );
      },
      onPageChanged: (index) {
        final newIndex = index % _reels.length;

        // Update current index and track view
        setState(() => _currentPageIndex = newIndex);
        _trackView(_reels[newIndex].id);
      },
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'ERROR LOADING REELS',
              style: TextStyle(
                color: Colors.white,
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
                color: Colors.grey[400],
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadReels,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.videoCamera,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            'NO REELS AVAILABLE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Check back later for new content',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final Reel reel;
  final bool isLiked;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback onShopTap;
  final VoidCallback onShareTap;
  final bool isCurrentPage;
  final bool isMutedDueToCall;

  const _ReelItem({
    super.key,
    required this.reel,
    required this.isLiked,
    required this.likeCount,
    required this.onLike,
    required this.onShopTap,
    required this.onShareTap,
    required this.isCurrentPage,
    this.isMutedDueToCall = false,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  double _swipeOffset = 0;
  bool _showLikeAnimation = false;
  bool _showPauseIndicator = false;
  Size? _cachedVideoSize;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(_ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reel.videoUrl != oldWidget.reel.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _showPauseIndicator = false;
      _cachedVideoSize = null;
      _initializeVideo();
    } else if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage) {
        playVideo();
      } else {
        pauseVideo();
      }
    }

    if (widget.isMutedDueToCall != oldWidget.isMutedDueToCall) {
      _controller?.setVolume(widget.isMutedDueToCall ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (!widget.isCurrentPage) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || widget.isCurrentPage) return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.reel.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();

      if (!mounted) return;

      final videoSize = _controller!.value.size;
      setState(() {
        _isInitialized = true;
        _cachedVideoSize = videoSize;
      });

      _controller!.setLooping(true);

      // Only auto-play if this is the current page
      if (widget.isCurrentPage) {
        _controller!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showPauseIndicator = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showPauseIndicator = false);
      });
    } else {
      _controller!.play();
      setState(() => _showPauseIndicator = false);
    }
  }

  void _handleDoubleTap() {
    widget.onLike();

    // Show like animation
    setState(() => _showLikeAnimation = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showLikeAnimation = false);
      }
    });
  }

  // Public methods for parent to control playback
  void pauseVideo() {
    if (_controller != null && _isInitialized && _controller!.value.isPlaying) {
      _controller!.pause();
      if (mounted) setState(() {});
    }
  }

  void playVideo() {
    if (_controller != null &&
        _isInitialized &&
        !_controller!.value.isPlaying) {
      _controller!.play();
      if (mounted) setState(() {});
    }
  }

  void setMuted(bool muted) {
    _controller?.setVolume(muted ? 0.0 : 1.0);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _handleDoubleTap,
      onHorizontalDragUpdate: (details) {
        if (widget.reel.affiliateLink != null &&
            widget.reel.affiliateLink!.isNotEmpty) {
          setState(() {
            _swipeOffset += details.delta.dx;
            _swipeOffset = _swipeOffset.clamp(-100.0, 0.0);
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_swipeOffset < -50) {
          widget.onShopTap();
        }
        setState(() {
          _swipeOffset = 0;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or thumbnail
          if (_hasError)
            _buildErrorView()
          else if (_isInitialized &&
              _controller != null &&
              _cachedVideoSize != null)
            RepaintBoundary(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cachedVideoSize!.width,
                    height: _cachedVideoSize!.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            )
          else
            _buildLoadingView(),

          // Gradient Overlay for better text visibility
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Play/Pause indicator (shown briefly then hidden)
          if (_showPauseIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.pause,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Like animation overlay
          if (_showLikeAnimation)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.5 + (value * 0.8),
                    child: Opacity(
                      opacity: 1.0 - value,
                      child: Icon(
                        PhosphorIconsFill.heart,
                        color: Colors.red,
                        size: 120,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Action buttons (Right Side)
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: widget.isLiked
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
                  label: _formatCount(widget.likeCount),
                  onTap: widget.onLike,
                  color: widget.isLiked
                      ? const Color(0xFFFF3040)
                      : Colors.white,
                ),
                const SizedBox(height: 20),
                if (widget.reel.affiliateLink != null &&
                    widget.reel.affiliateLink!.isNotEmpty) ...[
                  _ActionButton(
                    icon: PhosphorIconsRegular.bag,
                    label: 'Shop',
                    onTap: widget.onShopTap,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                ],
                _ActionButton(
                  icon: PhosphorIconsRegular.shareFat,
                  label: 'Share',
                  onTap: widget.onShareTap,
                  color: Colors.white,
                ),
              ],
            ),
          ),

          // Bottom info section (Left Side)
          Positioned(
            left: 16,
            right: 100,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Views Count
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.eye,
                      color: Colors.white,
                      size: 16,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatCount(widget.reel.views)} views',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                      ),
                    ),
                  ],
                ),

                // Shop CTA - show if reel has linked products
                if (widget.reel.hasProducts) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onShopTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Shop this look',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 2),
                              ],
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            PhosphorIconsRegular.arrowRight,
                            color: Colors.white,
                            size: 14,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 2),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.reel.thumbnailUrl.isNotEmpty)
            Image.network(
              widget.reel.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    PhosphorIconsRegular.videoCamera,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          const Center(child: Loader(showCaption: false)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'VIDEO UNAVAILABLE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // Removed background circle, added shadow for visibility
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 32, // Increased size slightly
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet to display products linked to a reel
class _ProductsBottomSheet extends StatefulWidget {
  final List<String> productIds;
  final String reelCategory;

  const _ProductsBottomSheet({
    required this.productIds,
    required this.reelCategory,
  });

  @override
  State<_ProductsBottomSheet> createState() => _ProductsBottomSheetState();
}

class _ProductsBottomSheetState extends State<_ProductsBottomSheet> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getProductsByIds(widget.productIds);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    
    return Container(
      height: height,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHOP THIS LOOK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.productIds.length} ITEMS',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: Loader(showCaption: false));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIconsRegular.warningCircle, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'UNABLE TO LOAD PRODUCTS',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadProducts();
                },
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.package, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'NO PRODUCTS FOUND',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1.5,
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
            Navigator.pop(context); // Close bottom sheet
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductScreen(product: product),
              ),
            );
          },
        );
      },
    );
  }
}
