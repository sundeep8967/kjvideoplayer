import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../video_files_screen.dart';
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
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _checkAndRequestStoragePermission();
    }
  }

  Future<void> _checkAndRequestStoragePermission() async {
    setState(() => _isLoading = true);
    
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      bool permissionStatus;
      
      if (deviceInfo.version.sdkInt > 32) {
        permissionStatus = await Permission.videos.request().isGranted;
      } else {
        permissionStatus = await Permission.storage.request().isGranted;
      }
      
      setState(() {
        _hasPermission = permissionStatus;
        _isLoading = false;
      });
      
      if (permissionStatus) {
        _animationController.forward();
      } else {
        _showPermissionSnackBar();
      }
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      _showPermissionSnackBar();
    }
  }

  void _showPermissionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Storage permission is required to access video files'),
        backgroundColor: ModernTheme.accentColor,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
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
            color: Colors.black.withOpacity(0.1),
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
              Color(0xFF0A0A0A),
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
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: ModernTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.video_library,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KJ Video Player',
                  style: TextStyle(
                    color: ModernTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Professional Video Experience',
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildActionButtons(),
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
          // Toggle view mode functionality can be added here
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grid view functionality coming soon!')),
          );
        }),
        const SizedBox(width: 8),
        _buildActionButton(Icons.settings, () {
          // Settings functionality
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: ModernTheme.textPrimary, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.primaryColor),
          ),
          SizedBox(height: 24),
          Text(
            'Initializing Video Player...',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ModernTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModernTheme.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_open,
                      color: ModernTheme.accentColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Storage Access Required',
                    style: TextStyle(
                      color: ModernTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'KJ Video Player needs access to your device storage to find and play video files.',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => openAppSettings(),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFoldersView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickAccessSection(),
            _buildFoldersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
              color: ModernTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildQuickAccessCard('Recent Videos', Icons.history, () {}),
                _buildQuickAccessCard('Downloads', Icons.download, () {}),
                _buildQuickAccessCard('Camera', Icons.camera_alt, () {}),
                _buildQuickAccessCard('Movies', Icons.movie, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(String title, IconData icon, VoidCallback onTap) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: ModernTheme.cardColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ModernTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: ModernTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: ModernTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoldersSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Folders',
              style: TextStyle(
                color: ModernTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FileManager(
                controller: controller,
                builder: (context, snapshot) {
                  final List<FileSystemEntity> entities = snapshot;
                  
                  if (controller.getCurrentPath == Directory('/storage/emulated/0').path) {
                    return FutureBuilder<List<FileSystemEntity>>(
                      future: findVideoFoldersRecursive(entities),
                      builder: (context, futureSnapshot) {
                        if (futureSnapshot.hasData) {
                          final videoFolders = futureSnapshot.data!;
                          return _buildModernFolderList(videoFolders);
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    );
                  }
                  
                  return _buildModernFolderList(entities);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFolderList(List<FileSystemEntity> entities) {
    if (entities.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: entities.length,
      itemBuilder: (context, index) {
        final entity = entities[index];
        return _buildModernFolderCard(entity);
      },
    );
  }

  Widget _buildModernFolderCard(FileSystemEntity entity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: ModernTheme.cardColor,
        child: InkWell(
          onTap: () {
            if (FileManager.isDirectory(entity)) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ModernVideoFilesScreen(
                    folderPath: entity.path,
                    folderName: FileManager.basename(entity),
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: ModernTheme.accentGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FileManager.isFile(entity) ? Icons.video_file : Icons.folder,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FileManager.basename(entity),
                        style: const TextStyle(
                          color: ModernTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<FileStat>(
                        future: entity.stat(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            if (entity is File) {
                              final size = snapshot.data!.size;
                              return Text(
                                FileManager.formatBytes(size),
                                style: const TextStyle(
                                  color: ModernTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return Text(
                              'Modified: ${snapshot.data!.modified.toString().substring(0, 10)}',
                              style: const TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 12,
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

  Widget _buildEmptyState() {
    return Center(
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
              Icons.video_library_outlined,
              color: ModernTheme.textSecondary,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Video Folders Found',
            style: TextStyle(
              color: ModernTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add some video files to your device to get started',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<List<FileSystemEntity>> findVideoFoldersRecursive(List<FileSystemEntity> entities) async {
    final List<FileSystemEntity> videoFolders = [];

    try {
      for (final entity in entities) {
        if (FileManager.isDirectory(entity)) {
          try {
            final subEntities = await Directory(entity.path).list(recursive: false).toList();
            final containsVideo = subEntities.any((subEntity) =>
                FileManager.isFile(subEntity) &&
                videoExtensions.any((ext) => subEntity.path.toLowerCase().endsWith(ext)));

            if (containsVideo) {
              videoFolders.add(entity);
            }

            videoFolders.addAll(await findVideoFoldersRecursive(subEntities));
          } catch (e) {
            debugPrint('Error accessing directory ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing entities: $e');
    }

    return videoFolders;
  }
}