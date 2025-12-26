import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../services/search_history_service.dart';
import 'search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  
  const SearchScreen({super.key, this.initialQuery = ''});

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
    {'icon': PhosphorIconsRegular.tShirt, 'label': 'SHIRTS'},
    {'icon': PhosphorIconsRegular.pants, 'label': 'PANTS'},
    {'icon': PhosphorIconsRegular.sparkle, 'label': 'SKINCARE'},
  ];

  int _currentIndex = 0;
  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialQuery.isNotEmpty) {
      _controller.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchSuggestions(widget.initialQuery);
      });
    }

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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
    setState(() {});
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    setState(() => _isLoadingSuggestions = true);

    final url = Uri.parse(
      'https://suggestions-alpha.vercel.app/suggest?q=$query',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _suggestions = List<Map<String, dynamic>>.from(data);
            _isLoadingSuggestions = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSuggestions = false);
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _performSearch(query);
  }

  void _performSearch(String query) {
    _historyService.addSearchQuery(query);
    Navigator.push(
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
          if (_controller.text.isNotEmpty)
            _buildSuggestionsList()
          else if (_searchHistory.isNotEmpty)
            _buildSearchHistory(),
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
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                onPressed: () {
                  _controller.clear();
                  _onSearchChanged('');
                  setState(() {});
                  _focus.requestFocus();
                },
                splashRadius: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            IconButton(
              icon: Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 20,
                color: _focus.hasFocus ? Colors.black : Colors.grey[600],
              ),
              onPressed: _submit,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Icon(icon, size: 20, color: Colors.grey[700]);
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
                  onTap: () => _performSearch(query),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_isLoadingSuggestions) {
      return const Expanded(
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _suggestions.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          final term = suggestion['term'] as String;
          final display = suggestion['display'] as String;
          final type = suggestion['type'] as String;

          IconData icon;
          switch (type) {
            case 'category':
              icon = PhosphorIconsRegular.squaresFour;
              break;
            case 'subcategory':
              icon = PhosphorIconsRegular.tag;
              break;
            case 'combination':
              icon = PhosphorIconsRegular.tShirt;
              break;
            default:
              icon = PhosphorIconsRegular.magnifyingGlass;
          }

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(icon, size: 18, color: Colors.grey[600]),
            title: Text(
              display,
              style: const TextStyle(fontSize: 14, letterSpacing: 0.3),
            ),
            onTap: () => _performSearch(term),
          );
        },
      ),
    );
  }
}
