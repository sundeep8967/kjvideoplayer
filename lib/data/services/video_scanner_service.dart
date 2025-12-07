import 'dart:io';
import 'dart:isolate';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/video_model.dart';
import '../models/folder_model.dart';
import '../../core/constants/app_constants.dart';

/// Data class for passing scan parameters to isolate
class _ScanParams {
  final List<String> directories;
  final List<String> extensions;

  _ScanParams(this.directories, this.extensions);
}

/// Data class for video data that can be passed across isolate boundary
class _VideoData {
  final String path;
  final String name;
  final String displayName;
  final int size;
  final int dateModifiedMs;

  _VideoData({
    required this.path,
    required this.name,
    required this.displayName,
    required this.size,
    required this.dateModifiedMs,
  });
}

class VideoScannerService {
  static final VideoScannerService _instance = VideoScannerService._internal();
  factory VideoScannerService() => _instance;
  VideoScannerService._internal();

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

  /// Scan for all video files using background isolate (non-blocking)
  Future<List<VideoModel>> scanAllVideosInBackground() async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission not granted');
    }

    try {
      // Get directories dynamically
      final directories = await _getVideoDirectoriesDynamic();
      
      print('[VideoScanner] Scanning ${directories.length} directories in background isolate');
      
      // Run scanning in background isolate
      final params = _ScanParams(
        directories,
        AppConstants.supportedVideoExtensions,
      );
      
      final videoDataList = await Isolate.run(() => _scanVideosIsolate(params));
      
      // Convert back to VideoModel
      final videos = videoDataList.map((data) => VideoModel(
        path: data.path,
        name: data.name,
        displayName: data.displayName,
        size: data.size,
        dateModified: DateTime.fromMillisecondsSinceEpoch(data.dateModifiedMs),
      )).toList();
      
      print('[VideoScanner] Found ${videos.length} videos');
      return videos;
    } catch (e) {
      print('Error scanning videos in background: $e');
      return [];
    }
  }

  /// Static function that runs in isolate - must be top-level or static
  static List<_VideoData> _scanVideosIsolate(_ScanParams params) {
    final List<_VideoData> allVideos = [];
    final Set<String> seenPaths = {};
    
    for (final directoryPath in params.directories) {
      try {
        final directory = Directory(directoryPath);
        if (!directory.existsSync()) continue;
        
        // Use sync operations inside isolate (they won't block main thread)
        final entities = directory.listSync(recursive: true, followLinks: false);
        
        for (final entity in entities) {
          if (entity is File) {
            final path = entity.path;
            
            // Check extension
            final extension = '.${path.split('.').last.toLowerCase()}';
            if (!params.extensions.contains(extension)) continue;
            
            // Skip duplicates
            if (seenPaths.contains(path)) continue;
            seenPaths.add(path);
            
            try {
              final stat = entity.statSync();
              final fileName = path.split('/').last;
              final nameWithoutExtension = fileName.split('.').first;
              final displayName = nameWithoutExtension
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ');
              
              allVideos.add(_VideoData(
                path: path,
                name: fileName,
                displayName: displayName,
                size: stat.size,
                dateModifiedMs: stat.modified.millisecondsSinceEpoch,
              ));
            } catch (e) {
              // Skip files that can't be accessed
              continue;
            }
          }
        }
      } catch (e) {
        // Skip directories that can't be accessed
        continue;
      }
    }
    
    return allVideos;
  }

  /// Get video directories dynamically using external_path package
  Future<List<String>> _getVideoDirectoriesDynamic() async {
    List<String> directories = [];

    try {
      // Get external storage directories dynamically
      final externalStorageDirs = await ExternalPath.getExternalStorageDirectories();
      
      print('[VideoScanner] Found ${externalStorageDirs.length} external storage roots');
      
      for (final storageRoot in externalStorageDirs) {
        // Add common video subdirectories for each storage root
        directories.addAll([
          '$storageRoot/Movies',
          '$storageRoot/DCIM',
          '$storageRoot/Download',
          '$storageRoot/Downloads',
          '$storageRoot/Pictures',
          '$storageRoot/Camera',
          '$storageRoot/Video',
          '$storageRoot/Videos',
        ]);
        
        // Add app-specific media directories
        directories.addAll([
          '$storageRoot/WhatsApp/Media/WhatsApp Video',
          '$storageRoot/Telegram/Telegram Video',
          '$storageRoot/Android/media',
        ]);
      }
      
      // Also try to get public directories
      try {
        final movieDir = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_MOVIES,
        );
        if (!directories.contains(movieDir)) {
          directories.add(movieDir);
        }
        
        final dcimDir = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DCIM,
        );
        if (!directories.contains(dcimDir)) {
          directories.add(dcimDir);
        }
        
        final downloadDir = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOADS,
        );
        if (!directories.contains(downloadDir)) {
          directories.add(downloadDir);
        }
      } catch (e) {
        print('[VideoScanner] Could not get public directories: $e');
      }
      
      // Add SD card directories
      directories.addAll(await _getExternalStorageDirectories());
      
    } catch (e) {
      print('[VideoScanner] Error getting dynamic directories: $e');
      // Fallback to common paths if dynamic retrieval fails
      directories = _getFallbackDirectories();
    }

    // Remove duplicates and filter existing
    return directories.toSet().toList();
  }

  /// Fallback directories if dynamic retrieval fails
  List<String> _getFallbackDirectories() {
    return [
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Camera',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/Telegram/Telegram Video',
      '/storage/emulated/0/Android/media',
    ];
  }

  /// Get external storage directories (SD cards, etc.)
  Future<List<String>> _getExternalStorageDirectories() async {
    List<String> directories = [];

    try {
      // Check for SD card and other external storage
      final storageDir = Directory('/storage');
      if (await storageDir.exists()) {
        final entities = storageDir.listSync();
        for (final entity in entities) {
          if (entity is Directory && entity.path != '/storage/emulated' && entity.path != '/storage/self') {
            directories.add('${entity.path}/Movies');
            directories.add('${entity.path}/DCIM');
            directories.add('${entity.path}/Download');
            directories.add('${entity.path}/Video');
          }
        }
      }
    } catch (e) {
      print('[VideoScanner] Error getting external storage directories: $e');
    }

    return directories;
  }

  /// Legacy sync method - kept for backward compatibility but deprecated
  @Deprecated('Use scanAllVideosInBackground() instead for better performance')
  Future<List<VideoModel>> scanAllVideos() async {
    return scanAllVideosInBackground();
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
        subfolders: [],
        dateModified: DateTime.now(),
      );
      folders.add(folder);
    }

    return folders;
  }
}