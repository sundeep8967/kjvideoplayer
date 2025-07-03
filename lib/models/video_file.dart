import 'dart:io';

class VideoFile {
  final String path;
  final String name;
  final String extension;
  final int size;
  final DateTime lastModified;
  final DateTime lastAccessed;
  String? thumbnailPath;
  
  VideoFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.size,
    required this.lastModified,
    required this.lastAccessed,
    this.thumbnailPath,
  });
  
  factory VideoFile.fromFileSystemEntity(FileSystemEntity entity, FileStat stat) {
    final name = entity.path.split('/').last;
    final extension = name.split('.').last.toLowerCase();
    
    return VideoFile(
      path: entity.path,
      name: name,
      extension: extension,
      size: stat.size,
      lastModified: stat.modified,
      lastAccessed: stat.accessed,
    );
  }
  
  String get formattedSize {
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String get formattedDuration {
    final duration = DateTime.now().difference(lastModified);
    if (duration.inDays > 0) return '${duration.inDays} days ago';
    if (duration.inHours > 0) return '${duration.inHours} hours ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes} minutes ago';
    return 'Just now';
  }
}