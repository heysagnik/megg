import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/reel.dart';
import '../services/reel_service.dart';
import '../widgets/loader.dart';

class LikedReelsScreen extends StatefulWidget {
  const LikedReelsScreen({super.key});

  @override
  State<LikedReelsScreen> createState() => _LikedReelsScreenState();
}

class _LikedReelsScreenState extends State<LikedReelsScreen>
    with WidgetsBindingObserver {
  final ReelService _reelService = ReelService();
  final PageController _pageController = PageController();

  List<Reel> _reels = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _viewedReels = {};
  final Set<String> _likedReels = {};
  final Map<String, int> _likeCounts = {};
  int _currentPageIndex = 0;
  final Map<int, GlobalKey<_ReelItemState>> _reelKeys = {};
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      _isInitialLoad = false;
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadReels();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _reelKeys[_currentPageIndex]?.currentState?.pauseVideo();
    } else if (state == AppLifecycleState.resumed) {
      _loadReels();
    }
  }

  Future<void> _loadReels() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final reels = await _reelService.getLikedReels();

      if (!mounted) return;

      setState(() {
        _reels = reels;
        _isLoading = false;
        _likedReels.clear();
        _likeCounts.clear();
        _reelKeys.clear();
        _currentPageIndex = 0;

        for (var reel in reels) {
          _likeCounts[reel.id] = reel.likes;
          _likedReels.add(reel.id);
        }
      });

      if (reels.isNotEmpty && _pageController.hasClients) {
        _pageController.jumpToPage(0);
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
    Reel? removedReel;

    setState(() {
      if (isLiked) {
        _likedReels.remove(reelId);
        _likeCounts[reelId] = (_likeCounts[reelId] ?? 1) - 1;
        if (_likeCounts[reelId]! < 0) _likeCounts[reelId] = 0;
        removedReel = _reels.firstWhere((reel) => reel.id == reelId);
        final removedIndex = _reels.indexWhere((reel) => reel.id == reelId);
        _reels.removeWhere((reel) => reel.id == reelId);
        if (_reels.isNotEmpty) {
          if (_currentPageIndex >= _reels.length) {
            _currentPageIndex = _reels.length - 1;
          } else if (removedIndex <= _currentPageIndex &&
              _currentPageIndex > 0) {
            _currentPageIndex = _currentPageIndex - 1;
          }
        } else {
          _currentPageIndex = 0;
        }
      } else {
        _likedReels.add(reelId);
        _likeCounts[reelId] = (_likeCounts[reelId] ?? 0) + 1;
      }
    });

    try {
      await _reelService.toggleLike(reelId, like: willLike);

      if (isLiked && _reels.isEmpty && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isLiked && removedReel != null) {
            _likedReels.add(reelId);
            _likeCounts[reelId] = (_likeCounts[reelId] ?? 0) + 1;
            if (!_reels.any((r) => r.id == reelId)) {
              _reels.add(removedReel!);
            }
          } else {
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
      print('Failed to toggle like: $e');
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
      print('Attempting to open link: $link');

      String finalLink = link;
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        finalLink = 'https://$link';
      }

      final uri = Uri.parse(finalLink);
      print('Parsed URI: $uri');

      final canLaunch = await canLaunchUrl(uri);
      print('Can launch URL: $canLaunch');

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('Launch result: $launched');

        if (!launched) {
          throw 'Failed to launch URL';
        }
      } else {
        throw 'Cannot launch URL';
      }
    } catch (e) {
      print('Error opening link: $e');
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
        title: const Text(
          'FAVOURITE REELS',
          style: TextStyle(
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
      itemCount: _reels.length,
      onPageChanged: (index) {
        _reelKeys[_currentPageIndex]?.currentState?.pauseVideo();

        setState(() => _currentPageIndex = index);
        _trackView(_reels[index].id);

        Future.delayed(const Duration(milliseconds: 100), () {
          _reelKeys[index]?.currentState?.playVideo();
        });
      },
      itemBuilder: (context, index) {
        final reel = _reels[index];
        if (!_reelKeys.containsKey(index)) {
          _reelKeys[index] = GlobalKey<_ReelItemState>();
        }

        return _ReelItem(
          key: _reelKeys[index],
          reel: reel,
          isLiked: _likedReels.contains(reel.id),
          likeCount: _likeCounts[reel.id] ?? reel.likes,
          onLike: () => _toggleLike(reel.id),
          onShopTap: () => _openLink(reel.affiliateLink),
          isCurrentPage: index == _currentPageIndex,
        );
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
          Icon(PhosphorIconsRegular.heart, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text(
            'NO FAVOURITE REELS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Like reels to see them here',
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
  final bool isCurrentPage;

  const _ReelItem({
    super.key,
    required this.reel,
    required this.isLiked,
    required this.likeCount,
    required this.onLike,
    required this.onShopTap,
    required this.isCurrentPage,
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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.reel.videoUrl),
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      _controller!.setLooping(true);

      if (widget.isCurrentPage) {
        _controller!.play();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _handleDoubleTap() {
    widget.onLike();

    setState(() => _showLikeAnimation = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showLikeAnimation = false);
      }
    });
  }

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
          if (_hasError)
            _buildErrorView()
          else if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            _buildLoadingView(),

          if (_isInitialized &&
              _controller != null &&
              !_controller!.value.isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.play,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

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

          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _ActionButton(
                  icon: widget.isLiked
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
                  label: widget.likeCount.toString(),
                  onTap: widget.onLike,
                  color: widget.isLiked ? Colors.red : Colors.white,
                ),
                if (widget.reel.affiliateLink != null &&
                    widget.reel.affiliateLink!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _ActionButton(
                    icon: PhosphorIconsRegular.shoppingBag,
                    label: null,
                    onTap: widget.onShopTap,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 80,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.eye,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.reel.views} views',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (widget.reel.affiliateLink != null &&
                    widget.reel.affiliateLink!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'SWIPE LEFT FOR PRODUCTS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
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
              fit: BoxFit.contain,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
