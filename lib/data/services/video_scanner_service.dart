import 'dart:io';
import 'package:file_manager/file_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/video_model.dart';
import '../models/folder_model.dart';
import '../../core/constants/app_constants.dart';

class VideoScannerService {
  static final VideoScannerService _instance = VideoScannerService._internal();
  factory VideoScannerService() => _instance;
  VideoScannerService._internal();

  final FileManagerController _controller = FileManagerController();
  
  /// Check and request storage permissions
  Future<bool> requestStoragePermission() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      PermissionStatus permission;
      
      if (sdkInt >= 33) {
        // Android 13+ (API 33+) - Use scoped storage permissions
        permission = await Permission.videos.status;
        if (!permission.isGranted) {
          permission = await Permission.videos.request();
        }
        
        // Also check for photos permission if needed
        if (permission.isGranted) {
          final photosPermission = await Permission.photos.status;
          if (!photosPermission.isGranted) {
            await Permission.photos.request();
          }
        }
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32) - Use MANAGE_EXTERNAL_STORAGE
        permission = await Permission.manageExternalStorage.status;
        if (!permission.isGranted) {
          permission = await Permission.manageExternalStorage.request();
        }
      } else {
        // Android 10 and below - Use traditional storage permission
        permission = await Permission.storage.status;
        if (!permission.isGranted) {
          permission = await Permission.storage.request();
        }
      }
      
      return permission.isGranted;
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }

  /// Scan for all video files on the device
  Future<List<VideoModel>> scanAllVideos() async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission not granted');
    }

    List<VideoModel> allVideos = [];
    
    try {
      // Get common video directories
      final directories = await _getVideoDirectories();
      
      for (final directory in directories) {
        if (await Directory(directory).exists()) {
          final videos = await _scanDirectory(directory);
          allVideos.addAll(videos);
        }
      }
      
      // Remove duplicates based on path
      final uniqueVideos = <String, VideoModel>{};
      for (final video in allVideos) {
        uniqueVideos[video.path] = video;
      }
      
      return uniqueVideos.values.toList();
    } catch (e) {
      print('Error scanning videos: $e');
      return [];
    }
  }

  /// Scan a specific directory for videos
  Future<List<VideoModel>> _scanDirectory(String directoryPath) async {
    List<VideoModel> videos = [];
    
    try {
      final directory = Directory(directoryPath);
      final entities = directory.listSync(recursive: true, followLinks: false);
      
      for (final entity in entities) {
        if (entity is File && _isVideoFile(entity.path)) {
          try {
            final stat = entity.statSync();
            final video = VideoModel(
              path: entity.path,
              name: entity.path.split('/').last,
              displayName: _getDisplayName(entity.path),
              size: stat.size,
              dateModified: stat.modified,
            );
            videos.add(video);
          } catch (e) {
            // Skip files that can't be accessed
            continue;
          }
        }
      }
    } catch (e) {
      print('Error scanning directory $directoryPath: $e');
    }
    
    return videos;
  }

  /// Get common video directories
  Future<List<String>> _getVideoDirectories() async {
    List<String> directories = [];
    
    try {
      // Add common Android video directories
      directories.addAll([
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Camera',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/Telegram/Telegram Video',
        '/storage/emulated/0/Android/media',
      ]);
      
      // Add external storage directories if available
      final externalDirs = await _getExternalStorageDirectories();
      directories.addAll(externalDirs);
      
    } catch (e) {
      print('Error getting video directories: $e');
    }
    
    return directories;
  }

  /// Get external storage directories
  Future<List<String>> _getExternalStorageDirectories() async {
    List<String> directories = [];
    
    try {
      // Check for SD card and other external storage
      final storageDir = Directory('/storage');
      if (await storageDir.exists()) {
        final entities = storageDir.listSync();
        for (final entity in entities) {
          if (entity is Directory && entity.path != '/storage/emulated') {
            directories.add('${entity.path}/Movies');
            directories.add('${entity.path}/DCIM');
            directories.add('${entity.path}/Download');
          }
        }
      }
    } catch (e) {
      print('Error getting external storage directories: $e');
    }
    
    return directories;
  }

  /// Check if file is a video file
  bool _isVideoFile(String path) {
    final extension = '.${path.split('.').last.toLowerCase()}';
    return AppConstants.supportedVideoExtensions.contains(extension);
  }

  /// Get display name from file path
  String _getDisplayName(String path) {
    final fileName = path.split('/').last;
    final nameWithoutExtension = fileName.split('.').first;
    return nameWithoutExtension.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  /// Organize videos into folders
  List<FolderModel> organizeVideosIntoFolders(List<VideoModel> videos) {
    Map<String, List<VideoModel>> folderMap = {};
    
    for (final video in videos) {
      final folderPath = video.path.substring(0, video.path.lastIndexOf('/'));
      if (!folderMap.containsKey(folderPath)) {
        folderMap[folderPath] = [];
      }
      folderMap[folderPath]!.add(video);
    }
    
    List<FolderModel> folders = [];
    for (final entry in folderMap.entries) {
      final folderName = entry.key.split('/').last;
      final folder = FolderModel(
        path: entry.key,
        name: folderName,
        videos: entry.value,
        subfolders: [], // TODO: Implement nested folder structure
        dateModified: DateTime.now(),
      );
      folders.add(folder);
    }
    
    return folders;
  }
}