import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _recentVideosKey = 'recent_videos';
  static const String _favoriteVideosKey = 'favorite_videos';
  static const String _bookmarksKey = 'bookmarks';
  static const String _playbackPositionsKey = 'playback_positions';

  /// Save recent videos
  Future<void> saveRecentVideos(List<VideoModel> videos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = videos.map((video) => video.toJson()).toList();
    await prefs.setString(_recentVideosKey, jsonEncode(jsonList));
  }

  /// Get recent videos
  Future<List<VideoModel>> getRecentVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentVideosKey);
      if (jsonString == null) return [];
      
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => VideoModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading recent videos: $e');
      return [];
    }
  }

  /// Add video to recent list
  Future<void> addToRecent(VideoModel video) async {
    final recentVideos = await getRecentVideos();
    
    // Remove if already exists
    recentVideos.removeWhere((v) => v.path == video.path);
    
    // Add to beginning
    recentVideos.insert(0, video.copyWith(lastPlayed: DateTime.now()));
    
    // Keep only last 50 videos
    if (recentVideos.length > 50) {
      recentVideos.removeRange(50, recentVideos.length);
    }
    
    await saveRecentVideos(recentVideos);
  }

  /// Save favorite videos
  Future<void> saveFavoriteVideos(List<VideoModel> videos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = videos.map((video) => video.toJson()).toList();
    await prefs.setString(_favoriteVideosKey, jsonEncode(jsonList));
  }

  /// Get favorite videos
  Future<List<VideoModel>> getFavoriteVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_favoriteVideosKey);
      if (jsonString == null) return [];
      
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => VideoModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading favorite videos: $e');
      return [];
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(VideoModel video) async {
    final favorites = await getFavoriteVideos();
    final index = favorites.indexWhere((v) => v.path == video.path);
    
    if (index >= 0) {
      // Remove from favorites
      favorites.removeAt(index);
    } else {
      // Add to favorites
      favorites.add(video.copyWith(isFavorite: true));
    }
    
    await saveFavoriteVideos(favorites);
  }

  /// Check if video is favorite
  Future<bool> isFavorite(String videoPath) async {
    final favorites = await getFavoriteVideos();
    return favorites.any((video) => video.path == videoPath);
  }

  /// Save playback position
  Future<void> savePlaybackPosition(String videoPath, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    final positions = await getPlaybackPositions();
    positions[videoPath] = position.inMilliseconds;
    await prefs.setString(_playbackPositionsKey, jsonEncode(positions));
  }

  /// Get playback position
  Future<Duration?> getPlaybackPosition(String videoPath) async {
    final positions = await getPlaybackPositions();
    final milliseconds = positions[videoPath];
    return milliseconds != null ? Duration(milliseconds: milliseconds) : null;
  }

  /// Get all playback positions
  Future<Map<String, int>> getPlaybackPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_playbackPositionsKey);
      if (jsonString == null) return {};
      
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      print('Error loading playback positions: $e');
      return {};
    }
  }

  /// Save bookmarks
  Future<void> saveBookmarks(Map<String, List<Duration>> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, List<int>> serializable = {};
    
    bookmarks.forEach((videoPath, durations) {
      serializable[videoPath] = durations.map((d) => d.inMilliseconds).toList();
    });
    
    await prefs.setString(_bookmarksKey, jsonEncode(serializable));
  }

  /// Get bookmarks
  Future<Map<String, List<Duration>>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_bookmarksKey);
      if (jsonString == null) return {};
      
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final Map<String, List<Duration>> bookmarks = {};
      
      decoded.forEach((videoPath, durations) {
        final List<int> millisecondsList = List<int>.from(durations);
        bookmarks[videoPath] = millisecondsList
            .map((ms) => Duration(milliseconds: ms))
            .toList();
      });
      
      return bookmarks;
    } catch (e) {
      print('Error loading bookmarks: $e');
      return {};
    }
  }

  /// Add bookmark
  Future<void> addBookmark(String videoPath, Duration position) async {
    final bookmarks = await getBookmarks();
    if (!bookmarks.containsKey(videoPath)) {
      bookmarks[videoPath] = [];
    }
    
    // Avoid duplicate bookmarks (within 5 seconds)
    final existingBookmarks = bookmarks[videoPath]!;
    final isDuplicate = existingBookmarks.any((bookmark) {
      return (bookmark - position).abs() < const Duration(seconds: 5);
    });
    
    if (!isDuplicate) {
      existingBookmarks.add(position);
      existingBookmarks.sort();
      await saveBookmarks(bookmarks);
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(String videoPath, Duration position) async {
    final bookmarks = await getBookmarks();
    if (bookmarks.containsKey(videoPath)) {
      bookmarks[videoPath]!.removeWhere((bookmark) {
        return (bookmark - position).abs() < const Duration(seconds: 1);
      });
      
      if (bookmarks[videoPath]!.isEmpty) {
        bookmarks.remove(videoPath);
      }
      
      await saveBookmarks(bookmarks);
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentVideosKey);
    await prefs.remove(_favoriteVideosKey);
    await prefs.remove(_bookmarksKey);
    await prefs.remove(_playbackPositionsKey);
  }
}