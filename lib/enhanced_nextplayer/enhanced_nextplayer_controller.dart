import 'dart:async';
import 'package:flutter/services.dart';
import '../core/video_player/nextplayer_integration_manager.dart';

/// Enhanced NextPlayer Controller with advanced features
/// Utilizes NextPlayer's full feature set including gestures, PiP, and advanced controls
class EnhancedNextPlayerController {
  static const MethodChannel _channel = MethodChannel('enhanced_nextplayer');
  
  // Integration manager
  late final NextPlayerIntegrationManager _integrationManager;
  
  // Event streams
  final StreamController<NextPlayerEvent> _eventController = StreamController<NextPlayerEvent>.broadcast();
  final StreamController<NextPlayerState> _stateController = StreamController<NextPlayerState>.broadcast();
  
  // Current state
  NextPlayerState _currentState = NextPlayerState.idle;
  MethodChannel? _methodChannel;
  
  // Player properties
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  VideoZoom _videoZoom = VideoZoom.bestFit;
  bool _isInitialized = false;
  
  // Initialize integration manager
  EnhancedNextPlayerController() {
    _integrationManager = NextPlayerIntegrationManager();
    _setupIntegrationListeners();
    _setupMethodCallHandler();
  }
  
  // Initialize the plugin (call this before using the player)
  Future<Map<String, dynamic>> initializePlugin() async {
    try {
      final result = await _channel.invokeMethod('initialize');
      _isInitialized = true;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Failed to initialize Enhanced NextPlayer plugin: $e');
      rethrow;
    }
  }
  
  void _setupIntegrationListeners() {
    _integrationManager.events.listen((event) {
      switch (event.type) {
        case NextPlayerEventType.gesture:
          final gestureEvent = event.data['gestureEvent'];
          _eventController.add(_mapGestureEvent(gestureEvent));
          break;
        case NextPlayerEventType.speedChanged:
          _eventController.add(NextPlayerEvent.playbackSpeedChanged);
          break;
        case NextPlayerEventType.orientationChanged:
          _eventController.add(NextPlayerEvent.orientationChanged);
          break;
        case NextPlayerEventType.error:
          _currentState = NextPlayerState.error;
          _stateController.add(_currentState);
          _eventController.add(NextPlayerEvent.error);
          break;
        default:
          break;
      }
    });
  }
  
  NextPlayerEvent _mapGestureEvent(dynamic gestureEvent) {
    final type = gestureEvent?.type?.toString() ?? '';
    switch (type) {
      case 'GestureType.volume':
        return NextPlayerEvent.volumeGesture;
      case 'GestureType.brightness':
        return NextPlayerEvent.brightnessGesture;
      case 'GestureType.seek':
        return NextPlayerEvent.seekGesture;
      case 'GestureType.zoom':
        return NextPlayerEvent.zoomGesture;
      default:
        return NextPlayerEvent.gestureDetected;
    }
  }
  
