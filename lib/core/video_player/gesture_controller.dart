import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gesture Controller for advanced video player gestures
/// Implements NextPlayer's gesture system (swipe, pinch, double-tap, long-press)
class GestureController {
  static const MethodChannel _channel = MethodChannel('gesture_controller');
  
  // Gesture settings
  bool _useSwipeControls = true;
  bool _useSeekControls = true;
  bool _useZoomControls = true;
  bool _useLongPressControls = false;
  double _longPressControlsSpeed = 2.0;
  DoubleTapGesture _doubleTapGesture = DoubleTapGesture.both;
  
  // Gesture state
  bool _isGestureActive = false;
  GestureType _currentGestureType = GestureType.none;
  double _gestureValue = 0.0;
  String _gestureText = '';
  
  // Brightness and volume
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  double _currentZoom = 1.0;
  
  // Seek settings
  int _seekIncrement = 10; // seconds
  Duration _minDurationForFastSeek = const Duration(minutes: 2);
  
  // Event streams
  final StreamController<GestureEvent> _gestureEventController = 
      StreamController<GestureEvent>.broadcast();
  final StreamController<double> _brightnessController = 
      StreamController<double>.broadcast();
  final StreamController<double> _volumeController = 
      StreamController<double>.broadcast();
  final StreamController<double> _zoomController = 
      StreamController<double>.broadcast();
  
  // Streams
  Stream<GestureEvent> get gestureEvents => _gestureEventController.stream;
  Stream<double> get brightnessStream => _brightnessController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<double> get zoomStream => _zoomController.stream;
  
  // Getters
  bool get useSwipeControls => _useSwipeControls;
  bool get useSeekControls => _useSeekControls;
  bool get useZoomControls => _useZoomControls;
  bool get useLongPressControls => _useLongPressControls;
  double get longPressControlsSpeed => _longPressControlsSpeed;
  DoubleTapGesture get doubleTapGesture => _doubleTapGesture;
  bool get isGestureActive => _isGestureActive;
  GestureType get currentGestureType => _currentGestureType;
  double get gestureValue => _gestureValue;
  String get gestureText => _gestureText;
  double get currentBrightness => _currentBrightness;
  double get currentVolume => _currentVolume;
  double get currentZoom => _currentZoom;
  int get seekIncrement => _seekIncrement;
  
