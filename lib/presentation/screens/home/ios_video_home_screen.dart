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
import '../video_player/video_player_screen.dart';
import '../../animations/slide_transition.dart';

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
  int _selectedTabIndex = 0; // 0 = All Videos, 1 = Folders, 2 = Recent
  
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
        CustomSlideTransition.createRoute(
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
                  // Large title
                  const Text(
                    'KJ Video Player',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: iosLabel,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // iOS-style segmented control
                  Container(
                    decoration: BoxDecoration(
                      color: iosLightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentedControlItem('All Videos', 0),
                        _buildSegmentedControlItem('Folders', 1),
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
    List<VideoModel> videosToShow;
    
    switch (_selectedTabIndex) {
      case 0: // All Videos
        videosToShow = _allVideos;
        break;
      case 1: // Folders (placeholder)
        videosToShow = _allVideos;
        break;
      case 2: // Recent
        videosToShow = _allVideos.where((video) => 
          _recentFiles.contains(video.path)).toList();
        break;
      default:
        videosToShow = _allVideos;
    }
    
    if (videosToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: iosGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found',
              style: TextStyle(
                fontSize: 18,
                color: iosSecondaryLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh and scan for videos',
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
      onRefresh: _loadAllVideos,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: videosToShow.length,
        itemBuilder: (context, index) {
          final video = videosToShow[index];
          return IOSVideoThumbnail(
            video: video,
            onTap: () => _playVideo(video.path, video.displayName),
          );
        },
      ),
    );
  }
}