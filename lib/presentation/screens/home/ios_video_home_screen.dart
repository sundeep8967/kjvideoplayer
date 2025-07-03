import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_manager/file_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/models/video_model.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/ios_video_thumbnail.dart';
import '../../widgets/ios_folder_card.dart';
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
  bool _isGridView = true;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<VideoModel> _filteredVideos = [];
  List<String> _filteredFolders = [];
  
  late AnimationController _animationController;
  late AnimationController _tabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    
    // Use system default notification bar
    SystemUIHelper.initializeSystemUI();
    
    _initializeAnimations();
    _checkAndRequestStoragePermission();
    _loadRecentFiles();
    _loadAllVideos();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _tabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestStoragePermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      PermissionStatus permission;
      
      // Check current permission status first
      if (sdkInt >= 33) {
        // Android 13+ (API 33+) - Use scoped storage permissions
        permission = await Permission.videos.status;
        if (!permission.isGranted) {
          permission = await Permission.videos.request();
        }
        
        // Also check for photos permission if needed
        if (permission.isGranted) {
          final photosPermission = await Permission.photos.status;
          if (!photosPermission.isGranted) {
            await Permission.photos.request();
          }
        }
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32) - Use MANAGE_EXTERNAL_STORAGE
        permission = await Permission.manageExternalStorage.status;
        if (!permission.isGranted) {
          permission = await Permission.manageExternalStorage.request();
        }
      } else {
        // Android 10 and below - Use traditional storage permission
        permission = await Permission.storage.status;
        if (!permission.isGranted) {
          permission = await Permission.storage.request();
        }
      }
      
      setState(() {
        _hasPermission = permission.isGranted;
      });
      
      if (_hasPermission) {
        await _loadAllVideos();
        _animationController.forward();
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

  Future<void> _loadAllVideos() async {
    if (!_hasPermission) return;
    
    try {
      List<VideoModel> videos = [];
      
      // Get common video directories
      final directories = [
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Camera',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/Telegram/Telegram Video',
      ];
      
      for (final directoryPath in directories) {
        final directory = Directory(directoryPath);
        if (await directory.exists()) {
          final entities = directory.listSync(recursive: true, followLinks: false);
          
          for (final entity in entities) {
            if (entity is File && _isVideoFile(entity.path)) {
              try {
                final stat = entity.statSync();
                final video = VideoModel(
                  path: entity.path,
                  name: entity.path.split('/').last,
                  displayName: _getDisplayName(entity.path),
                  size: stat.size,
                  dateModified: stat.modified,
                );
                videos.add(video);
              } catch (e) {
                // Skip files that can't be accessed
                continue;
              }
            }
          }
        }
      }
      
      setState(() {
        _allVideos = videos;
        _organizeFolders(videos);
        _updateFilteredContent();
      });
    } catch (e) {
      print('Error loading videos: $e');
    }
  }

  bool _isVideoFile(String path) {
    final extension = '.${path.split('.').last.toLowerCase()}';
    return videoExtensions.contains(extension);
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
      _isGridView = !_isGridView;
    });
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
    // Add to recent files
    final storageService = StorageService();
    final video = VideoModel(
      path: videoPath,
      name: videoTitle,
      displayName: videoTitle,
      size: 0,
      dateModified: DateTime.now(),
    );
    await storageService.addToRecent(video);
    
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
          children: [
            // iOS-style header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      GestureDetector(
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
                            _isGridView ? Icons.view_list : Icons.grid_view,
                            size: 20,
                            color: iosBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Search bar (if searching)
                  if (_isSearching) ...[
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
            
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: _buildContent(),
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

  Widget _buildContent() {
    if (_isLoading) {
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
    
    if (!_hasPermission) {
      return _buildPermissionRequest();
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildVideoGrid(),
      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_selectedTabIndex == 0) {
      // Folders view
      return _buildFoldersGrid();
    }
    
    List<VideoModel> videosToShow;
    
    switch (_selectedTabIndex) {
      case 1: // All Videos
        videosToShow = _filteredVideos;
        break;
      case 2: // Recent
        final recentVideos = _allVideos.where((video) => 
          _recentFiles.contains(video.path)).toList();
        videosToShow = _searchQuery.isEmpty 
          ? recentVideos 
          : recentVideos.where((video) =>
              video.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              video.name.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
        break;
      default:
        videosToShow = _filteredVideos;
    }
    
    if (videosToShow.isEmpty) {
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
      child: _isGridView ? _buildVideoGridView(videosToShow) : _buildVideoListView(videosToShow),
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
        return IOSVideoThumbnail(
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
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                ),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 24,
              ),
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
                  Text(
                    video.formattedSize,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
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
    final foldersToShow = _filteredFolders;
    
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
      child: _isGridView ? _buildFolderGridView(foldersToShow) : _buildFolderListView(foldersToShow),
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
}