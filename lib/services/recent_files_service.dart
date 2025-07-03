import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_file.dart';

class RecentFilesService {
  static const String _recentFilesKey = 'recent_video_files';
  static const int _maxRecentFiles = 20;
  
  static Future<List<String>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final recentFilesJson = prefs.getStringList(_recentFilesKey) ?? [];
    return recentFilesJson;
  }
  
  static Future<void> addRecentFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentFiles = prefs.getStringList(_recentFilesKey) ?? [];
    
    // Remove if already exists
    recentFiles.remove(filePath);
    
    // Add to beginning
    recentFiles.insert(0, filePath);
    
    // Keep only max recent files
    if (recentFiles.length > _maxRecentFiles) {
      recentFiles = recentFiles.take(_maxRecentFiles).toList();
    }
    
    await prefs.setStringList(_recentFilesKey, recentFiles);
  }
  
  static Future<void> removeRecentFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentFiles = prefs.getStringList(_recentFilesKey) ?? [];
    recentFiles.remove(filePath);
    await prefs.setStringList(_recentFilesKey, recentFiles);
  }
  
  static Future<void> clearRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentFilesKey);
  }
}