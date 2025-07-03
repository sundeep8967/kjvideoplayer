import 'package:flutter/material.dart';
import 'dart:io';
import '../../data/models/video_model.dart';
import '../../data/services/thumbnail_service.dart';

class VideoListThumbnail extends StatefulWidget {
  final VideoModel video;
  final double size;

  const VideoListThumbnail({
    super.key,
    required this.video,
    this.size = 60,
  });

  @override
  State<VideoListThumbnail> createState() => _VideoListThumbnailState();
}

class _VideoListThumbnailState extends State<VideoListThumbnail> {
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
      return;
    }

    // Check cache first
    final cachedThumbnail = _thumbnailService.getCachedThumbnail(widget.video.path);
    if (cachedThumbnail != null && await File(cachedThumbnail).exists()) {
      if (mounted) {
        setState(() {
          _thumbnailPath = cachedThumbnail;
        });
      }
      return;
    }

    // Generate thumbnail if not in cache
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
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF2F2F7),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildThumbnailContent(),
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
            width: 16,
            height: 16,
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
              return _buildErrorThumbnail('Corrupted', Icons.broken_image);
            },
          ),
          // Small play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Check file size to detect incomplete downloads
    if (widget.video.size < 1024) {
      return _buildErrorThumbnail('Incomplete', Icons.download);
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
          size: 24,
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
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
          Text(
            errorText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}