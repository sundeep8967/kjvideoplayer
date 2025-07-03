import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import '../video_files_screen.dart';
import '../screens/modern_video_files_screen.dart';
import 'modern_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'];
  List<FileSystemEntity> _searchResults = [];
  List<FileSystemEntity> _recentSearches = [];
  bool _isSearching = false;
  String _currentQuery = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRecentSearches();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecentSearches() {
    // TODO: Load from shared preferences
    setState(() {
      _recentSearches = [];
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    try {
      final results = await _searchVideoFiles(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      debugPrint('Search error: $e');
    }
  }

  Future<List<FileSystemEntity>> _searchVideoFiles(String query) async {
    final List<FileSystemEntity> results = [];
    final searchQuery = query.toLowerCase();
    
    try {
      // Search in common video directories
      final directories = [
        Directory('/storage/emulated/0/DCIM'),
        Directory('/storage/emulated/0/Movies'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Pictures'),
        Directory('/storage/emulated/0'),
      ];

      for (final dir in directories) {
        if (await dir.exists()) {
          await _searchInDirectory(dir, searchQuery, results);
        }
      }
    } catch (e) {
      debugPrint('Error searching files: $e');
    }

    return results;
  }

  Future<void> _searchInDirectory(Directory dir, String query, List<FileSystemEntity> results) async {
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final fileName = FileManager.basename(entity).toLowerCase();
          final hasVideoExtension = videoExtensions.any((ext) => 
            entity.path.toLowerCase().endsWith(ext));
          
          if (hasVideoExtension && fileName.contains(query)) {
            results.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching in directory ${dir.path}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.surfaceColor,
        elevation: 0,
        title: _buildSearchBar(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ModernTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_currentQuery.isEmpty) _buildSearchSuggestions(),
          if (_isSearching) _buildSearchingIndicator(),
          if (_searchResults.isNotEmpty) _buildSearchResults(),
          if (_currentQuery.isNotEmpty && !_isSearching && _searchResults.isEmpty)
            _buildNoResults(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: ModernTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: ModernTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search videos...',
          hintStyle: const TextStyle(color: ModernTheme.textSecondary),
          prefixIcon: const Icon(Icons.search, color: ModernTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: ModernTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onChanged: (value) {
          if (value.length > 2) {
            _performSearch(value);
          } else if (value.isEmpty) {
            _performSearch('');
          }
        },
        onSubmitted: _performSearch,
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Suggestions',
              style: TextStyle(
                color: ModernTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSuggestionChip('Movies'),
                _buildSuggestionChip('Camera'),
                _buildSuggestionChip('Downloaded'),
                _buildSuggestionChip('WhatsApp'),
                _buildSuggestionChip('Instagram'),
                _buildSuggestionChip('TikTok'),
              ],
            ),
            const SizedBox(height: 24),
            if (_recentSearches.isNotEmpty) ...[
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // TODO: Show recent searches
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return ActionChip(
      label: Text(suggestion),
      labelStyle: const TextStyle(color: ModernTheme.textPrimary),
      backgroundColor: ModernTheme.cardColor,
      onPressed: () {
        _searchController.text = suggestion;
        _performSearch(suggestion);
      },
    );
  }

  Widget _buildSearchingIndicator() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Searching videos...',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${_searchResults.length} videos found',
                style: const TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final file = _searchResults[index];
                  return _buildVideoResultCard(file);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoResultCard(FileSystemEntity file) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: ModernTheme.cardColor,
        child: InkWell(
          onTap: () {
            final videoTitle = FileManager.basename(file);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModernVideoFilesScreen(
                  folderPath: file.parent.path,
                  folderName: file.parent.path.split('/').last,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: ModernTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FileManager.basename(file),
                        style: const TextStyle(
                          color: ModernTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.parent.path.split('/').last,
                        style: const TextStyle(
                          color: ModernTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      FutureBuilder<FileStat>(
                        future: file.stat(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final size = snapshot.data!.size;
                            return Text(
                              FileManager.formatBytes(size),
                              style: const TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 11,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: ModernTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ModernTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.search_off,
                color: ModernTheme.textSecondary,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No videos found for "$_currentQuery"',
              style: const TextStyle(
                color: ModernTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with different keywords',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}