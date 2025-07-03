import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../../core/utils/haptic_feedback_helper.dart';
import '../../data/models/video_model.dart';
import '../../data/services/thumbnail_service.dart';
import 'ios_context_menu.dart';
import 'ios_action_sheet.dart';

class IOSFolderCard extends StatefulWidget {
  final String folderName;
  final int videoCount;
  final List<VideoModel> videos;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;

  const IOSFolderCard({
    super.key,
    required this.folderName,
    required this.videoCount,
    required this.videos,
    required this.onTap,
    this.onFavorite,
    this.onShare,
  });

  @override
  State<IOSFolderCard> createState() => _IOSFolderCardState();
}

class _IOSFolderCardState extends State<IOSFolderCard>
    with TickerProviderStateMixin {
  final ThumbnailService _thumbnailService = ThumbnailService();
  List<String?> _thumbnailPaths = [];
  bool _isLoadingThumbnails = false;
  
  // Animation for cycling thumbnails
  late AnimationController _cycleController;
  late Animation<double> _fadeAnimation;
  Timer? _cycleTimer;
  int _currentThumbnailSet = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadFolderThumbnails();
  }

  void _initializeAnimations() {
    _cycleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cycleController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadFolderThumbnails() async {
    if (widget.videos.isEmpty) return;
    
    setState(() {
      _isLoadingThumbnails = true;
    });

    // Load thumbnails for all videos in the folder
    List<String?> thumbnails = [];

    for (final video in widget.videos) {
      try {
        final thumbnailPath = await _thumbnailService.generateThumbnail(video.path);
        thumbnails.add(thumbnailPath);
      } catch (e) {
        thumbnails.add(null);
      }
    }

    if (mounted) {
      setState(() {
        _thumbnailPaths = thumbnails;
        _isLoadingThumbnails = false;
      });
      
      // Start the cycling animation after thumbnails are loaded
      if (_thumbnailPaths.isNotEmpty) {
        _startThumbnailCycling();
      }
    }
  }

  void _startThumbnailCycling() {
    if (widget.videos.length <= 1) return; // No need to cycle if only 1 video
    
    _cycleController.forward();
    
    _cycleTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _currentThumbnailSet = (_currentThumbnailSet + 1) % _thumbnailPaths.length;
      });
      
      // Restart fade animation
      _cycleController.reset();
      _cycleController.forward();
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _cycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IOSContextMenu(
      onTap: () {
        HapticFeedbackHelper.lightImpact();
        widget.onTap();
      },
      actions: [
        IOSContextMenuAction(
          title: 'Open Folder',
          icon: Icons.folder_open,
          onPressed: widget.onTap,
        ),
        if (widget.onFavorite != null)
          IOSContextMenuAction(
            title: 'Add to Favorites',
            icon: Icons.favorite_outline,
            onPressed: widget.onFavorite!,
          ),
        if (widget.onShare != null)
          IOSContextMenuAction(
            title: 'Share Folder',
            icon: Icons.share,
            onPressed: widget.onShare!,
          ),
        IOSContextMenuAction(
          title: 'Folder Info',
          icon: Icons.info_outline,
          onPressed: () => _showFolderInfo(context),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnails Grid (Top Half)
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildThumbnailGrid(),
                ),
              ),
            ),
            
            // Folder Info (Bottom Half)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Folder Icon and Count
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.folder,
                            color: Color(0xFF007AFF),
                            size: 14,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${widget.videoCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Folder Name
                    Expanded(
                      child: Text(
                        widget.folderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF000000),
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailGrid() {
    if (_isLoadingThumbnails) {
      return Container(
        color: const Color(0xFFF2F2F7),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),
        ),
      );
    }

    if (_thumbnailPaths.isEmpty || widget.videos.isEmpty) {
      return _buildDefaultThumbnailGrid();
    }

    // Show single cycling thumbnail
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
            ),
            child: _thumbnailPaths[_currentThumbnailSet] != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(_thumbnailPaths[_currentThumbnailSet]!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultThumbnailGrid();
                        },
                      ),
                      // Play overlay
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildDefaultThumbnailGrid(),
          ),
        );
      },
    );
  }

  Widget _buildDefaultThumbnailGrid() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF007AFF),
            Color(0xFF0051D5),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.folder,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSingleDefaultThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF007AFF),
            Color(0xFF0051D5),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showFolderInfo(BuildContext context) {
    IOSActionSheet.show(
      context: context,
      title: widget.folderName,
      message: 'Folder Information',
      actions: [
        IOSActionSheetAction(
          title: 'Videos: ${widget.videoCount}',
          onPressed: () {},
        ),
        IOSActionSheetAction(
          title: 'Folder Name: ${widget.folderName}',
          onPressed: () {},
        ),
      ],
    );
  }
}