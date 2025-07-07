import 'dart:async';
import 'package:flutter/services.dart';

/// Media3 Player Controller - Clean implementation without NextPlayer
class Media3PlayerController {
  // ...existing code...
  late final MethodChannel _channel;
  final int viewId;
  
  // Player state
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  
  // Stream controllers for reactive updates
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<bool> _bufferingController = StreamController<bool>.broadcast();
  final StreamController<Map<String, Duration>> _positionController = StreamController<Map<String, Duration>>.broadcast();
  final StreamController<String?> _errorController = StreamController<String?>.broadcast();
  final StreamController<void> _initializedController = StreamController<void>.broadcast();
  final StreamController<Map<String, dynamic>> _performanceController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _tracksController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;
  
  // Streams for reactive programming
  Stream<bool> get onPlayingChanged => _playingController.stream;
  Stream<bool> get onBufferingChanged => _bufferingController.stream;
  Stream<Map<String, Duration>> get onPositionChanged => _positionController.stream;
  Stream<String?> get onError => _errorController.stream;
  Stream<void> get onInitialized => _initializedController.stream;
  Stream<Map<String, dynamic>> get onPerformanceUpdate => _performanceController.stream;
  Stream<Map<String, dynamic>> get onTracksChanged => _tracksController.stream;
  
