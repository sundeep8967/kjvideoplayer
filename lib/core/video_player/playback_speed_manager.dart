import 'dart:async';
import 'package:flutter/services.dart';

/// Playback Speed Manager for advanced speed controls
/// Implements NextPlayer's playback speed and fast seek features
class PlaybackSpeedManager {
  static const MethodChannel _channel = MethodChannel('playback_speed_manager');
  
  // Speed settings
  double _currentSpeed = 1.0;
  List<double> _availableSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  bool _rememberSpeed = false;
  
  // Fast seek settings
  FastSeek _fastSeek = FastSeek.auto;
  Duration _fastSeekThreshold = const Duration(minutes: 2);
  
  // Long press speed
  double _longPressSpeed = 2.0;
  bool _isLongPressActive = false;
  
  // Event streams
  final StreamController<double> _speedController = 
      StreamController<double>.broadcast();
  final StreamController<FastSeekEvent> _fastSeekController = 
      StreamController<FastSeekEvent>.broadcast();
  
  Stream<double> get speedStream => _speedController.stream;
  Stream<FastSeekEvent> get fastSeekStream => _fastSeekController.stream;
  
  // Getters
  double get currentSpeed => _currentSpeed;
  List<double> get availableSpeeds => List.unmodifiable(_availableSpeeds);
  bool get rememberSpeed => _rememberSpeed;
  FastSeek get fastSeek => _fastSeek;
  Duration get fastSeekThreshold => _fastSeekThreshold;
  double get longPressSpeed => _longPressSpeed;
  bool get isLongPressActive => _isLongPressActive;
  
  PlaybackSpeedManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSpeedChanged':
        _currentSpeed = call.arguments['speed'] as double;
        _speedController.add(_currentSpeed);
        break;
      case 'onLongPressSpeedActivated':
        _isLongPressActive = call.arguments['active'] as bool;
        if (_isLongPressActive) {
          await setSpeed(_longPressSpeed);
        } else {
          await restoreNormalSpeed();
        }
        break;
      case 'onFastSeekEvent':
        final event = FastSeekEvent.fromMap(call.arguments);
        _fastSeekController.add(event);
        break;
    }
  }
  
  /// Initialize playback speed manager
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      throw Exception('Failed to initialize playback speed manager: $e');
    }
  }
  
  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setSpeed', {'speed': speed});
      _currentSpeed = speed;
      _speedController.add(_currentSpeed);
    } catch (e) {
      throw Exception('Failed to set playback speed: $e');
    }
  }
  
  /// Increase speed to next available speed
  Future<void> increaseSpeed() async {
    final currentIndex = _availableSpeeds.indexOf(_currentSpeed);
    if (currentIndex < _availableSpeeds.length - 1) {
      await setSpeed(_availableSpeeds[currentIndex + 1]);
    }
  }
  
  /// Decrease speed to previous available speed
  Future<void> decreaseSpeed() async {
    final currentIndex = _availableSpeeds.indexOf(_currentSpeed);
    if (currentIndex > 0) {
      await setSpeed(_availableSpeeds[currentIndex - 1]);
    }
  }
  
  /// Reset speed to normal (1.0x)
  Future<void> resetSpeed() async {
    await setSpeed(1.0);
  }
  
  /// Set custom available speeds
  Future<void> setAvailableSpeeds(List<double> speeds) async {
    try {
      await _channel.invokeMethod('setAvailableSpeeds', {'speeds': speeds});
      _availableSpeeds = List.from(speeds);
    } catch (e) {
      throw Exception('Failed to set available speeds: $e');
    }
  }
  
  /// Set remember speed setting
  Future<void> setRememberSpeed(bool remember) async {
    try {
      await _channel.invokeMethod('setRememberSpeed', {'remember': remember});
      _rememberSpeed = remember;
    } catch (e) {
      throw Exception('Failed to set remember speed: $e');
    }
  }
  
  /// Set fast seek mode
  Future<void> setFastSeek(FastSeek mode) async {
    try {
      await _channel.invokeMethod('setFastSeek', {'mode': mode.name});
      _fastSeek = mode;
    } catch (e) {
      throw Exception('Failed to set fast seek: $e');
    }
  }
  
  /// Set fast seek threshold
  Future<void> setFastSeekThreshold(Duration threshold) async {
    try {
      await _channel.invokeMethod('setFastSeekThreshold', {
        'thresholdMs': threshold.inMilliseconds
      });
      _fastSeekThreshold = threshold;
    } catch (e) {
      throw Exception('Failed to set fast seek threshold: $e');
    }
  }
  
  /// Set long press speed
  Future<void> setLongPressSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setLongPressSpeed', {'speed': speed});
      _longPressSpeed = speed;
    } catch (e) {
      throw Exception('Failed to set long press speed: $e');
    }
  }
  
  /// Activate long press speed
  Future<void> activateLongPressSpeed() async {
    try {
      await _channel.invokeMethod('activateLongPressSpeed');
      _isLongPressActive = true;
    } catch (e) {
      throw Exception('Failed to activate long press speed: $e');
    }
  }
  
  /// Deactivate long press speed
  Future<void> deactivateLongPressSpeed() async {
    try {
      await _channel.invokeMethod('deactivateLongPressSpeed');
      _isLongPressActive = false;
    } catch (e) {
      throw Exception('Failed to deactivate long press speed: $e');
    }
  }
  
  /// Restore normal speed after long press
  Future<void> restoreNormalSpeed() async {
    if (_isLongPressActive) {
      await setSpeed(1.0);
      _isLongPressActive = false;
    }
  }
  
  /// Check if fast seek should be used for duration
  bool shouldUseFastSeek(Duration videoDuration) {
    switch (_fastSeek) {
      case FastSeek.disable:
        return false;
      case FastSeek.enable:
        return true;
      case FastSeek.auto:
        return videoDuration >= _fastSeekThreshold;
    }
  }
  
  void dispose() {
    _speedController.close();
    _fastSeekController.close();
  }
}

/// Fast Seek enum
enum FastSeek {
  disable,
  enable,
  auto;
  
  String get name => toString().split('.').last;
}

/// Fast Seek Event
class FastSeekEvent {
  final FastSeekEventType type;
  final Duration position;
  final Duration targetPosition;
  final bool isActive;
  
  const FastSeekEvent({
    required this.type,
    required this.position,
    required this.targetPosition,
    required this.isActive,
  });
  
  factory FastSeekEvent.fromMap(Map<String, dynamic> map) {
    return FastSeekEvent(
      type: FastSeekEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FastSeekEventType.seek,
      ),
      position: Duration(milliseconds: map['position'] ?? 0),
      targetPosition: Duration(milliseconds: map['targetPosition'] ?? 0),
      isActive: map['isActive'] ?? false,
    );
  }
  
  @override
  String toString() {
    return 'FastSeekEvent(type: $type, position: $position, '
           'targetPosition: $targetPosition, isActive: $isActive)';
  }
}

/// Fast Seek Event Types
enum FastSeekEventType {
  seek,
  start,
  end,
}