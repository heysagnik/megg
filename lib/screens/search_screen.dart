import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../widgets/custom_icons.dart';
import '../services/search_history_service.dart';
import 'search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final SearchHistoryService _historyService = SearchHistoryService();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final List<Map<String, dynamic>> _categories = [
    {'icon': CustomIcons.shirt, 'label': 'SHIRTS'},
    {'icon': CustomIcons.pants, 'label': 'PANTS'},
    {'icon': CustomIcons.skincare, 'label': 'SKINCARE'},
  ];

  int _currentIndex = 0;
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % _categories.length;
            });
            _animationController.reset();
            _animationController.forward();
          }
        });
      }
    });

    _animationController.forward();

    // Autofocus to bring up the keyboard immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());

    // Load search history
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _historyService.getSearchHistory();
    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // Save to search history
    _historyService.addSearchQuery(query);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(initialQuery: query),
      ),
    );
  }

  void _searchFromHistory(String query) {
    // Save to history (moves it to top)
    _historyService.addSearchQuery(query);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(initialQuery: query),
      ),
    );
  }

  Future<void> _removeFromHistory(String query) async {
    await _historyService.removeSearchQuery(query);
    await _loadSearchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AestheticAppBar(title: 'SEARCH', showBackButton: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _buildSearchBar(),
          ),
          if (_searchHistory.isNotEmpty) _buildSearchHistory(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final borderColor = _focus.hasFocus
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.15);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Animated category icon carousel
            SizedBox(
              width: 24,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  final category = _categories[_currentIndex];
                  final nextCategory =
                      _categories[(_currentIndex + 1) % _categories.length];

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Current item sliding out
                      Opacity(
                        opacity: 1.0 - _slideAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, -20 * _slideAnimation.value),
                          child: _buildCategoryItem(
                            category['icon'],
                            category['label'],
                          ),
                        ),
                      ),
                      // Next item sliding in
                      Opacity(
                        opacity: _slideAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                          child: _buildCategoryItem(
                            nextCategory['icon'],
                            nextCategory['label'],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                style: const TextStyle(fontSize: 14, letterSpacing: 0.5),
                decoration: InputDecoration(
                  hintText: 'Search styles, products...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  _focus.requestFocus();
                },
                splashRadius: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            IconButton(
              icon: CustomIcons.search(
                size: 20,
                color: _focus.hasFocus ? Colors.black : Colors.grey[600]!,
              ),
              onPressed: _submit,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    Widget Function({double size, Color color, bool filled}) iconBuilder,
    String label,
  ) {
    return iconBuilder(size: 20, color: Colors.grey[700]!);
  }

  Widget _buildSearchHistory() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'RECENT SEARCHES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final query = _searchHistory[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  title: Text(
                    query,
                    style: const TextStyle(fontSize: 14, letterSpacing: 0.3),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      PhosphorIconsRegular.x,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    onPressed: () => _removeFromHistory(query),
                    splashRadius: 18,
                    padding: const EdgeInsets.all(8),
                  ),
                  onTap: () => _searchFromHistory(query),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