  void _setMethodChannel(MethodChannel channel) {
    _methodChannel = channel;
    _methodChannel?.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onInitialized':
        _currentState = NextPlayerState.ready;
        _stateController.add(_currentState);
        _eventController.add(NextPlayerEvent.initialized);
        break;
      case 'onPlaybackStateChanged':
        final state = call.arguments['state'] as int;
        _updatePlaybackState(state);
        break;
      case 'onIsPlayingChanged':
        final isPlaying = call.arguments['isPlaying'] as bool;
        _currentState = isPlaying ? NextPlayerState.playing : NextPlayerState.paused;
        _stateController.add(_currentState);
        break;
      case 'onVideoSizeChanged':
        final width = call.arguments['width'] as int;
        final height = call.arguments['height'] as int;
        _eventController.add(NextPlayerEvent.initialized);
        break;
      case 'onPlaybackSpeedChanged':
        final speed = call.arguments['speed'] as double;
        _playbackSpeed = speed;
        _eventController.add(NextPlayerEvent.playbackSpeedChanged);
        break;
      case 'onError':
        final error = call.arguments['error'] as String;
        _eventController.add(NextPlayerEvent.error);
        break;
    }
  }
  
  void _updatePlaybackState(int state) {
    switch (state) {
      case 1: // STATE_IDLE
        _currentState = NextPlayerState.idle;
        break;
      case 2: // STATE_BUFFERING
        _currentState = NextPlayerState.loading;
        break;
      case 3: // STATE_READY
        _currentState = NextPlayerState.ready;
        break;
      case 4: // STATE_ENDED
        _currentState = NextPlayerState.stopped;
        break;
    }
    _stateController.add(_currentState);
  }
  
  // Getters
  Stream<NextPlayerEvent> get events => _eventController.stream;
  Stream<NextPlayerState> get stateStream => _stateController.stream;
  NextPlayerState get state => _currentState;
  Duration get duration => _duration;
  Duration get position => _position;
  
  // Basic playback controls
  Future<void> play() async {
    await _channel.invokeMethod('play');
  }
  
  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }
  
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
  
  Future<void> seekTo(Duration position) async {
    await _channel.invokeMethod('seekTo', {
      'position': position.inMilliseconds,
    });
  }
  
  // Seek relative to current position
  Future<void> seekRelative(Duration offset) async {
    final newPosition = position + offset;
    await seekTo(newPosition);
  }
  
  // Switch audio track
  Future<void> switchAudioTrack(int trackIndex) async {
    await _channel.invokeMethod('switchAudioTrack', {
      'trackIndex': trackIndex,
    });
  }
  
  // Switch subtitle track
  Future<void> switchSubtitleTrack(int trackIndex) async {
    await _channel.invokeMethod('switchSubtitleTrack', {
      'trackIndex': trackIndex,
    });
  }
  
  // Picture-in-Picture support
  Future<void> enterPictureInPicture() async {
    await _channel.invokeMethod('enterPictureInPicture');
  }
  double get playbackSpeed => _playbackSpeed;
  double get volume => _volume;
  VideoZoom get videoZoom => _videoZoom;
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _currentState == NextPlayerState.playing;
  bool get isPaused => _currentState == NextPlayerState.paused;
  
  
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onInitialized':
          _isInitialized = true;
          _duration = Duration(milliseconds: call.arguments['duration'] ?? 0);
          _eventController.add(NextPlayerEvent.initialized);
          break;
          
        case 'onStateChanged':
          final stateString = call.arguments['state'] as String;
          _currentState = NextPlayerState.values.firstWhere(
            (e) => e.toString().split('.').last == stateString,
            orElse: () => NextPlayerState.idle,
          );
          _stateController.add(_currentState);
          break;
          
        case 'onPositionChanged':
          _position = Duration(milliseconds: call.arguments['position'] ?? 0);
          _eventController.add(NextPlayerEvent.positionChanged);
          break;
          
        case 'onPlaybackSpeedChanged':
          _playbackSpeed = (call.arguments['speed'] ?? 1.0).toDouble();
          _eventController.add(NextPlayerEvent.playbackSpeedChanged);
          break;
          
        case 'onVolumeChanged':
          _volume = (call.arguments['volume'] ?? 1.0).toDouble();
          _eventController.add(NextPlayerEvent.volumeChanged);
          break;
          
        case 'onVideoZoomChanged':
          final zoomString = call.arguments['zoom'] as String;
          _videoZoom = VideoZoom.values.firstWhere(
            (e) => e.toString().split('.').last == zoomString,
            orElse: () => VideoZoom.bestFit,
          );
          _eventController.add(NextPlayerEvent.videoZoomChanged);
          break;
          
        case 'onError':
          final error = call.arguments['error'] as String;
          _eventController.add(NextPlayerEvent.error);
          break;
          
        case 'onGestureDetected':
          final gestureType = call.arguments['type'] as String;
          final value = call.arguments['value'];
          _handleGestureEvent(gestureType, value);
          break;
      }
    });
  }
  
  void _handleGestureEvent(String gestureType, dynamic value) {
    switch (gestureType) {
      case 'volume':
        _volume = (value ?? 1.0).toDouble();
        _eventController.add(NextPlayerEvent.volumeGesture);
        break;
      case 'brightness':
        _eventController.add(NextPlayerEvent.brightnessGesture);
        break;
      case 'seek':
        _position = Duration(milliseconds: value ?? 0);
        _eventController.add(NextPlayerEvent.seekGesture);
        break;
      case 'zoom':
        _eventController.add(NextPlayerEvent.zoomGesture);
        break;
    }
  }
  
  // Basic Controls
  Future<void> initialize(String videoPath, {String? title}) async {
    await _channel.invokeMethod('initialize', {
      'videoPath': videoPath,
      'title': title,
    });
  }
  
  // Advanced Controls
  Future<void> setPlaybackSpeed(double speed) async {
    await _channel.invokeMethod('setPlaybackSpeed', {
      'speed': speed,
    });
  }
  
  Future<void> setVolume(double volume) async {
    await _channel.invokeMethod('setVolume', {
      'volume': volume.clamp(0.0, 1.0),
    });
  }
  
  Future<void> setBrightness(double brightness) async {
    await _channel.invokeMethod('setBrightness', {
      'brightness': brightness.clamp(0.0, 1.0),
    });
  }
  
  Future<void> setVideoZoom(VideoZoom zoom) async {
    await _channel.invokeMethod('setVideoZoom', {
      'zoom': zoom.toString().split('.').last,
    });
  }
  
  // Gesture Controls
  Future<void> enableGestures(bool enabled) async {
    await _channel.invokeMethod('enableGestures', {
      'enabled': enabled,
    });
  }
  
  Future<void> enableVolumeGesture(bool enabled) async {
    await _channel.invokeMethod('enableVolumeGesture', {
      'enabled': enabled,
    });
  }
  
  Future<void> enableBrightnessGesture(bool enabled) async {
    await _channel.invokeMethod('enableBrightnessGesture', {
      'enabled': enabled,
    });
  }
  
  Future<void> enableSeekGesture(bool enabled) async {
    await _channel.invokeMethod('enableSeekGesture', {
      'enabled': enabled,
    });
  }
  
  Future<void> enableZoomGesture(bool enabled) async {
    await _channel.invokeMethod('enableZoomGesture', {
      'enabled': enabled,
    });
  }
  
  // Advanced Features
  
  Future<void> exitPictureInPicture() async {
    await _channel.invokeMethod('exitPictureInPicture');
  }
  
  Future<void> enableBackgroundPlayback(bool enabled) async {
    await _channel.invokeMethod('enableBackgroundPlayback', {
      'enabled': enabled,
    });
  }
  
  // Track Selection
  Future<List<AudioTrack>> getAudioTracks() async {
    final result = await _channel.invokeMethod('getAudioTracks');
    return (result as List).map((track) => AudioTrack.fromMap(track)).toList();
  }
  
  Future<List<SubtitleTrack>> getSubtitleTracks() async {
    final result = await _channel.invokeMethod('getSubtitleTracks');
    return (result as List).map((track) => SubtitleTrack.fromMap(track)).toList();
  }
  
  Future<void> selectAudioTrack(int trackIndex) async {
    await _channel.invokeMethod('selectAudioTrack', {
      'trackIndex': trackIndex,
    });
  }
  
  Future<void> selectSubtitleTrack(int trackIndex) async {
    await _channel.invokeMethod('selectSubtitleTrack', {
      'trackIndex': trackIndex,
    });
  }
  
  Future<void> addExternalSubtitle(String subtitlePath) async {
    await _channel.invokeMethod('addExternalSubtitle', {
      'subtitlePath': subtitlePath,
    });
  }
  
  // Loop Mode
  Future<void> setLoopMode(LoopMode mode) async {
    await _channel.invokeMethod('setLoopMode', {
      'mode': mode.toString().split('.').last,
    });
  }
  
  // Decoder Settings
  Future<void> setDecoderPriority(DecoderPriority priority) async {
    await _channel.invokeMethod('setDecoderPriority', {
      'priority': priority.toString().split('.').last,
    });
  }
  
  // UI Controls
  Future<void> showInfo(String text, {String? subText}) async {
    await _channel.invokeMethod('showInfo', {
      'text': text,
      'subText': subText,
    });
  }
  
  Future<void> showTopInfo(String text) async {
    await _channel.invokeMethod('showTopInfo', {
      'text': text,
    });
  }
  
  Future<void> hideInfo() async {
    await _channel.invokeMethod('hideInfo');
  }
  
  Future<void> showVolumeIndicator(bool show) async {
    await _channel.invokeMethod('showVolumeIndicator', {
      'show': show,
    });
  }
  
  Future<void> showBrightnessIndicator(bool show) async {
    await _channel.invokeMethod('showBrightnessIndicator', {
      'show': show,
    });
  }
  
  // Cleanup
  Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
    await _eventController.close();
    await _stateController.close();
  }
}

