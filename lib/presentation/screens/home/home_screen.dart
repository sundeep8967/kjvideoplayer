import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/video_model.dart';
import '../../../data/models/folder_model.dart';
import '../../../data/services/video_scanner_service.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/video_grid.dart';
import '../../widgets/folder_grid.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/permission_request_widget.dart';
import '../video_player/video_player_screen.dart';
import '../../animations/slide_transition.dart';
import 'ios_video_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Services
  final VideoScannerService _scannerService = VideoScannerService();
  final StorageService _storageService = StorageService();
  
  // State
  bool _hasPermission = false;
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 = All Videos, 1 = Folders, 2 = Recent
  
  // Data
  List<VideoModel> _allVideos = [];
  List<FolderModel> _folders = [];
  List<VideoModel> _recentVideos = [];
  
  // Animation
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize system UI
    SystemUIHelper.initializeSystemUI();
    
    // Initialize animations
    _initializeAnimations();
    
    // Load data
    _initializeData();
  }

  void _initializeAnimations() {
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
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

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check permissions
      _hasPermission = await _scannerService.requestStoragePermission();
      
      if (_hasPermission) {
        // Load recent videos first (faster)
        _recentVideos = await _storageService.getRecentVideos();
        
        // Scan for all videos
        _allVideos = await _scannerService.scanAllVideos();
        
        // Organize into folders
        _folders = _scannerService.organizeVideosIntoFolders(_allVideos);
        
        // Start animations
        _animationController.forward();
      }
    } catch (e) {
      print('Error initializing data: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading videos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  void _playVideo(VideoModel video) async {
    // Add to recent videos
    await _storageService.addToRecent(video);
    
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // iOS white background
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: const Color(0xFFFFFFFF),
              foregroundColor: const Color(0xFF000000),
              elevation: 0,
              floating: true,
              pinned: true,
              snap: false,
              title: const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),
              bottom: _hasPermission && !_isLoading ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorPadding: const EdgeInsets.all(2),
                    labelColor: const Color(0xFF007AFF),
                    unselectedLabelColor: const Color(0xFF8E8E93),
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: [
                      Tab(text: 'All (${_allVideos.length})'),
                      Tab(text: 'Folders (${_folders.length})'),
                      Tab(text: 'Recent (${_recentVideos.length})'),
                    ],
                  ),
                ),
              ) : null,
            ),
          ];
        },
        body: _buildBody(),
      ),
      floatingActionButton: _hasPermission && !_isLoading
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _refreshData,
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.refresh_rounded, size: 28),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Scanning for videos...');
    }
    
    if (!_hasPermission) {
      return PermissionRequestWidget(
        onRetry: _initializeData,
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            // All Videos Tab
            VideoGrid(
              videos: _allVideos,
              onVideoTap: _playVideo,
              onRefresh: _refreshData,
            ),
            
            // Folders Tab
            FolderGrid(
              folders: _folders,
              onFolderTap: (folder) {
                // Navigate to folder contents
                Navigator.push(
                  context,
                  CustomSlideTransition.createRoute(
                    FolderContentsScreen(folder: folder),
                  ),
                );
              },
              onRefresh: _refreshData,
            ),
            
            // Recent Tab
            VideoGrid(
              videos: _recentVideos,
              onVideoTap: _playVideo,
              onRefresh: _refreshData,
              showLastPlayed: true,
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for folder contents screen
class FolderContentsScreen extends StatelessWidget {
  final FolderModel folder;
  
  const FolderContentsScreen({
    super.key,
    required this.folder,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
      ),
      body: VideoGrid(
        videos: folder.videos,
        onVideoTap: (video) {
          Navigator.push(
            context,
            CustomSlideTransition.createRoute(
              VideoPlayerScreen(video: video),
            ),
          );
        },
      ),
    );
  }
}