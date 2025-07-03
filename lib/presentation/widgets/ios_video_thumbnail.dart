import 'package:flutter/material.dart';
import 'dart:io';
import '../../data/models/video_model.dart';
import '../../data/services/thumbnail_service.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import 'ios_context_menu.dart';
import 'ios_action_sheet.dart';

class IOSVideoThumbnail extends StatefulWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const IOSVideoThumbnail({
    super.key,
    required this.video,
    required this.onTap,
    this.onFavorite,
    this.onDelete,
    this.onShare,
  });

  @override
  State<IOSVideoThumbnail> createState() => _IOSVideoThumbnailState();
}

class _IOSVideoThumbnailState extends State<IOSVideoThumbnail> {
  final ThumbnailService _thumbnailService = ThumbnailService();
  String? _thumbnailPath;
  bool _isLoadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // Check if video file exists first
    if (!widget.video.exists) {
      if (mounted) {
        setState(() {
          _isLoadingThumbnail = false;
          _thumbnailPath = null;
        });
      }
      return;
    }

    // Check if thumbnail already exists
    final cachedThumbnail = _thumbnailService.getCachedThumbnail(widget.video.path);
    if (cachedThumbnail != null && await File(cachedThumbnail).exists()) {
      if (mounted) {
        setState(() {
          _thumbnailPath = cachedThumbnail;
        });
      }
      return;
    }

    // Generate new thumbnail with error handling
    if (!_isLoadingThumbnail) {
      setState(() {
        _isLoadingThumbnail = true;
      });

      try {
        final thumbnailPath = await _thumbnailService.generateThumbnail(widget.video.path);
        
        if (mounted) {
          setState(() {
            _thumbnailPath = thumbnailPath;
            _isLoadingThumbnail = false;
          });
        }
      } catch (e) {
        // Handle corrupted or incomplete video files
        if (mounted) {
          setState(() {
            _thumbnailPath = null;
            _isLoadingThumbnail = false;
          });
        }
      }
    }
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
          title: 'Play',
          icon: Icons.play_arrow,
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
            title: 'Share',
            icon: Icons.share,
            onPressed: widget.onShare!,
          ),
        IOSContextMenuAction(
          title: 'Show Info',
          icon: Icons.info_outline,
          onPressed: () => _showVideoInfo(context),
        ),
        if (widget.onDelete != null)
          IOSContextMenuAction(
            title: 'Delete',
            icon: Icons.delete_outline,
            onPressed: () => _confirmDelete(context),
            isDestructive: true,
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
            // Thumbnail
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
                  child: _buildThumbnailContent(),
                ),
              ),
            ),
            
            // Video Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Name
                    Text(
                      widget.video.displayName,
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
                        if (widget.video.duration != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.video.formattedDuration,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            widget.video.formattedSize,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildThumbnailContent() {
    // Check if video file doesn't exist
    if (!widget.video.exists) {
      return _buildErrorThumbnail('File Not Found', Icons.file_present);
    }

    if (_isLoadingThumbnail) {
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

    if (_thumbnailPath != null && File(_thumbnailPath!).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_thumbnailPath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorThumbnail('Corrupted File', Icons.broken_image);
            },
          ),
          // Play button overlay
          const Center(
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 24,
              child: Icon(
                Icons.play_arrow,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Check file size to detect incomplete downloads
    if (widget.video.size < 1024) { // Less than 1KB likely incomplete
      return _buildErrorThumbnail('Incomplete Download', Icons.download);
    }

    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
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
          Icons.play_circle_fill,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorThumbnail(String errorText, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red[300]!,
            Colors.red[600]!,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            errorText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showVideoInfo(BuildContext context) {
    IOSActionSheet.show(
      context: context,
      title: widget.video.displayName,
      message: 'Video Information',
      actions: [
        IOSActionSheetAction(
          title: 'Size: ${widget.video.formattedSize}',
          onPressed: () {},
        ),
        if (widget.video.duration != null)
          IOSActionSheetAction(
            title: 'Duration: ${widget.video.formattedDuration}',
            onPressed: () {},
          ),
        IOSActionSheetAction(
          title: 'Modified: ${_formatDate(widget.video.dateModified)}',
          onPressed: () {},
        ),
        IOSActionSheetAction(
          title: 'Path: ${widget.video.path}',
          onPressed: () {},
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    IOSActionSheet.show(
      context: context,
      title: 'Delete Video',
      message: 'Are you sure you want to delete "${widget.video.displayName}"? This action cannot be undone.',
      actions: [
        IOSActionSheetAction(
          title: 'Delete',
          onPressed: () {
            HapticFeedbackHelper.error();
            widget.onDelete?.call();
          },
          isDestructive: true,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}