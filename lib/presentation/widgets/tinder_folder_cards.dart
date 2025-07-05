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
  late PageController _pageController;
  int _currentIndex = 0;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSwipeLeft() {
    HapticFeedbackHelper.lightImpact();
    if (_currentIndex < widget.folders.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _onSwipeRight() {
    HapticFeedbackHelper.lightImpact();
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex--;
      });
    }
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
        // Swipe indicators
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSwipeIndicator(
                icon: Icons.arrow_back,
                label: 'Swipe Left\nPrevious',
                color: Colors.blue,
              ),
              _buildSwipeIndicator(
                icon: Icons.folder_open,
                label: 'Tap\nOpen Folder',
                color: Colors.green,
              ),
              _buildSwipeIndicator(
                icon: Icons.arrow_forward,
                label: 'Swipe Right\nNext',
                color: Colors.blue,
              ),
            ],
          ),
        ),
        
        // Cards stack
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background cards (next 2 cards)
              for (int i = math.min(_currentIndex + 2, widget.folders.length - 1); 
                   i > _currentIndex; i--)
                _buildBackgroundCard(i),
              
              // Current card
              if (_currentIndex < widget.folders.length)
                _buildCurrentCard(_currentIndex),
            ],
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

  Widget _buildSwipeIndicator({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBackgroundCard(int index) {
    final scale = 1.0 - (index - _currentIndex) * 0.05;
    final offset = (index - _currentIndex) * 10.0;
    
    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(0, offset),
        child: Opacity(
          opacity: 0.5,
          child: _buildCard(widget.folders[index], index, isInteractive: false),
        ),
      ),
    );
  }

  Widget _buildCurrentCard(int index) {
    return GestureDetector(
      onTap: () => widget.onFolderTap(widget.folders[index]),
      onPanUpdate: (details) {
        setState(() {
          _dragOffset = details.delta.dx;
          _isDragging = true;
        });
      },
      onPanEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragOffset = 0.0;
        });
        
        final velocity = details.velocity.pixelsPerSecond;
        
        if (velocity.dx > 500) {
          _onSwipeRight();
        } else if (velocity.dx < -500) {
          _onSwipeLeft();
        }
      },
      child: Transform.translate(
        offset: Offset(_isDragging ? _dragOffset * 0.3 : 0, 0),
        child: Transform.rotate(
          angle: _isDragging ? _dragOffset * 0.001 : 0,
          child: _buildCard(widget.folders[index], index, isInteractive: true),
        ),
      ),
    );
  }

  Widget _buildCard(String folderPath, int index, {required bool isInteractive}) {
    final folderName = folderPath.split('/').last;
    final videos = widget.folderVideos[folderPath] ?? [];
    
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: MediaQuery.of(context).size.height * 0.6,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: isInteractive ? 12 : 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              
              // Folder info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        folderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.video_library,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${videos.length} videos',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getTotalSize(videos),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Folder icon overlay
              if (isInteractive)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_open,
                      color: Colors.white,
                      size: 40,
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