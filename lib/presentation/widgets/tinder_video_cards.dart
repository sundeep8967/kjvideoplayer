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
                icon: Icons.arrow_back,
                label: 'Swipe Left\nPrevious',
                color: Colors.blue,
              ),
              _buildSwipeIndicator(
                icon: Icons.favorite,
                label: 'Swipe Up\nFavorite',
                color: Colors.red,
              ),
              _buildSwipeIndicator(
                icon: Icons.play_circle_fill,
                label: 'Tap\nPlay Video',
                color: Colors.green,
              ),
              _buildSwipeIndicator(
                icon: Icons.share,
                label: 'Swipe Down\nShare',
                color: Colors.orange,
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
              for (int i = math.min(_currentIndex + 2, widget.videos.length - 1); 
                   i > _currentIndex; i--)
                _buildBackgroundCard(i),
              
              // Current card
              if (_currentIndex < widget.videos.length)
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
                '${_currentIndex + 1} / ${widget.videos.length}',
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
          child: _buildCard(widget.videos[index], index, isInteractive: false),
        ),
      ),
    );
  }

  Widget _buildCurrentCard(int index) {
    return GestureDetector(
      onTap: () => widget.onVideoTap(widget.videos[index]),
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
        
        // Horizontal swipes
        if (velocity.dx.abs() > velocity.dy.abs()) {
          if (velocity.dx > 500) {
            _onSwipeRight();
          } else if (velocity.dx < -500) {
            _onSwipeLeft();
          }
        } 
        // Vertical swipes
        else {
          if (velocity.dy < -500) {
            _onSwipeUp();
          } else if (velocity.dy > 500) {
            _onSwipeDown();
          }
        }
      },
      child: Transform.translate(
        offset: Offset(_isDragging ? _dragOffset * 0.3 : 0, 0),
        child: Transform.rotate(
          angle: _isDragging ? _dragOffset * 0.001 : 0,
          child: _buildCard(widget.videos[index], index, isInteractive: true),
        ),
      ),
    );
  }

  Widget _buildCard(VideoModel video, int index, {required bool isInteractive}) {
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
              // Video thumbnail
              IOSVideoThumbnail(
                video: video,
                onTap: () => widget.onVideoTap(video),
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
              
              // Video info
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
                        video.displayName,
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
                            Icons.access_time,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            video.formattedDuration,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            video.formattedSize,
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
              
              // Play button overlay
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
                      Icons.play_arrow,
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
}