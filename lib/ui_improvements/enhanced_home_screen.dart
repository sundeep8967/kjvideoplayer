import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../screens/modern_video_files_screen.dart';
import '../services/recent_files_service.dart';
import 'modern_theme.dart';
import 'search_screen.dart';

class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _isLoading = true;
  final FileManagerController controller = FileManagerController();
  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];
  List<String> _recentFiles = [];
  int _selectedIndex = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _checkAndRequestStoragePermission();
    _loadRecentFiles();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRequestStoragePermission();
    }
  }

  Future<void> _loadRecentFiles() async {
    final recentFiles = await RecentFilesService.getRecentFiles();
    setState(() {
      _recentFiles = recentFiles;
    });
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 1) { // Search tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchScreen()),
      );
      // Reset to home tab after navigation
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundColor,
      appBar: _hasPermission ? _buildAppBar() : null,
      body: _hasPermission ? _buildMainContent() : _buildPermissionScreen(),
      bottomNavigationBar: _hasPermission ? _buildBottomNavigation() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ModernTheme.surfaceColor,
      elevation: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Video Player',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          Text(
            'Discover your videos',
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: ModernTheme.textPrimary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: ModernTheme.textPrimary),
          onSelected: (value) {
            switch (value) {
              case 'settings':
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon!')),
                );
                break;
              case 'refresh':
                _checkAndRequestStoragePermission();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: ModernTheme.textPrimary),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: ModernTheme.textPrimary),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: ModernTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: ModernTheme.primaryColor,
        unselectedItemColor: ModernTheme.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Recent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      color: ModernTheme.backgroundColor,
      child: Column(
        children: [
          // Quick Stats Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.video_library,
                    color: ModernTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Library',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ModernTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Browse your video collection',
                        style: TextStyle(
                          fontSize: 14,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: ModernTheme.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: _isLoading
                ? _buildLoadingScreen()
                : _buildVideoFoldersView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: ModernTheme.primaryColor),
          SizedBox(height: 16),
          Text(
            'Scanning for video folders...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Container(
      color: ModernTheme.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ModernTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open,
                  size: 64,
                  color: ModernTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Storage Permission Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We need access to your storage to find and play video files on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Grant Permission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoFoldersView() {
    return FutureBuilder<List<FileSystemEntity>>(
      future: findVideoFoldersRecursive([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ModernTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading folders',
                  style: const TextStyle(
                    fontSize: 18,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: ModernTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        final folders = snapshot.data ?? [];
        
        if (folders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ModernTheme.textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: ModernTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Video Folders Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add some video files to your device to get started',
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _checkAndRequestStoragePermission(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                color: ModernTheme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModernVideoFilesScreen(
                          folderPath: folder.path,
                          folderName: FileManager.basename(folder),
                        ),
                      ),
                    ).then((_) => _loadRecentFiles());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ModernTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.folder,
                            color: ModernTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                FileManager.basename(folder),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ModernTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                folder.path,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ModernTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: ModernTheme.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkAndRequestStoragePermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      PermissionStatus status;
      if (sdkInt >= 33) {
        status = await Permission.videos.status;
        if (!status.isGranted) {
          status = await Permission.videos.request();
        }
      } else if (sdkInt >= 30) {
        status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
      } else {
        status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }

      setState(() {
        _hasPermission = status.isGranted;
        _isLoading = false;
      });

      if (_hasPermission) {
        _animationController.forward();
      }
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<List<FileSystemEntity>> findVideoFoldersRecursive(List<FileSystemEntity> entities) async {
    List<FileSystemEntity> videoFolders = [];
    
    try {
      final commonPaths = [
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0',
      ];

      for (String path in commonPaths) {
        final directory = Directory(path);
        if (await directory.exists()) {
          final contents = await directory.list().toList();
          for (final entity in contents) {
            if (FileManager.isDirectory(entity)) {
              final hasVideos = await _hasVideoFiles(entity.path);
              if (hasVideos) {
                videoFolders.add(entity);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing entities: $e');
    }

    return videoFolders;
  }

  Future<bool> _hasVideoFiles(String folderPath) async {
    try {
      final directory = Directory(folderPath);
      final entities = await directory.list().toList();
      
      for (final entity in entities) {
        if (FileManager.isFile(entity)) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (videoExtensions.any((ext) => entity.path.toLowerCase().endsWith(ext))) {
            return true;
          }
        }
      }
    } catch (e) {
      // Ignore permission errors
    }
    return false;
  }
}