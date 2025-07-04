import 'dart:io';
import 'package:flutter/services.dart';

/// NextPlayerLauncher - Platform channel for launching NextPlayer
/// Currently using Flutter's video_player plugin for cross-platform compatibility
class NextPlayerLauncher {
  static const MethodChannel _channel = MethodChannel('com.sundeep.kjvideoplayer/nextplayer');

  static Future<void> launch(String videoPath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('launchNextPlayer', {'videoPath': videoPath});
      } catch (e) {
        // Fallback to system video player if NextPlayer is not available
        throw UnsupportedError('NextPlayer not available: $e');
      }
    } else {
      throw UnsupportedError('NextPlayer is only available on Android');
    }
  }
}
