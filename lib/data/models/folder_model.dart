import 'video_model.dart';

class FolderModel {
  final String path;
  final String name;
  final List<VideoModel> videos;
  final List<FolderModel> subfolders;
  final DateTime dateModified;

  const FolderModel({
    required this.path,
    required this.name,
    required this.videos,
    required this.subfolders,
    required this.dateModified,
  });

  // Get total video count including subfolders
  int get totalVideoCount {
    int count = videos.length;
    for (final subfolder in subfolders) {
      count += subfolder.totalVideoCount;
    }
    return count;
  }

  // Get total size of all videos
  int get totalSize {
    int size = 0;
    for (final video in videos) {
      size += video.size;
    }
    for (final subfolder in subfolders) {
      size += subfolder.totalSize;
    }
    return size;
  }

  // Get formatted total size
  String get formattedTotalSize {
    if (totalSize < 1024) return '${totalSize}B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  // Get all videos recursively
  List<VideoModel> get allVideos {
    List<VideoModel> allVids = List.from(videos);
    for (final subfolder in subfolders) {
      allVids.addAll(subfolder.allVideos);
    }
    return allVids;
  }

  // Get thumbnail from first video
  String? get thumbnailPath {
    if (videos.isNotEmpty && videos.first.thumbnailPath != null) {
      return videos.first.thumbnailPath;
    }
    for (final subfolder in subfolders) {
      final thumbnail = subfolder.thumbnailPath;
      if (thumbnail != null) return thumbnail;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderModel && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() {
    return 'FolderModel(path: $path, name: $name, videos: ${videos.length}, subfolders: ${subfolders.length})';
  }
}