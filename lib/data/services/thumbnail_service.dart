import 'dart:io';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, String> _thumbnailCache = {};

  /// Generate thumbnail for a video file
  Future<String?> generateThumbnail(String videoPath) async {
    try {
      // Check if thumbnail already exists in cache
      if (_thumbnailCache.containsKey(videoPath)) {
        final cachedPath = _thumbnailCache[videoPath]!;
        if (await File(cachedPath).exists()) {
          return cachedPath;
        } else {
          // Remove invalid cache entry
          _thumbnailCache.remove(videoPath);
        }
      }

      // Check if video file exists and is readable
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        print('Video file does not exist: $videoPath');
        return null;
      }

      // Check file size (avoid very small or very large files)
      final fileSize = await videoFile.length();
      if (fileSize < 1024) { // Less than 1KB
        print('Video file too small (likely incomplete): $videoPath');
        return null;
      }

      // Check if file is actually a video by extension
      if (!isVideoSupported(videoPath)) {
        print('Unsupported video format: $videoPath');
        return null;
      }

      // Try multiple thumbnail generation strategies
      String? thumbnailPath;
      
      // Strategy 1: Default settings
      try {
        thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: await _getThumbnailDirectory(),
          imageFormat: ImageFormat.JPEG,
          maxHeight: 300,
          maxWidth: 300,
          quality: 75,
          timeMs: 1000, // 1 second into video
        );
      } catch (e) {
        print('Strategy 1 failed for $videoPath: $e');
      }

      // Strategy 2: Try different time position if first failed
      if (thumbnailPath == null) {
        try {
          thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: videoPath,
            thumbnailPath: await _getThumbnailDirectory(),
            imageFormat: ImageFormat.JPEG,
            maxHeight: 300,
            maxWidth: 300,
            quality: 60,
            timeMs: 5000, // 5 seconds into video
          );
        } catch (e) {
          print('Strategy 2 failed for $videoPath: $e');
        }
      }

      // Strategy 3: Try beginning of video
      if (thumbnailPath == null) {
        try {
          thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: videoPath,
            thumbnailPath: await _getThumbnailDirectory(),
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            maxWidth: 200,
            quality: 50,
            timeMs: 0, // Very beginning
          );
        } catch (e) {
          print('Strategy 3 failed for $videoPath: $e');
        }
      }

      if (thumbnailPath != null && await File(thumbnailPath).exists()) {
        _thumbnailCache[videoPath] = thumbnailPath;
        print('Successfully generated thumbnail for: $videoPath');
        return thumbnailPath;
      } else {
        print('All thumbnail generation strategies failed for: $videoPath');
        // Cache the failure to avoid repeated attempts
        _thumbnailCache[videoPath] = '';
      }
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
      // Cache the failure
      _thumbnailCache[videoPath] = '';
    }
    
    return null;
  }

  /// Generate thumbnail as Uint8List for immediate use
  Future<Uint8List?> generateThumbnailData(String videoPath) async {
    try {
      // Check if video file exists first
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        print('Video file does not exist: $videoPath');
        return null;
      }

      Uint8List? thumbnailData;

      // Try multiple strategies for thumbnail data generation
      try {
        thumbnailData = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 300,
          maxWidth: 300,
          quality: 75,
          timeMs: 1000,
        );
      } catch (e) {
        print('Thumbnail data strategy 1 failed: $e');
        
        // Fallback strategy
        try {
          thumbnailData = await VideoThumbnail.thumbnailData(
            video: videoPath,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            maxWidth: 200,
            quality: 50,
            timeMs: 0,
          );
        } catch (e2) {
          print('Thumbnail data strategy 2 failed: $e2');
        }
      }

      return thumbnailData;
    } catch (e) {
      print('Error generating thumbnail data for $videoPath: $e');
      return null;
    }
  }

  /// Get the directory for storing thumbnails
  Future<String> _getThumbnailDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailDir = Directory('${appDir.path}/thumbnails');
      
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }
      
      // Ensure directory is writable
      final testFile = File('${thumbnailDir.path}/test.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();
      
      return thumbnailDir.path;
    } catch (e) {
      print('Error creating thumbnail directory: $e');
      // Fallback to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fallbackDir = Directory('${tempDir.path}/thumbnails');
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir.path;
    }
  }

  /// Check if video file is supported for thumbnail generation
  bool isVideoSupported(String videoPath) {
    final extension = videoPath.toLowerCase().split('.').last;
    const supportedFormats = [
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'ts', 'mts'
    ];
    return supportedFormats.contains(extension);
  }

  /// Generate thumbnails for folder (only first few videos for efficiency)
  Future<List<String?>> generateFolderThumbnails(List<String> videoPaths, {int maxThumbnails = 4}) async {
    List<String?> thumbnails = [];
    
    // Only generate thumbnails for the first few videos to improve performance
    final videosToProcess = videoPaths.take(maxThumbnails).toList();
    
    for (final videoPath in videosToProcess) {
      try {
        final thumbnail = await generateThumbnail(videoPath);
        thumbnails.add(thumbnail);
        
        // If we get a successful thumbnail, we can break early for single thumbnail display
        if (thumbnail != null && maxThumbnails == 1) {
          break;
        }
      } catch (e) {
        print('Error generating folder thumbnail for $videoPath: $e');
        thumbnails.add(null);
      }
    }
    
    return thumbnails;
  }

  /// Get the best thumbnail from a folder (first available)
  Future<String?> getFolderThumbnail(List<String> videoPaths) async {
    // Try to find a cached thumbnail first
    for (final videoPath in videoPaths) {
      final cached = getCachedThumbnail(videoPath);
      if (cached != null && cached.isNotEmpty && await File(cached).exists()) {
        return cached;
      }
    }
    
    // Generate thumbnail for the first video that works
    for (final videoPath in videoPaths) {
      try {
        final thumbnail = await generateThumbnail(videoPath);
        if (thumbnail != null) {
          return thumbnail;
        }
      } catch (e) {
        print('Error generating thumbnail for folder video $videoPath: $e');
        continue;
      }
    }
    
    return null;
  }

  /// Get cached thumbnail path
  String? getCachedThumbnail(String videoPath) {
    final cached = _thumbnailCache[videoPath];
    return (cached != null && cached.isNotEmpty) ? cached : null;
  }

  /// Clear thumbnail cache
  void clearCache() {
    _thumbnailCache.clear();
  }

  /// Delete all cached thumbnails
  Future<void> clearAllThumbnails() async {
    try {
      final thumbnailDir = Directory(await _getThumbnailDirectory());
      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
      }
      _thumbnailCache.clear();
    } catch (e) {
      print('Error clearing thumbnails: $e');
    }
  }
}