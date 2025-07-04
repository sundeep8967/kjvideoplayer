import 'package:flutter/services.dart';

/// Simple Screen Orientation Manager for video playback
class SimpleScreenOrientationManager {
  
  /// Set preferred orientations for video playback (landscape)
  static Future<void> setVideoPlaybackOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  /// Restore default orientations (portrait)
  static Future<void> restoreDefaultOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
  /// Set fullscreen mode
  static Future<void> setFullscreen(bool fullscreen) async {
    if (fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
  
  /// Allow all orientations
  static Future<void> allowAllOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}