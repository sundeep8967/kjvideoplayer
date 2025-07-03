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
        }
      }

      // Generate new thumbnail
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: await _getThumbnailDirectory(),
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 300,
        quality: 75,
      );

      if (thumbnailPath != null) {
        _thumbnailCache[videoPath] = thumbnailPath;
        return thumbnailPath;
      }
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
    }
    
    return null;
  }

  /// Generate thumbnail as Uint8List for immediate use
  Future<Uint8List?> generateThumbnailData(String videoPath) async {
    try {
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 300,
        quality: 75,
      );

      return thumbnailData;
    } catch (e) {
      print('Error generating thumbnail data for $videoPath: $e');
      return null;
    }
  }

  /// Get the directory for storing thumbnails
  Future<String> _getThumbnailDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory('${appDir.path}/thumbnails');
    
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }
    
    return thumbnailDir.path;
  }

  /// Get cached thumbnail path
  String? getCachedThumbnail(String videoPath) {
    return _thumbnailCache[videoPath];
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