// Enums and Data Classes
enum NextPlayerState {
  idle,
  loading,
  ready,
  playing,
  paused,
  stopped,
  error,
}

enum NextPlayerEvent {
  initialized,
  positionChanged,
  playbackSpeedChanged,
  volumeChanged,
  videoZoomChanged,
  error,
  volumeGesture,
  brightnessGesture,
  seekGesture,
  zoomGesture,
  gestureDetected,
  orientationChanged,
  trackChanged,
}

enum VideoZoom {
  bestFit,
  stretch,
  crop,
  hundredPercent,
}

enum LoopMode {
  off,
  one,
  all,
}

enum DecoderPriority {
  deviceOnly,
  preferDevice,
  preferApp,
}

class AudioTrack {
  final int index;
  final String language;
  final String label;
  final bool isSelected;
  
  AudioTrack({
    required this.index,
    required this.language,
    required this.label,
    required this.isSelected,
  });
  
  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      index: map['index'] ?? 0,
      language: map['language'] ?? '',
      label: map['label'] ?? '',
      isSelected: map['isSelected'] ?? false,
    );
  }
}

class SubtitleTrack {
  final int index;
  final String language;
  final String label;
  final bool isSelected;
  final bool isExternal;
  
  SubtitleTrack({
    required this.index,
    required this.language,
    required this.label,
    required this.isSelected,
    required this.isExternal,
  });
  
  factory SubtitleTrack.fromMap(Map<String, dynamic> map) {
    return SubtitleTrack(
      index: map['index'] ?? 0,
      language: map['language'] ?? '',
      label: map['label'] ?? '',
      isSelected: map['isSelected'] ?? false,
      isExternal: map['isExternal'] ?? false,
    );
  }
}