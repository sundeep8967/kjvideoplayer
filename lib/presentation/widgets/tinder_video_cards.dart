import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../data/models/video_model.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import 'ios_video_thumbnail.dart';

class TinderVideoCards extends StatefulWidget {
  final List<VideoModel> videos;
  final Function(VideoModel) onVideoTap;
  final Function(VideoModel)? onFavorite;
  final Function(VideoModel)? onShare;
  final Function(VideoModel)? onDelete;

  const TinderVideoCards({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.onFavorite,
    this.onShare,
    this.onDelete,
  });

  @override
  State<TinderVideoCards> createState() => _TinderVideoCardsState();
}

class _TinderVideoCardsState extends State<TinderVideoCards>
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
    if (_currentIndex < widget.videos.length - 1) {
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

  void _onSwipeUp() {
    HapticFeedbackHelper.success();
    if (widget.onFavorite != null) {
      widget.onFavorite!(widget.videos[_currentIndex]);
    }
  }

  void _onSwipeDown() {
    HapticFeedbackHelper.warning();
    if (widget.onShare != null) {
      widget.onShare!(widget.videos[_currentIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Center(
        child: Text('No videos available'),
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
                icon: Icons.favorite,
                label: 'Swipe Up\nFavorite',
                color: Colors.red,
              ),
              _buildSwipeIndicator(
                icon: Icons.arrow_back,
                label: 'Swipe Left\nPrevious',
                color: Colors.blue,
              ),
              _buildSwipeIndicator(
                icon: Icons.play_circle,
                label: 'Tap\nPlay',
                color: Colors.green,
              ),
              _buildSwipeIndicator(
                icon: Icons.arrow_forward,
                label: 'Swipe Right\nNext',
                color: Colors.blue,
              ),
              _buildSwipeIndicator(
                icon: Icons.share,
                label: 'Swipe Down\nShare',
                color: Colors.orange,
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
            itemCount: widget.videos.length,
            itemBuilder: (context, index) {
              final video = widget.videos[index];
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
                    widget.onVideoTap(video);
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
                    } else if (velocity.dy < -500) {
                      _onSwipeUp();
                    } else if (velocity.dy > 500) {
                      _onSwipeDown();
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
                            IOSVideoThumbnail(
                              video: video,
                              onTap: () => widget.onVideoTap(video),
                              onFavorite: widget.onFavorite != null 
                                  ? () => widget.onFavorite!(video) 
                                  : null,
                              onShare: widget.onShare != null 
                                  ? () => widget.onShare!(video) 
                                  : null,
                              onDelete: widget.onDelete != null 
                                  ? () => widget.onDelete!(video) 
                                  : null,
                            ),
                            
                            // Video info overlay
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
                                      Colors.black.withValues(alpha: 0.8),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      video.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (video.duration != null) ...[
                                          const Icon(
                                            Icons.access_time,
                                            color: Colors.white70,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            video.formattedDuration,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                        ],
                                        const Icon(
                                          Icons.storage,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          video.formattedSize,
                                          style: const TextStyle(
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
              math.min(widget.videos.length, 5),
              (index) {
                final actualIndex = _currentIndex - 2 + index;
                final isActive = actualIndex == _currentIndex;
                final isVisible = actualIndex >= 0 && actualIndex < widget.videos.length;
                
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
}