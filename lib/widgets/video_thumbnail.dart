import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  
  const VideoThumbnailWidget({
    Key? key,
    required this.videoPath,
    this.width = 120,
    this.height = 80,
    this.borderRadius,
  }) : super(key: key);
  
  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }
  
  Future<void> _generateThumbnail() async {
    try {
      // Create a unique filename based on video path hash
      final bytes = utf8.encode(widget.videoPath);
      final digest = sha256.convert(bytes);
      final fileName = 'thumb_${digest.toString().substring(0, 16)}.jpg';
      
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = '${tempDir.path}/$fileName';
      
      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
        });
        return;
      }
      
      // Generate new thumbnail
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        maxHeight: 200,
        quality: 75,
      );
      
      if (thumbnail != null && await File(thumbnail).exists()) {
        setState(() {
          _thumbnailPath = thumbnail;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        child: _buildContent(),
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      );
    }
    
    if (_hasError || _thumbnailPath == null) {
      return Container(
        color: Colors.grey[700],
        child: const Center(
          child: Icon(
            Icons.video_file,
            color: Colors.white54,
            size: 32,
          ),
        ),
      );
    }
    
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(_thumbnailPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[700],
              child: const Center(
                child: Icon(
                  Icons.video_file,
                  color: Colors.white54,
                  size: 32,
                ),
              ),
            );
          },
        ),
        // Play overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}