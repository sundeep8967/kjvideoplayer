import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import '../../data/models/video_model.dart';
import '../../data/services/thumbnail_service.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import 'ios_folder_card.dart';

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

        // Card stack
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.folders.length,
            itemBuilder: (context, index) {
              final folderName = widget.folders[index];
              final videos = widget.folderVideos[folderName] ?? [];
              final isCurrentCard = index == _currentIndex;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(
                  horizontal: isCurrentCard ? 10 : 20,
                  vertical: isCurrentCard ? 20 : 40,
                ),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedbackHelper.lightImpact();
                    widget.onFolderTap(folderName);
                  },
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
                  child: Transform.rotate(
                    angle: _isDragging && isCurrentCard ? _dragOffset * 0.001 : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Just show the cycling thumbnail without folder info
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              child: _buildFolderThumbnail(videos),
                            ),
                            
                            // Folder info overlay
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.6),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      folderName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.video_library,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${videos.length} video${videos.length == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(
                                          Icons.folder,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Swipe to browse',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Page indicator
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              math.min(widget.folders.length, 5),
              (index) {
                final actualIndex = _currentIndex - 2 + index;
                final isActive = actualIndex == _currentIndex;
                final isVisible = actualIndex >= 0 && actualIndex < widget.folders.length;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isVisible 
                        ? (isActive ? const Color(0xFF007AFF) : Colors.grey[300])
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFolderThumbnail(List<VideoModel> videos) {
    if (videos.isEmpty) {
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
            size: 64,
            color: Colors.white,
          ),
        ),
      );
    }

    // Show cycling thumbnail similar to folder card but without UI elements
    return TinderFolderThumbnail(videos: videos);
  }
}

class TinderFolderThumbnail extends StatefulWidget {
  final List<VideoModel> videos;

  const TinderFolderThumbnail({
    super.key,
    required this.videos,
  });

  @override
  State<TinderFolderThumbnail> createState() => _TinderFolderThumbnailState();
}

class _TinderFolderThumbnailState extends State<TinderFolderThumbnail>
    with TickerProviderStateMixin {
  final ThumbnailService _thumbnailService = ThumbnailService();
  List<String?> _thumbnailPaths = [];
  bool _isLoadingThumbnails = false;
  
  late AnimationController _cycleController;
  late Animation<double> _fadeAnimation;
  Timer? _cycleTimer;
  int _currentThumbnailIndex = 0;

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
      
      if (_thumbnailPaths.isNotEmpty) {
        _startThumbnailCycling();
      }
    }
  }

  void _startThumbnailCycling() {
    if (widget.videos.length <= 1) return;
    
    _cycleController.forward();
    
    _cycleTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _currentThumbnailIndex = (_currentThumbnailIndex + 1) % _thumbnailPaths.length;
      });
      
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
    if (_isLoadingThumbnails) {
      return Container(
        color: const Color(0xFFF2F2F7),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),
        ),
      );
    }

    if (_thumbnailPaths.isEmpty) {
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
            size: 64,
            color: Colors.white,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: _thumbnailPaths[_currentThumbnailIndex] != null
                ? Image.file(
                    File(_thumbnailPaths[_currentThumbnailIndex]!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.folder,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.folder,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}