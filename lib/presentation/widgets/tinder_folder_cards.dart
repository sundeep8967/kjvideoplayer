import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import '../../data/models/video_model.dart';
import '../../data/services/thumbnail_service.dart';
import '../../core/utils/haptic_feedback_helper.dart';

class TinderFolderCards extends StatefulWidget {
  final List<String> folders;
  final Map<String, List<VideoModel>> folderVideos;
  final Function(String) onFolderTap;

  const TinderFolderCards({
    super.key,
    required this.folders,
    required this.folderVideos,
    required this.onFolderTap,
  });

  @override
  State<TinderFolderCards> createState() => _TinderFolderCardsState();
}

class _TinderFolderCardsState extends State<TinderFolderCards>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragPosition = 0.0;
  bool _isDragging = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextFolder() {
    if (_currentIndex < widget.folders.length - 1) {
      HapticFeedbackHelper.lightImpact();
      _animateToNext();
    }
  }

  void _previousFolder() {
    if (_currentIndex > 0) {
      HapticFeedbackHelper.lightImpact();
      _animateToPrevious();
    }
  }

  void _animateToNext() {
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward().then((_) {
      setState(() {
        _currentIndex++;
      });
      _animationController.reset();
    });
  }

  void _animateToPrevious() {
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.5, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: -0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward().then((_) {
      setState(() {
        _currentIndex--;
      });
      _animationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.folders.isEmpty) {
      return const Center(
        child: Text('No folders available'),
      );
    }

    return Column(
      children: [
        
        // Clean folder view
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.9),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              HapticFeedbackHelper.lightImpact();
            },
            itemCount: widget.folders.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                child: _buildCard(widget.folders[index], index, isInteractive: true),
              );
            },
          ),
        ),
        
        // Progress indicator
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentIndex + 1} / ${widget.folders.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildCard(String folderPath, int index, {required bool isInteractive}) {
    final folderName = folderPath.split('/').last;
    final videos = widget.folderVideos[folderPath] ?? [];
    
    return GestureDetector(
      onTap: () => widget.onFolderTap(folderPath),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Folder thumbnail
              TinderFolderThumbnail(
                videos: videos,
                folderName: folderName,
              ),
              
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              
              // Folder info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        folderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${videos.length} videos',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getTotalSize(videos),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Folder icon overlay
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: Colors.black87,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTotalSize(List<VideoModel> videos) {
    int totalSize = 0;
    for (final video in videos) {
      totalSize += video.size;
    }
    
    if (totalSize < 1024) return '${totalSize}B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class TinderFolderThumbnail extends StatefulWidget {
  final List<VideoModel> videos;
  final String folderName;

  const TinderFolderThumbnail({
    super.key,
    required this.videos,
    required this.folderName,
  });

  @override
  State<TinderFolderThumbnail> createState() => _TinderFolderThumbnailState();
}

class _TinderFolderThumbnailState extends State<TinderFolderThumbnail> {
  final ThumbnailService _thumbnailService = ThumbnailService();
  final Map<String, String?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    final videosToLoad = widget.videos.take(4).toList();
    for (final video in videosToLoad) {
      if (!_thumbnailCache.containsKey(video.path)) {
        final thumbnail = await _thumbnailService.generateThumbnail(video.path);
        if (mounted) {
          setState(() {
            _thumbnailCache[video.path] = thumbnail;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(
            Icons.folder_outlined,
            size: 64,
            color: Colors.grey,
          ),
        ),
      );
    }

    final videosToShow = widget.videos.take(4).toList();
    
    if (videosToShow.length == 1) {
      return _buildSingleThumbnail(videosToShow.first);
    } else {
      return _buildGridThumbnails(videosToShow);
    }
  }

  Widget _buildSingleThumbnail(VideoModel video) {
    final thumbnailPath = _thumbnailCache[video.path];
    
    if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
      return Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
      );
    }
    
    return _buildDefaultThumbnail();
  }

  Widget _buildGridThumbnails(List<VideoModel> videos) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        if (index < videos.length) {
          final video = videos[index];
          final thumbnailPath = _thumbnailCache[video.path];
          
          if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
            return Image.file(
              File(thumbnailPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
            );
          }
          
          return _buildDefaultThumbnail();
        } else {
          return Container(
            color: Colors.grey[100],
            child: Icon(
              Icons.add,
              color: Colors.grey[400],
              size: 32,
            ),
          );
        }
      },
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.video_file,
          size: 32,
          color: Colors.grey,
        ),
      ),
    );
  }
}