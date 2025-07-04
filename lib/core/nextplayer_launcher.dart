import 'package:flutter/services.dart';
import 'dart:io';

/// Service to launch the actual NextPlayer app for video playback
class NextPlayerLauncher {
  static const MethodChannel _channel = MethodChannel('nextplayer_launcher');
  
  /// Launch NextPlayer app with the given video path
  static Future<bool> launchVideo(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('launchVideo', {
        'videoPath': videoPath,
      });
      return result == true;
    } catch (e) {
      print('Failed to launch NextPlayer: $e');
      return false;
    }
  }
  
  /// Check if NextPlayer app is installed
  static Future<bool> isNextPlayerInstalled() async {
    try {
      final result = await _channel.invokeMethod('isNextPlayerInstalled');
      return result == true;
    } catch (e) {
      print('Failed to check NextPlayer installation: $e');
      return false;
    }
  }
  
  /// Install NextPlayer app (if APK is available)
  static Future<bool> installNextPlayer() async {
    try {
      final result = await _channel.invokeMethod('installNextPlayer');
      return result == true;
    } catch (e) {
      print('Failed to install NextPlayer: $e');
      return false;
    }
  }
  
  /// Launch NextPlayer app directly (without specific video)
  static Future<bool> launchNextPlayerApp() async {
    try {
      final result = await _channel.invokeMethod('launchNextPlayerApp');
      return result == true;
    } catch (e) {
      print('Failed to launch NextPlayer app: $e');
      return false;
    }
  }
}