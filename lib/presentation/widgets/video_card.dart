import 'package:flutter/material.dart';
import '../../data/models/video_model.dart';
import '../../core/constants/app_constants.dart';

class VideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final bool showLastPlayed;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.showLastPlayed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: const Color(0xFFF2F2F7),
                ),
                child: _buildThumbnail(),
              ),
            ),
            
            // Video Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Name
                    Text(
                      video.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF000000),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const Spacer(),
                    
                    // Duration and Size
                    Row(
                      children: [
                        if (video.duration != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              video.formattedDuration,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          video.formattedSize,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    // Last Played (if enabled)
                    if (showLastPlayed && video.lastPlayed != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Played ${_formatLastPlayed(video.lastPlayed!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (video.thumbnailPath != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadius),
        ),
        child: Image.asset(
          video.thumbnailPath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail();
          },
        ),
      );
    }
    
    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        gradient: const LinearGradient(
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
          Icons.play_circle_fill,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatLastPlayed(DateTime lastPlayed) {
    final now = DateTime.now();
    final difference = now.difference(lastPlayed);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}