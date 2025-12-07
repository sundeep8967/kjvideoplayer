import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_manager/file_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/video_scanner_service.dart';
import '../../../data/models/video_model.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../widgets/ios_video_thumbnail.dart';
import '../../widgets/ios_folder_card.dart';
import '../../widgets/video_list_thumbnail.dart';
import '../../widgets/tinder_video_cards.dart';
import '../../widgets/tinder_folder_cards.dart';
import '../video_player/video_player_screen.dart';
import '../../animations/ios_page_transitions.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import 'ios_folder_screen.dart';

class IOSVideoHomeScreen extends StatefulWidget {
  const IOSVideoHomeScreen({super.key});

  @override
  State<IOSVideoHomeScreen> createState() => _IOSVideoHomeScreenState();
}

class _IOSVideoHomeScreenState extends State<IOSVideoHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _isLoading = true;
  final FileManagerController controller = FileManagerController();
  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];
  List<String> _recentFiles = [];
  List<VideoModel> _allVideos = [];
  Map<String, List<VideoModel>> _folderVideos = {};
  List<String> _folderNames = [];
  int _selectedTabIndex = 0; // 0 = Folders, 1 = All Videos, 2 = Recent
  
  // Search and view functionality
  int _viewMode = 0; // 0 = Grid, 1 = List, 2 = Tinder Cards
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<VideoModel> _filteredVideos = [];
  List<String> _filteredFolders = [];
  
  late PageController _pageController;

  // iOS-style colors
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosGray = Color(0xFF8E8E93);
  static const Color iosLightGray = Color(0xFFF2F2F7);
  static const Color iosSystemBackground = Color(0xFFFFFFFF);
  static const Color iosSecondarySystemBackground = Color(0xFFF2F2F7);
  static const Color iosLabel = Color(0xFF000000);
  static const Color iosSecondaryLabel = Color(0xFF3C3C43);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize system UI with app theme colors
    SystemUIHelper.initializeSystemUI();
    SystemUIHelper.setAppThemeUI();
    
    _pageController = PageController(initialPage: _selectedTabIndex);
    _loadSavedViewMode();
    _checkAndRequestStoragePermission();
    _loadRecentFiles();
    _loadAllVideos();
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestStoragePermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use VideoScannerService for permission handling
      final scannerService = VideoScannerService();
      final hasPermission = await scannerService.requestStoragePermission();
      
      setState(() {
        _hasPermission = hasPermission;
      });
      
      if (_hasPermission) {
        await _loadAllVideos();
      }
    } catch (e) {
      print('Error requesting storage permission: $e');
      setState(() {
        _hasPermission = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecentFiles() async {
    try {
      final storageService = StorageService();
      final recentVideos = await storageService.getRecentVideos();
      setState(() {
        _recentFiles = recentVideos.map((video) => video.path).toList();
      });
    } catch (e) {
      print('Error loading recent files: $e');
    }
  }

  /// Load all videos using background isolate (non-blocking)
  Future<void> _loadAllVideos() async {
    if (!_hasPermission) return;
    
    try {
      // Use VideoScannerService with background isolate for non-blocking scanning
      final scannerService = VideoScannerService();
      final videos = await scannerService.scanAllVideosInBackground();
      
      if (mounted) {
        setState(() {
          _allVideos = videos;
          _organizeFolders(videos);
          _updateFilteredContent();
        });
      }
    } catch (e) {
      print('Error loading videos: $e');
    }
  }

  String _getDisplayName(String path) {
    final fileName = path.split('/').last;
    final nameWithoutExtension = fileName.split('.').first;
    return nameWithoutExtension.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  void _organizeFolders(List<VideoModel> videos) {
    _folderVideos.clear();
    _folderNames.clear();
    
    for (final video in videos) {
      final folderPath = video.path.substring(0, video.path.lastIndexOf('/'));
      final folderName = folderPath.split('/').last;
      
      if (!_folderVideos.containsKey(folderName)) {
        _folderVideos[folderName] = [];
        _folderNames.add(folderName);
      }
      _folderVideos[folderName]!.add(video);
    }
    
    // Sort folders by name
    _folderNames.sort();
  }

  void _updateFilteredContent() {
    if (_searchQuery.isEmpty) {
      _filteredVideos = _allVideos;
      _filteredFolders = _folderNames;
    } else {
      // Filter videos by name
      _filteredVideos = _allVideos.where((video) {
        return video.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               video.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
      
      // Filter folders by name or if they contain matching videos
      _filteredFolders = _folderNames.where((folderName) {
        // Check folder name
        if (folderName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return true;
        }
        
        // Check if folder contains matching videos
        final folderVideos = _folderVideos[folderName] ?? [];
        return folderVideos.any((video) =>
          video.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          video.name.toLowerCase().contains(_searchQuery.toLowerCase())
        );
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredContent();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _updateFilteredContent();
      }
    });
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = (_viewMode + 1) % 3; // Cycle through 0, 1, 2
    });
    _saveViewMode();
  }

  Future<void> _loadSavedViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedViewMode = prefs.getInt('view_mode') ?? 0; // Default to Grid
      setState(() {
        _viewMode = savedViewMode;
      });
    } catch (e) {
      print('Error loading view mode: $e');
    }
  }

  Future<void> _saveViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('view_mode', _viewMode);
    } catch (e) {
      print('Error saving view mode: $e');
    }
  }

  void _addToFavorites(VideoModel video) {
    HapticFeedbackHelper.success();
    // TODO: Implement favorites functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${video.displayName}" to favorites'),
        backgroundColor: const Color(0xFF007AFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareVideo(VideoModel video) {
    HapticFeedbackHelper.lightImpact();
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing "${video.displayName}"'),
        backgroundColor: const Color(0xFF007AFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _deleteVideo(VideoModel video) {
    HapticFeedbackHelper.error();
    setState(() {
      _allVideos.removeWhere((v) => v.path == video.path);
      _organizeFolders(_allVideos);
      _updateFilteredContent();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${video.displayName}"'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implement undo functionality
            HapticFeedbackHelper.lightImpact();
          },
        ),
      ),
    );
  }

  void _navigateToFolder(String folderName) {
    final folderVideos = _folderVideos[folderName] ?? [];
    Navigator.push(
      context,
      IOSPageTransitions.slideFromRight(
        IOSFolderScreen(
          folderName: folderName,
          videos: folderVideos,
          onVideoTap: _playVideo,
        ),
      ),
    );
  }

  void _playVideo(String videoPath, String videoTitle) async {
    // Find the actual video from _allVideos to get correct metadata
    final video = _allVideos.firstWhere(
      (v) => v.path == videoPath,
      orElse: () => VideoModel(
        path: videoPath,
        name: videoTitle,
        displayName: videoTitle,
        size: 0,
        dateModified: DateTime.now(),
      ),
    );
    
    // Add to recent files
    final storageService = StorageService();
    await storageService.addToRecent(video);
    
    // Update recent files list to refresh Continue Watching
    await _loadRecentFiles();
    
    // Navigate to video player
    if (mounted) {
      Navigator.push(
        context,
        IOSPageTransitions.slideFromRight(
          VideoPlayerScreen(video: video),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosSystemBackground,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // iOS-style header
            Flexible(
              flex: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Title and action buttons
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'i Player',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: iosLabel,
                          ),
                        ),
                      ),
                      // Search button
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedbackHelper.lightImpact();
                            _toggleSearch();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isSearching ? iosBlue : iosLightGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.search,
                              size: 20,
                              color: _isSearching ? Colors.white : iosBlue,
                            ),
                          ),
                        ),
                      ),
                      // View toggle button
                      Tooltip(
                        message: _getViewModeTooltip(),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedbackHelper.selectionClick();
                            _toggleViewMode();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iosLightGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getViewModeIcon(),
                              size: 20,
                              color: iosBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  
                  // Search bar (if searching)
                  if (_isSearching) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: iosLightGray,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: iosGray,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(
                                fontSize: 16,
                                color: iosLabel,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search videos and folders...',
                                hintStyle: TextStyle(
                                  color: iosGray,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: const Icon(
                                Icons.clear,
                                color: iosGray,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],
                  
                  // iOS-style segmented control
                  Container(
                    decoration: BoxDecoration(
                      color: iosLightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentedControlItem('Folders', 0),
                        _buildSegmentedControlItem('All Videos', 1),
                        _buildSegmentedControlItem('Recent', 2),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Content with swipe navigation
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: 3,
                onPageChanged: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                  HapticFeedbackHelper.lightImpact();
                },
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return _buildFoldersContent();
                    case 1:
                      return _buildAllVideosContent();
                    case 2:
                      return _buildRecentContent();
                    default:
                      return _buildFoldersContent();
                  }
                },
              ),
            ),
            
            // Continue Watching section at bottom
            if (_recentFiles.isNotEmpty && !_isSearching)
              SafeArea(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: iosSystemBackground,
                    border: Border(
                      top: BorderSide(
                        color: iosLightGray,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: _buildLastPlayedVideo(),
                ),
              ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControlItem(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedbackHelper.selectionClick();
          setState(() {
            _selectedTabIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        },
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? iosBlue : iosGray,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFoldersContent() {
    if (_isLoading) return _buildLoadingContent();
    if (!_hasPermission) return _buildPermissionRequest();
    
    return _buildFoldersGrid();
  }

  Widget _buildAllVideosContent() {
    if (_isLoading) return _buildLoadingContent();
    if (!_hasPermission) return _buildPermissionRequest();
    
    // All Videos tab should show all videos, not filtered by search when not searching
    final videosToShow = _searchQuery.isEmpty ? _allVideos : _filteredVideos;
    
    return _buildVideoContentView(videosToShow);
  }

  Widget _buildRecentContent() {
    if (_isLoading) return _buildLoadingContent();
    if (!_hasPermission) return _buildPermissionRequest();
    
    // Recent tab should show only recent videos in the order they were played
    final recentVideos = _recentFiles.map((path) {
      return _allVideos.firstWhere(
        (video) => video.path == path,
        orElse: () => VideoModel(
          path: path,
          name: path.split('/').last,
          displayName: _getDisplayName(path),
          size: 0,
          dateModified: DateTime.now(),
        ),
      );
    }).toList();
    
    final videosToShow = _searchQuery.isEmpty 
      ? recentVideos 
      : recentVideos.where((video) =>
          video.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          video.name.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
    
    return _buildVideoContentView(videosToShow);
  }

  Widget _buildLoadingContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Scanning for videos...',
            style: TextStyle(
              fontSize: 16,
              color: iosGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContentView(List<VideoModel> videos) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.video_library_outlined,
              size: 64,
              color: iosGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No videos found for "$_searchQuery"' : 'No videos found',
              style: TextStyle(
                fontSize: 18,
                color: iosSecondaryLabel,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                ? 'Try a different search term'
                : 'Pull down to refresh and scan for videos',
              style: TextStyle(
                fontSize: 14,
                color: iosGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedbackHelper.lightImpact();
        await _loadAllVideos();
        HapticFeedbackHelper.success();
      },
      color: const Color(0xFF007AFF),
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      child: _buildVideoView(videos),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off,
              size: 80,
              color: iosGray,
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Storage Permission Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: iosLabel,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'KJ Video Player needs access to your device storage to find and play video files.',
              style: TextStyle(
                fontSize: 16,
                color: iosSecondaryLabel,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _checkAndRequestStoragePermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: iosBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            // Continue Watching section at bottom
            if (_recentFiles.isNotEmpty && !_isSearching)
              SafeArea(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: iosSystemBackground,
                    border: Border(
                      top: BorderSide(
                        color: iosLightGray,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: _buildLastPlayedVideo(),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildVideoGridView(List<VideoModel> videos) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        
        // Lazy loading - only load thumbnails for visible items
        return IOSVideoThumbnail(
          key: ValueKey(video.path), // Ensure proper widget recycling
          video: video,
          onTap: () => _playVideo(video.path, video.displayName),
          onFavorite: () => _addToFavorites(video),
          onShare: () => _shareVideo(video),
          onDelete: () => _deleteVideo(video),
        );
      },
    );
  }

  Widget _buildVideoListView(List<VideoModel> videos) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: VideoListThumbnail(
              video: video,
              size: 60,
            ),
            title: Text(
              video.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF000000),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (video.duration != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.formattedDuration,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      video.formattedSize,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _playVideo(video.path, video.displayName),
          ),
        );
      },
    );
  }

  Widget _buildFoldersGrid() {
    // This method should only be called for Folders tab
    final foldersToShow = _searchQuery.isEmpty ? _folderNames : _filteredFolders;
    
    if (foldersToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_outlined,
              size: 64,
              color: iosGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No folders found for "$_searchQuery"' : 'No folders found',
              style: TextStyle(
                fontSize: 18,
                color: iosSecondaryLabel,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                ? 'Try a different search term'
                : 'Videos will be organized into folders automatically',
              style: TextStyle(
                fontSize: 14,
                color: iosGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedbackHelper.lightImpact();
        await _loadAllVideos();
        HapticFeedbackHelper.success();
      },
      color: const Color(0xFF007AFF),
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      child: _buildFolderView(foldersToShow),
    );
  }

  Widget _buildFolderGridView(List<String> folders) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folderName = folders[index];
        final videoCount = _folderVideos[folderName]?.length ?? 0;
        return IOSFolderCard(
          folderName: folderName,
          videoCount: videoCount,
          videos: _folderVideos[folderName] ?? [],
          onTap: () => _navigateToFolder(folderName),
        );
      },
    );
  }

  Widget _buildFolderListView(List<String> folders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folderName = folders[index];
        final videoCount = _folderVideos[folderName]?.length ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.folder,
                color: Color(0xFF007AFF),
                size: 24,
              ),
            ),
            title: Text(
              folderName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF000000),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$videoCount video${videoCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$videoCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            onTap: () => _navigateToFolder(folderName),
          ),
        );
      },
    );
  }

  IconData _getViewModeIcon() {
    switch (_viewMode) {
      case 0: return Icons.view_list; // Grid -> List
      case 1: return Icons.style; // List -> Cards
      case 2: return Icons.grid_view; // Cards -> Grid
      default: return Icons.grid_view;
    }
  }

  String _getViewModeTooltip() {
    switch (_viewMode) {
      case 0: return 'Switch to List View';
      case 1: return 'Switch to Card View';
      case 2: return 'Switch to Grid View';
      default: return 'Switch View';
    }
  }

  Widget _buildVideoView(List<VideoModel> videos) {
    switch (_viewMode) {
      case 0: return _buildVideoGridView(videos);
      case 1: return _buildVideoListView(videos);
      case 2: return _buildVideoTinderView(videos);
      default: return _buildVideoGridView(videos);
    }
  }

  Widget _buildFolderView(List<String> folders) {
    switch (_viewMode) {
      case 0: return _buildFolderGridView(folders);
      case 1: return _buildFolderListView(folders);
      case 2: return _buildFolderTinderView(folders);
      default: return _buildFolderGridView(folders);
    }
  }

  Widget _buildVideoTinderView(List<VideoModel> videos) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.video_library_outlined,
              size: 64,
              color: iosGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No videos found for "$_searchQuery"' : 'No videos found',
              style: TextStyle(
                fontSize: 18,
                color: iosSecondaryLabel,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return TinderVideoCards(
      key: ValueKey('tinder_videos_${_selectedTabIndex}_${videos.length}'),
      videos: videos,
      onVideoTap: (video) => _playVideo(video.path, video.displayName),
      onFavorite: _addToFavorites,
      onShare: _shareVideo,
      onDelete: _deleteVideo,
    );
  }

  Widget _buildFolderTinderView(List<String> folders) {
    if (folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_outlined,
              size: 64,
              color: iosGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No folders found for "$_searchQuery"' : 'No folders found',
              style: TextStyle(
                fontSize: 18,
                color: iosSecondaryLabel,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return TinderFolderCards(
      folders: folders,
      folderVideos: _folderVideos,
      onFolderTap: _navigateToFolder,
    );
  }

  Widget _buildLastPlayedVideo() {
    if (_recentFiles.isEmpty) return const SizedBox.shrink();
    
    // Get the most recent video (first in the recent files list)
    final lastVideoPath = _recentFiles.first;
    final lastVideo = _allVideos.firstWhere(
      (video) => video.path == lastVideoPath,
      orElse: () => _allVideos.isNotEmpty ? _allVideos.first : VideoModel(
        path: lastVideoPath,
        name: lastVideoPath.split('/').last,
        displayName: _getDisplayName(lastVideoPath),
        size: 0,
        dateModified: DateTime.now(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _playVideo(lastVideo.path, lastVideo.displayName),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iosLightGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoListThumbnail(
                        key: ValueKey(lastVideo.path),
                        video: lastVideo,
                        size: 40,
                      ),
                      Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: iosBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: iosBlue.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Watching',
                      style: TextStyle(
                        fontSize: 12,
                        color: iosGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastVideo.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: iosLabel,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Central Play Button
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: iosBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iosBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: iosGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}