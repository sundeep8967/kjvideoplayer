import 'dart:io';

class VideoModel {
  final String path;
  final String name;
  final String displayName;
  final int size;
  final DateTime dateModified;
  final Duration? duration;
  final String? thumbnailPath;
  final bool isFavorite;
  final DateTime? lastPlayed;
  final Duration? lastPosition;

  const VideoModel({
    required this.path,
    required this.name,
    required this.displayName,
    required this.size,
    required this.dateModified,
    this.duration,
    this.thumbnailPath,
    this.isFavorite = false,
    this.lastPlayed,
    this.lastPosition,
  });

  // Get file extension
  String get extension => path.split('.').last.toLowerCase();
  
  // Get file size in readable format
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  // Get formatted duration
  String get formattedDuration {
    if (duration == null) return 'Unknown';
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Check if file exists
  bool get exists => File(path).existsSync();
  
  // Copy with method for immutable updates
  VideoModel copyWith({
    String? path,
    String? name,
    String? displayName,
    int? size,
    DateTime? dateModified,
    Duration? duration,
    String? thumbnailPath,
    bool? isFavorite,
    DateTime? lastPlayed,
    Duration? lastPosition,
  }) {
    return VideoModel(
      path: path ?? this.path,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      size: size ?? this.size,
      dateModified: dateModified ?? this.dateModified,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }

  // Convert to/from JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'displayName': displayName,
      'size': size,
      'dateModified': dateModified.millisecondsSinceEpoch,
      'duration': duration?.inMilliseconds,
      'thumbnailPath': thumbnailPath,
      'isFavorite': isFavorite,
      'lastPlayed': lastPlayed?.millisecondsSinceEpoch,
      'lastPosition': lastPosition?.inMilliseconds,
    };
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      path: json['path'],
      name: json['name'],
      displayName: json['displayName'],
      size: json['size'],
      dateModified: DateTime.fromMillisecondsSinceEpoch(json['dateModified']),
      duration: json['duration'] != null 
          ? Duration(milliseconds: json['duration']) 
          : null,
      thumbnailPath: json['thumbnailPath'],
      isFavorite: json['isFavorite'] ?? false,
      lastPlayed: json['lastPlayed'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastPlayed']) 
          : null,
      lastPosition: json['lastPosition'] != null 
          ? Duration(milliseconds: json['lastPosition']) 
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoModel && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() {
    return 'VideoModel(path: $path, name: $name, size: $formattedSize)';
  }
}