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

  void _nextCard() {
    if (_currentIndex < widget.videos.length - 1) {
      HapticFeedbackHelper.lightImpact();
      _animateToNext();
    }
  }

  void _previousCard() {
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
        
        // Clean card view
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.9),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              HapticFeedbackHelper.lightImpact();
            },
            itemCount: widget.videos.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                child: _buildCard(widget.videos[index], index, isInteractive: true),
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



  Widget _buildCard(VideoModel video, int index, {required bool isInteractive}) {
    return GestureDetector(
      onTap: () => widget.onVideoTap(video),
      onLongPress: () {
        HapticFeedbackHelper.lightImpact();
        _showVideoActions(video);
      },
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
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              
              // Video info
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
                        video.displayName,
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
                            Icons.play_circle_outline,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            video.formattedDuration,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            video.formattedSize,
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
              
              // Play button overlay
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.black87,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoActions(VideoModel video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.favorite_outline, color: Colors.red),
              title: const Text('Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                _onSwipeUp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.blue),
              title: const Text('Share Video'),
              onTap: () {
                Navigator.pop(context);
                _onSwipeDown();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}