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
      body: _hasPermission ? _buildMainContent() : _buildPermissionScreen(),
      bottomNavigationBar: _hasPermission ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: ModernTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ModernTheme.backgroundColor,
            ModernTheme.surfaceColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildModernAppBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingScreen()
                  : _hasPermission
                      ? _buildVideoFoldersView()
                      : _buildPermissionScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.surfaceColor.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modern Video Player',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Discover your video collection',
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              _buildActionButtons(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton(Icons.search, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        }),
        const SizedBox(width: 8),
        _buildActionButton(Icons.grid_view, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grid view functionality coming soon!')),
          );
        }),
        const SizedBox(width: 8),
        _buildActionButton(Icons.settings, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings functionality coming soon!')),
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: ModernTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: ModernTheme.textPrimary),
        onPressed: onPressed,
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
            style: TextStyle(color: ModernTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_off,
              size: 64,
              color: ModernTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Storage Permission Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We need access to your storage to find video files.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text('Grant Permission'),
            ),
          ],
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
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: ModernTheme.textSecondary),
            ),
          );
        }
        
        final folders = snapshot.data ?? [];
        
        if (folders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: ModernTheme.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  'No video folders found',
                  style: TextStyle(
                    fontSize: 18,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add some video files to get started',
                  style: TextStyle(color: ModernTheme.textSecondary),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: ModernTheme.cardColor,
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
                          color: ModernTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
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
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: ModernTheme.textSecondary,
                        size: 16,
                      ),
                    ],
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