import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import '../models/video_file.dart';
import '../widgets/video_thumbnail.dart';
import '../services/recent_files_service.dart';
import '../video_player_screen.dart';
import '../nextplayer_video_player.dart';
import '../ui_improvements/modern_theme.dart';

enum SortOption { name, size, date, type }
enum ViewMode { list, grid }

class ModernVideoFilesScreen extends StatefulWidget {
  final String folderPath;
  final String folderName;
  
  const ModernVideoFilesScreen({
    Key? key,
    required this.folderPath,
    required this.folderName,
  }) : super(key: key);
  
  @override
  State<ModernVideoFilesScreen> createState() => _ModernVideoFilesScreenState();
}

class _ModernVideoFilesScreenState extends State<ModernVideoFilesScreen>
    with TickerProviderStateMixin {
  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'];
  final TextEditingController _searchController = TextEditingController();
  
  List<VideoFile> _allVideoFiles = [];
  List<VideoFile> _filteredVideoFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  SortOption _currentSort = SortOption.name;
  bool _sortAscending = true;
  ViewMode _viewMode = ViewMode.list;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadVideoFiles();
    _searchController.addListener(_onSearchChanged);
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterAndSortFiles();
    });
  }

  Future<void> _loadVideoFiles() async {
    try {
      final directory = Directory(widget.folderPath);
      final entities = await directory.list().toList();
      
      List<VideoFile> videoFiles = [];
      
      for (final entity in entities) {
        if (FileManager.isFile(entity)) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (videoExtensions.any((ext) => entity.path.toLowerCase().endsWith(ext))) {
            final stat = await entity.stat();
            videoFiles.add(VideoFile.fromFileSystemEntity(entity, stat));
          }
        }
      }
      
      setState(() {
        _allVideoFiles = videoFiles;
        _filteredVideoFiles = videoFiles;
        _isLoading = false;
      });
      
      _filterAndSortFiles();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading video files: $e');
    }
  }

  void _filterAndSortFiles() {
    List<VideoFile> filtered = _allVideoFiles;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((file) =>
          file.name.toLowerCase().contains(_searchQuery)).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (_currentSort) {
        case SortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SortOption.size:
          comparison = a.size.compareTo(b.size);
          break;
        case SortOption.date:
          comparison = a.lastModified.compareTo(b.lastModified);
          break;
        case SortOption.type:
          comparison = a.extension.compareTo(b.extension);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
    setState(() {
      _filteredVideoFiles = filtered;
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ModernTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort by',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ...SortOption.values.map((option) => ListTile(
              leading: Icon(
                _getSortIcon(option),
                color: _currentSort == option ? ModernTheme.primaryColor : ModernTheme.textSecondary,
              ),
              title: Text(
                _getSortLabel(option),
                style: TextStyle(
                  color: _currentSort == option ? ModernTheme.primaryColor : ModernTheme.textPrimary,
                  fontWeight: _currentSort == option ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: _currentSort == option
                  ? Icon(
                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: ModernTheme.primaryColor,
                    )
                  : null,
              onTap: () {
                setState(() {
                  if (_currentSort == option) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _currentSort = option;
                    _sortAscending = true;
                  }
                  _filterAndSortFiles();
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.name:
        return Icons.sort_by_alpha;
      case SortOption.size:
        return Icons.storage;
      case SortOption.date:
        return Icons.access_time;
      case SortOption.type:
        return Icons.category;
    }
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.name:
        return 'Name';
      case SortOption.size:
        return 'Size';
      case SortOption.date:
        return 'Date Modified';
      case SortOption.type:
        return 'File Type';
    }
  }

  void _showPlayerSelectionDialog(VideoFile videoFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ModernTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Choose Video Player',
            style: TextStyle(color: ModernTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select your preferred video player for:',
                style: TextStyle(color: ModernTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                videoFile.name,
                style: const TextStyle(
                  color: ModernTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            // NextPlayer Option
            Container(
              width: double.maxFinite,
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.video_library, size: 24),
                label: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NextPlayer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'RECOMMENDED',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _playVideo(videoFile, true);
                },
              ),
            ),
            
            // Original Player Option
            SizedBox(
              width: double.maxFinite,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: ModernTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Original Player'),
                onPressed: () {
                  Navigator.pop(context);
                  _playVideo(videoFile, false);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _playVideo(VideoFile videoFile, bool useNextPlayer) async {
    // Add to recent files
    await RecentFilesService.addRecentFile(videoFile.path);
    
    if (useNextPlayer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NextPlayerVideoPlayer(
            videoPath: videoFile.path,
            videoTitle: videoFile.name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomVideoPlayer(
            videoPath: videoFile.path,
            videoTitle: videoFile.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Video Files',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ModernTheme.textPrimary),
            ),
            Text(
              widget.folderName,
              style: const TextStyle(fontSize: 12, color: ModernTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: ModernTheme.surfaceColor,
        elevation: 1,
        iconTheme: const IconThemeData(color: ModernTheme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(_viewMode == ViewMode.list ? Icons.grid_view : Icons.list),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: ModernTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search video files...',
                hintStyle: const TextStyle(color: ModernTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: ModernTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: ModernTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: ModernTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Results Info
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredVideoFiles.length} video${_filteredVideoFiles.length != 1 ? 's' : ''} found',
                    style: const TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const Text(
                      ' • ',
                      style: TextStyle(color: ModernTheme.textSecondary),
                    ),
                    Text(
                      'Filtered by "$_searchQuery"',
                      style: const TextStyle(
                        color: ModernTheme.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Video Files List/Grid
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ModernTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading video files...',
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_filteredVideoFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.video_file_outlined,
              size: 64,
              color: ModernTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No videos found for "$_searchQuery"'
                  : 'No video files found in this folder',
              style: const TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                },
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _viewMode == ViewMode.list ? _buildListView() : _buildGridView(),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredVideoFiles.length,
      itemBuilder: (context, index) {
        final videoFile = _filteredVideoFiles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: ModernTheme.cardColor,
          child: ListTile(
            leading: VideoThumbnailWidget(
              videoPath: videoFile.path,
              width: 60,
              height: 40,
              borderRadius: BorderRadius.circular(6),
            ),
            title: Text(
              videoFile.name,
              style: const TextStyle(
                color: ModernTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${videoFile.formattedSize} • ${videoFile.extension.toUpperCase()}',
                  style: const TextStyle(color: ModernTheme.textSecondary),
                ),
                Text(
                  videoFile.formattedDuration,
                  style: const TextStyle(color: ModernTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            trailing: const Icon(
              Icons.play_circle_outline,
              color: ModernTheme.primaryColor,
              size: 32,
            ),
            onTap: () => _showPlayerSelectionDialog(videoFile),
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredVideoFiles.length,
      itemBuilder: (context, index) {
        final videoFile = _filteredVideoFiles[index];
        return Card(
          color: ModernTheme.cardColor,
          child: InkWell(
            onTap: () => _showPlayerSelectionDialog(videoFile),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: VideoThumbnailWidget(
                      videoPath: videoFile.path,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    videoFile.name,
                    style: const TextStyle(
                      color: ModernTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${videoFile.formattedSize} • ${videoFile.extension.toUpperCase()}',
                    style: const TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}