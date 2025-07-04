import 'dart:async';
import 'package:flutter/services.dart';

/// Screen Orientation Manager for video playback
/// Implements NextPlayer's orientation control features
class ScreenOrientationManager {
  static const MethodChannel _channel = MethodChannel('screen_orientation_manager');
  
  // Orientation settings
  ScreenOrientation _orientation = ScreenOrientation.auto;
  bool _autoRotateEnabled = true;
  bool _rememberOrientationPerVideo = false;
  
  // Current state
  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;
  bool _isFullscreen = false;
  
  // Event streams
  final StreamController<DeviceOrientation> _orientationController = 
      StreamController<DeviceOrientation>.broadcast();
  final StreamController<bool> _fullscreenController = 
      StreamController<bool>.broadcast();
  
  Stream<DeviceOrientation> get orientationStream => _orientationController.stream;
  Stream<bool> get fullscreenStream => _fullscreenController.stream;
  
  // Getters
  ScreenOrientation get orientation => _orientation;
  bool get autoRotateEnabled => _autoRotateEnabled;
  bool get rememberOrientationPerVideo => _rememberOrientationPerVideo;
  DeviceOrientation get currentOrientation => _currentOrientation;
  bool get isFullscreen => _isFullscreen;
  
  ScreenOrientationManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onOrientationChanged':
        final orientationName = call.arguments['orientation'] as String;
        _currentOrientation = DeviceOrientation.values.firstWhere(
          (e) => e.name == orientationName,
          orElse: () => DeviceOrientation.portraitUp,
        );
        _orientationController.add(_currentOrientation);
        break;
      case 'onFullscreenChanged':
        _isFullscreen = call.arguments['isFullscreen'] as bool;
        _fullscreenController.add(_isFullscreen);
        break;
    }
  }
  
  /// Initialize orientation manager
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      throw Exception('Failed to initialize orientation manager: $e');
    }
  }
  
  /// Set screen orientation mode
  Future<void> setOrientation(ScreenOrientation orientation) async {
    try {
      await _channel.invokeMethod('setOrientation', {'orientation': orientation.name});
      _orientation = orientation;
      
      // Apply orientation immediately
      await _applyOrientation();
    } catch (e) {
      throw Exception('Failed to set orientation: $e');
    }
  }
  
  /// Set auto rotate enabled
  Future<void> setAutoRotateEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoRotateEnabled', {'enabled': enabled});
      _autoRotateEnabled = enabled;
    } catch (e) {
      throw Exception('Failed to set auto rotate: $e');
    }
  }
  
  /// Set remember orientation per video
  Future<void> setRememberOrientationPerVideo(bool remember) async {
    try {
      await _channel.invokeMethod('setRememberOrientationPerVideo', {'remember': remember});
      _rememberOrientationPerVideo = remember;
    } catch (e) {
      throw Exception('Failed to set remember orientation: $e');
    }
  }
  
  /// Enter fullscreen mode
  Future<void> enterFullscreen() async {
    try {
      await _channel.invokeMethod('enterFullscreen');
      _isFullscreen = true;
      _fullscreenController.add(_isFullscreen);
    } catch (e) {
      throw Exception('Failed to enter fullscreen: $e');
    }
  }
  
  /// Exit fullscreen mode
  Future<void> exitFullscreen() async {
    try {
      await _channel.invokeMethod('exitFullscreen');
      _isFullscreen = false;
      _fullscreenController.add(_isFullscreen);
    } catch (e) {
      throw Exception('Failed to exit fullscreen: $e');
    }
  }
  
  /// Toggle fullscreen mode
  Future<void> toggleFullscreen() async {
    if (_isFullscreen) {
      await exitFullscreen();
    } else {
      await enterFullscreen();
    }
  }
  
  /// Rotate to landscape
  Future<void> rotateLandscape() async {
    try {
      await _channel.invokeMethod('rotateLandscape');
    } catch (e) {
      throw Exception('Failed to rotate to landscape: $e');
    }
  }
  
  /// Rotate to portrait
  Future<void> rotatePortrait() async {
    try {
      await _channel.invokeMethod('rotatePortrait');
    } catch (e) {
      throw Exception('Failed to rotate to portrait: $e');
    }
  }
  
  /// Lock current orientation
  Future<void> lockCurrentOrientation() async {
    try {
      await _channel.invokeMethod('lockCurrentOrientation');
    } catch (e) {
      throw Exception('Failed to lock orientation: $e');
    }
  }
  
  /// Unlock orientation
  Future<void> unlockOrientation() async {
    try {
      await _channel.invokeMethod('unlockOrientation');
    } catch (e) {
      throw Exception('Failed to unlock orientation: $e');
    }
  }
  
  /// Apply current orientation setting
  Future<void> _applyOrientation() async {
    switch (_orientation) {
      case ScreenOrientation.auto:
        await unlockOrientation();
        break;
      case ScreenOrientation.portrait:
        await rotatePortrait();
        break;
      case ScreenOrientation.landscape:
        await rotateLandscape();
        break;
      case ScreenOrientation.locked:
        await lockCurrentOrientation();
        break;
    }
  }
  
  /// Get orientation for video dimensions
  ScreenOrientation getOrientationForVideo(double width, double height) {
    if (_orientation == ScreenOrientation.auto) {
      return width > height ? ScreenOrientation.landscape : ScreenOrientation.portrait;
    }
    return _orientation;
  }
  
  void dispose() {
    _orientationController.close();
    _fullscreenController.close();
  }
}

/// Screen Orientation enum
enum ScreenOrientation {
  auto,
  portrait,
  landscape,
  locked;
  
  String get name => toString().split('.').last;
}

extension DeviceOrientationExtension on DeviceOrientation {
  String get name => toString().split('.').last;
}