  GestureController() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBrightnessChanged':
        _currentBrightness = call.arguments['brightness'] as double;
        _brightnessController.add(_currentBrightness);
        break;
      case 'onVolumeChanged':
        _currentVolume = call.arguments['volume'] as double;
        _volumeController.add(_currentVolume);
        break;
      case 'onZoomChanged':
        _currentZoom = call.arguments['zoom'] as double;
        _zoomController.add(_currentZoom);
        break;
    }
  }
  
  /// Initialize gesture controller
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize', {
        'useSwipeControls': _useSwipeControls,
        'useSeekControls': _useSeekControls,
        'useZoomControls': _useZoomControls,
        'useLongPressControls': _useLongPressControls,
        'longPressControlsSpeed': _longPressControlsSpeed,
        'doubleTapGesture': _doubleTapGesture.name,
        'seekIncrement': _seekIncrement,
      });
    } catch (e) {
      throw Exception('Failed to initialize gesture controller: $e');
    }
  }
  
  /// Set gesture controls enabled/disabled
  Future<void> setGestureControlsEnabled({
    bool? swipeControls,
    bool? seekControls,
    bool? zoomControls,
    bool? longPressControls,
  }) async {
    try {
      await _channel.invokeMethod('setGestureControls', {
        'swipeControls': swipeControls ?? _useSwipeControls,
        'seekControls': seekControls ?? _useSeekControls,
        'zoomControls': zoomControls ?? _useZoomControls,
        'longPressControls': longPressControls ?? _useLongPressControls,
      });
      
      if (swipeControls != null) _useSwipeControls = swipeControls;
      if (seekControls != null) _useSeekControls = seekControls;
      if (zoomControls != null) _useZoomControls = zoomControls;
      if (longPressControls != null) _useLongPressControls = longPressControls;
    } catch (e) {
      throw Exception('Failed to set gesture controls: $e');
    }
  }
  
  /// Set double tap gesture behavior
  Future<void> setDoubleTapGesture(DoubleTapGesture gesture) async {
    try {
      await _channel.invokeMethod('setDoubleTapGesture', {'gesture': gesture.name});
      _doubleTapGesture = gesture;
    } catch (e) {
      throw Exception('Failed to set double tap gesture: $e');
    }
  }
  
  /// Set long press speed
  Future<void> setLongPressSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setLongPressSpeed', {'speed': speed});
      _longPressControlsSpeed = speed;
    } catch (e) {
      throw Exception('Failed to set long press speed: $e');
    }
  }
  
  /// Set seek increment
  Future<void> setSeekIncrement(int seconds) async {
    try {
      await _channel.invokeMethod('setSeekIncrement', {'seconds': seconds});
      _seekIncrement = seconds;
    } catch (e) {
      throw Exception('Failed to set seek increment: $e');
    }
  }
  
  /// Handle horizontal swipe for seeking
  void handleHorizontalSwipe(double deltaX, Size screenSize, Duration videoDuration) {
    if (!_useSeekControls) return;
    
    _isGestureActive = true;
    _currentGestureType = GestureType.seek;
    
    // Calculate seek amount based on swipe distance
    final seekPercentage = deltaX / screenSize.width;
    final seekAmount = seekPercentage * videoDuration.inSeconds;
    
    _gestureValue = seekAmount;
    _gestureText = _formatSeekText(seekAmount);
    
    _gestureEventController.add(GestureEvent(
      type: GestureType.seek,
      value: seekAmount,
      text: _gestureText,
    ));
  }
  
  /// Handle vertical swipe for brightness (left side) or volume (right side)
  void handleVerticalSwipe(double deltaY, double positionX, Size screenSize) {
    if (!_useSwipeControls) return;
    
    _isGestureActive = true;
    final isLeftSide = positionX < screenSize.width / 2;
    
    if (isLeftSide) {
      // Brightness control
      _currentGestureType = GestureType.brightness;
      final brightnessChange = -deltaY / screenSize.height;
      _currentBrightness = (_currentBrightness + brightnessChange).clamp(0.0, 1.0);
      
      _gestureValue = _currentBrightness;
      _gestureText = '${(_currentBrightness * 100).round()}%';
      
      _brightnessController.add(_currentBrightness);
      _gestureEventController.add(GestureEvent(
        type: GestureType.brightness,
        value: _currentBrightness,
        text: _gestureText,
      ));
    } else {
      // Volume control
      _currentGestureType = GestureType.volume;
      final volumeChange = -deltaY / screenSize.height;
      _currentVolume = (_currentVolume + volumeChange).clamp(0.0, 1.0);
      
      _gestureValue = _currentVolume;
      _gestureText = '${(_currentVolume * 100).round()}%';
      
      _volumeController.add(_currentVolume);
      _gestureEventController.add(GestureEvent(
        type: GestureType.volume,
        value: _currentVolume,
        text: _gestureText,
      ));
    }
  }
  
  /// Handle pinch gesture for zoom
  void handlePinchGesture(double scale) {
    if (!_useZoomControls) return;
    
    _isGestureActive = true;
    _currentGestureType = GestureType.zoom;
    
    _currentZoom = (scale).clamp(0.5, 3.0);
    _gestureValue = _currentZoom;
    _gestureText = '${(_currentZoom * 100).round()}%';
    
    _zoomController.add(_currentZoom);
    _gestureEventController.add(GestureEvent(
      type: GestureType.zoom,
      value: _currentZoom,
      text: _gestureText,
    ));
  }
  
  /// Handle double tap gesture
  void handleDoubleTap(Offset position, Size screenSize, Function() onPlayPause, 
                      Function(int) onSeek) {
    if (_doubleTapGesture == DoubleTapGesture.disabled) return;
    
    final isLeftSide = position.dx < screenSize.width / 3;
    final isRightSide = position.dx > screenSize.width * 2 / 3;
    
    switch (_doubleTapGesture) {
      case DoubleTapGesture.playPause:
        onPlayPause();
        break;
      case DoubleTapGesture.seek:
        if (isLeftSide) {
          onSeek(-_seekIncrement);
        } else if (isRightSide) {
          onSeek(_seekIncrement);
        } else {
          onPlayPause();
        }
        break;
      case DoubleTapGesture.both:
        if (isLeftSide) {
          onSeek(-_seekIncrement);
        } else if (isRightSide) {
          onSeek(_seekIncrement);
        } else {
          onPlayPause();
        }
        break;
      case DoubleTapGesture.disabled:
        break;
    }
    
    _gestureEventController.add(GestureEvent(
      type: GestureType.doubleTap,
      value: 0,
      text: '',
    ));
  }
  
  /// Handle long press gesture
  void handleLongPress(bool isPressed, Function(double) onSpeedChange) {
    if (!_useLongPressControls) return;
    
    if (isPressed) {
      _isGestureActive = true;
      _currentGestureType = GestureType.longPress;
      onSpeedChange(_longPressControlsSpeed);
      
      _gestureEventController.add(GestureEvent(
        type: GestureType.longPress,
        value: _longPressControlsSpeed,
        text: '${_longPressControlsSpeed}x',
      ));
    } else {
      onSpeedChange(1.0);
      _endGesture();
    }
  }
  
  /// End current gesture
  void endGesture() {
    _endGesture();
  }
  
  void _endGesture() {
    _isGestureActive = false;
    _currentGestureType = GestureType.none;
    _gestureValue = 0.0;
    _gestureText = '';
    
    _gestureEventController.add(GestureEvent(
      type: GestureType.none,
      value: 0,
      text: '',
    ));
  }
  
  String _formatSeekText(double seconds) {
    final absSeconds = seconds.abs().round();
    final sign = seconds >= 0 ? '+' : '-';
    final minutes = absSeconds ~/ 60;
    final remainingSeconds = absSeconds % 60;
    
    if (minutes > 0) {
      return '$sign${minutes}m ${remainingSeconds}s';
    } else {
      return '$sign${remainingSeconds}s';
    }
  }
  
  /// Apply brightness to system
  Future<void> applyBrightness(double brightness) async {
    try {
      await _channel.invokeMethod('applyBrightness', {'brightness': brightness});
      _currentBrightness = brightness;
    } catch (e) {
      throw Exception('Failed to apply brightness: $e');
    }
  }
  
  /// Apply volume to system
  Future<void> applyVolume(double volume) async {
    try {
      await _channel.invokeMethod('applyVolume', {'volume': volume});
      _currentVolume = volume;
    } catch (e) {
      throw Exception('Failed to apply volume: $e');
    }
  }
  
  /// Apply zoom to video
  Future<void> applyZoom(double zoom) async {
    try {
      await _channel.invokeMethod('applyZoom', {'zoom': zoom});
      _currentZoom = zoom;
    } catch (e) {
      throw Exception('Failed to apply zoom: $e');
    }
  }
  
  void dispose() {
    _gestureEventController.close();
    _brightnessController.close();
    _volumeController.close();
    _zoomController.close();
  }
}

/// Gesture Types
enum GestureType {
  none,
  seek,
  brightness,
  volume,
  zoom,
  doubleTap,
  longPress,
}

/// Double Tap Gesture Options
enum DoubleTapGesture {
  disabled,
  playPause,
  seek,
  both;
  
  String get name => toString().split('.').last;
}

/// Gesture Event
class GestureEvent {
  final GestureType type;
  final double value;
  final String text;
  
  const GestureEvent({
    required this.type,
    required this.value,
    required this.text,
  });
  
  @override
  String toString() => 'GestureEvent(type: $type, value: $value, text: $text)';
}