  Media3PlayerController({required this.viewId}) {
    _channel = MethodChannel('media3_player_$viewId');
    _setupMethodCallHandler();
}
  
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlaybackStateChanged':
          _handlePlaybackStateChanged(call.arguments);
          break;
        case 'onPlayingChanged': // Changed from 'onIsPlayingChanged'
          _handleIsPlayingChanged(call.arguments);
          break;
        case 'onPositionChanged':
          _handlePositionChanged(call.arguments);
          break;
        case 'onError':
          _handleError(call.arguments);
          break;
        case 'onInitialized':
          _handleInitialized();
          break;
        case 'onVideoSizeChanged':
          _handleVideoSizeChanged(call.arguments);
          break;
        case 'onFirstFrameRendered':
          _handleFirstFrameRendered();
          break;
        case 'onLoadingChanged':
          _handleLoadingChanged(call.arguments);
          break;
        case 'onTracksChanged':
          _handleTracksChanged(call.arguments);
          break;
        case 'onControlsVisibilityChanged':
          _handleControlsVisibilityChanged(call.arguments);
          break;
        case 'onFullscreenToggle':
          _handleFullscreenToggle(call.arguments);
          break;
      }
    });
  }

  void _handleIsPlayingChanged(dynamic isPlaying) {
    _isPlaying = isPlaying == true;
    _playingController.add(_isPlaying);
  }
  
  /// Play the video
  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Pause the video
  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Seek to a specific position
  Future<void> seekTo(Duration position) async {
    try {
      await _channel.invokeMethod('seekTo', {
        'position': position.inMilliseconds,
      });
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Get current position
  Future<Duration> getCurrentPosition() async {
    try {
      final position = await _channel.invokeMethod<int>('getCurrentPosition');
      return Duration(milliseconds: position ?? 0);
    } catch (e) {
      return Duration.zero;
    }
  }
  
  /// Get duration
  Future<Duration> getDuration() async {
    try {
      final duration = await _channel.invokeMethod<int>('getDuration');
      return Duration(milliseconds: duration ?? 0);
    } catch (e) {
      return Duration.zero;
    }
  }
  
  /// Check if playing
  Future<bool> getIsPlaying() async {
    try {
      final playing = await _channel.invokeMethod<bool>('isPlaying');
      return playing ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Show Media3's built-in controls
  Future<void> showControls() async {
    try {
      await _channel.invokeMethod('showControls');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Hide Media3's built-in controls
  Future<void> hideControls() async {
    try {
      await _channel.invokeMethod('hideControls');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Set controller timeout for auto-hide
  Future<void> setControllerTimeout(int timeoutMs) async {
    try {
      await _channel.invokeMethod('setControllerTimeout', {'timeout': timeoutMs});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Enter fullscreen mode (Media3 handles this)
  Future<void> enterFullscreen() async {
    try {
      await _channel.invokeMethod('enterFullscreen');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  // Event handlers
  void _handlePlaybackStateChanged(Map<String, dynamic> args) {
    final state = args['state'] as String?;
    _isPlaying = args['isPlaying'] as bool? ?? false;
    _isBuffering = args['isBuffering'] as bool? ?? false;
    final bufferedPercentage = args['bufferedPercentage'] as int? ?? 0;
    final bufferedPosition = args['bufferedPosition'] as int? ?? 0;
    
    _playingController.add(_isPlaying);
    _bufferingController.add(_isBuffering);
    
    // Enhanced performance monitoring
    _performanceController.add({
      'type': 'playbackStateChanged',
      'state': state,
      'isPlaying': _isPlaying,
      'isBuffering': _isBuffering,
      'bufferedPercentage': bufferedPercentage,
      'bufferedPosition': bufferedPosition,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    print('Media3Player: State changed to $state, Playing: $_isPlaying, Buffering: $_isBuffering, Buffer: $bufferedPercentage%');
  }
  
  void _handlePositionChanged(Map<String, dynamic> args) {
    final position = args['position'] as int? ?? 0;
    final duration = args['duration'] as int? ?? 0;

    _position = Duration(milliseconds: position);
    _duration = Duration(milliseconds: duration);

    _positionController.add({
      'position': _position,
      'duration': _duration,
    });
  }
  
  void _handleError(Map<String, dynamic> args) {
    _error = args['error'] as String?;
    _errorController.add(_error);
    print('Media3Player: Error - $_error');
  }
  
  void _handleInitialized() {
    _isInitialized = true;
    _initializedController.add(null);
    print('Media3Player: Initialized successfully');
  }
  
  void _handleVideoSizeChanged(Map<String, dynamic> args) {
    final width = args['width'] as int? ?? 0;
    final height = args['height'] as int? ?? 0;
    final pixelRatio = args['pixelWidthHeightRatio'] as double? ?? 1.0;
    
    _performanceController.add({
      'type': 'videoSizeChanged',
      'width': width,
      'height': height,
      'pixelWidthHeightRatio': pixelRatio,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    print('Media3Player: Video size changed to ${width}x${height} (ratio: $pixelRatio)');
  }
  
  void _handleFirstFrameRendered() {
    _performanceController.add({
      'type': 'firstFrameRendered',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('Media3Player: First frame rendered');
  }
  
  void _handleLoadingChanged(Map<String, dynamic> args) {
    final isLoading = args['isLoading'] as bool? ?? false;
    _performanceController.add({
      'type': 'loadingChanged',
      'isLoading': isLoading,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleTracksChanged(Map<String, dynamic> args) {
    final videoTracks = args['videoTracks'] as List<dynamic>? ?? [];
    final audioTracks = args['audioTracks'] as List<dynamic>? ?? [];
    final subtitleTracks = args['subtitleTracks'] as List<dynamic>? ?? [];
    
    _tracksController.add({
      'videoTracks': videoTracks,
      'audioTracks': audioTracks,
      'subtitleTracks': subtitleTracks,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    print('Media3Player: Tracks changed - Video: ${videoTracks.length}, Audio: ${audioTracks.length}, Subtitle: ${subtitleTracks.length}');
  }
  
  void _handleControlsVisibilityChanged(Map<String, dynamic> args) {
    final visible = args['visible'] as bool? ?? false;
    _performanceController.add({
      'type': 'controlsVisibilityChanged',
      'visible': visible,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleFullscreenToggle(Map<String, dynamic> args) {
    final isFullscreen = args['isFullscreen'] as bool? ?? false;
    _performanceController.add({
      'type': 'fullscreenToggle',
      'isFullscreen': isFullscreen,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Select audio track by index
  Future<void> setAudioTrack(int index) async {
    try {
      await _channel.invokeMethod('setAudioTrack', {'index': index});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Select subtitle track by index
  Future<void> setSubtitleTrack(int index) async {
    try {
      await _channel.invokeMethod('setSubtitleTrack', {'index': index});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Disable subtitle track
  Future<void> disableSubtitle() async {
    try {
      await _channel.invokeMethod('disableSubtitle');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Dispose the controller
  void dispose() {
    _playingController.close();
    _bufferingController.close();
    _positionController.close();
    _errorController.close();
    _initializedController.close();
    _performanceController.close();
    _tracksController.close();
    // Dispose the native player
    _channel.invokeMethod('dispose').catchError((e) {
      print('Error disposing Media3Player: $e');
    });
  }
}