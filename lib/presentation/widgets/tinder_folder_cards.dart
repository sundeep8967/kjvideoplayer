import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../data/models/video_model.dart';
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
                            IOSFolderCard(
                              folderName: folderName,
                              videoCount: videos.length,
                              videos: videos,
                              onTap: () => widget.onFolderTap(folderName),
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
}