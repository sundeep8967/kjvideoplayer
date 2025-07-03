import 'package:flutter/material.dart';
import '../../data/models/video_model.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import 'ios_video_thumbnail.dart';

class SwipeableVideoCard extends StatefulWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const SwipeableVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onFavorite,
    this.onDelete,
    this.onShare,
  });

  @override
  State<SwipeableVideoCard> createState() => _SwipeableVideoCardState();
}

class _SwipeableVideoCardState extends State<SwipeableVideoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < -2) {
          // Swiping left
          if (!_animationController.isAnimating) {
            _animationController.forward();
            HapticFeedbackHelper.lightImpact();
          }
        } else if (details.delta.dx > 2) {
          // Swiping right
          if (!_animationController.isAnimating) {
            _animationController.reverse();
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (_animationController.value > 0.5) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      },
      onTap: () {
        if (_animationController.value > 0) {
          _animationController.reverse();
        } else {
          widget.onTap();
        }
      },
      child: Stack(
        children: [
          // Background actions (revealed when swiped)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.red.withValues(alpha: 0.1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onFavorite != null)
                    _buildActionButton(
                      icon: Icons.favorite,
                      color: Colors.orange,
                      onTap: () {
                        HapticFeedbackHelper.success();
                        _animationController.reverse();
                        widget.onFavorite!();
                      },
                    ),
                  if (widget.onShare != null)
                    _buildActionButton(
                      icon: Icons.share,
                      color: Colors.blue,
                      onTap: () {
                        HapticFeedbackHelper.lightImpact();
                        _animationController.reverse();
                        widget.onShare!();
                      },
                    ),
                  if (widget.onDelete != null)
                    _buildActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      onTap: () {
                        HapticFeedbackHelper.error();
                        _animationController.reverse();
                        widget.onDelete!();
                      },
                    ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          
          // Main card content
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: _slideAnimation.value * MediaQuery.of(context).size.width,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: IOSVideoThumbnail(
                    video: widget.video,
                    onTap: widget.onTap,
                    onFavorite: widget.onFavorite,
                    onDelete: widget.onDelete,
                    onShare: widget.onShare,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}