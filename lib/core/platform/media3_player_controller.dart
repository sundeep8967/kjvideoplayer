import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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
  final StreamController<Map<String, dynamic>> _videoSizeController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<double> _systemVolumeController = StreamController<double>.broadcast();
  
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
  Stream<Map<String, dynamic>> get onVideoSizeChanged => _videoSizeController.stream;
  Stream<double> get onSystemVolumeChanged => _systemVolumeController.stream;
  
  Media3PlayerController({required this.viewId}) {
    _channel = MethodChannel('media3_player_$viewId');
    _setupMethodCallHandler();
}
  

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      debugPrint('[Media3PlayerController] Native call: ${call.method} args: ${call.arguments}');
      switch (call.method) {
        case 'onPlaybackStateChanged':
          _handlePlaybackStateChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onPlayingChanged': // Changed from 'onIsPlayingChanged'
          _handleIsPlayingChanged(call.arguments as bool);
          break;
        case 'onPositionChanged':
          _handlePositionChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onError':
          _handleError(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onInitialized':
          _handleInitialized();
          break;
        case 'onVideoSizeChanged':
          _handleVideoSizeChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onFirstFrameRendered':
          _handleFirstFrameRendered();
          break;
        case 'onLoadingChanged':
          _handleLoadingChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onTracksChanged':
          _handleTracksChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onControlsVisibilityChanged':
          _handleControlsVisibilityChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onFullscreenToggle':
          _handleFullscreenToggle(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onSystemVolumeChanged':
          _handleSystemVolumeChanged(call.arguments as Map<dynamic, dynamic>);
          break;
        default:
          debugPrint('[Media3PlayerController] Unhandled native method: ${call.method}');
      }
    });
  }

  void _handleIsPlayingChanged(bool isPlaying) {
    debugPrint('[Media3PlayerController] _handleIsPlayingChanged: $isPlaying');
    _isPlaying = isPlaying;
    _playingController.add(_isPlaying);
    debugPrint('[Media3PlayerController] Emitted onPlayingChanged: $_isPlaying');
  }
  
  /// Play the video
  Future<void> play() async {
    debugPrint('[Media3PlayerController] Invoking native play()');
    try {
      await _channel.invokeMethod('play');
      debugPrint('[Media3PlayerController] Native play() invoked successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native play(): $e');
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Pause the video
  Future<void> pause() async {
    debugPrint('[Media3PlayerController] Invoking native pause()');
    try {
      await _channel.invokeMethod('pause');
      debugPrint('[Media3PlayerController] Native pause() invoked successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native pause(): $e');
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Seek to a specific position
  Future<void> seekTo(Duration position) async {
    debugPrint('[Media3PlayerController] Invoking native seekTo(${position.inMilliseconds})');
    try {
      await _channel.invokeMethod('seekTo', {
        'position': position.inMilliseconds,
      });
      debugPrint('[Media3PlayerController] Native seekTo() invoked successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native seekTo(): $e');
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    debugPrint('[Media3PlayerController] Invoking native setPlaybackSpeed($speed)');
    try {
      await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
      debugPrint('[Media3PlayerController] Native setPlaybackSpeed() invoked successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native setPlaybackSpeed(): $e');
      _error = e.toString();
      _errorController.add(_error);
    }
  }
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    debugPrint('[Media3PlayerController] Invoking native setVolume($volume)');
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
      debugPrint('[Media3PlayerController] Native setVolume() invoked successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native setVolume(): $e');
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
  void _handlePlaybackStateChanged(Map<dynamic, dynamic> args) {
    final state = args['state'] as String?;
    final isPlayingUpdate = args['isPlaying'] as bool? ?? false;
    final isBufferingUpdate = args['isBuffering'] as bool? ?? false;
    final bufferedPercentage = args['bufferedPercentage'] as int? ?? 0;
    final bufferedPosition = args['bufferedPosition'] as int? ?? 0;

    debugPrint('[Media3PlayerController] _handlePlaybackStateChanged: state=$state, isPlaying=$isPlayingUpdate, isBuffering=$isBufferingUpdate');

    _isPlaying = isPlayingUpdate;
    _isBuffering = isBufferingUpdate;
    
    _playingController.add(_isPlaying);
    _bufferingController.add(_isBuffering);
    
    _performanceController.add({
      'type': 'playbackStateChanged',
      'state': state,
      'isPlaying': _isPlaying,
      'isBuffering': _isBuffering,
      'bufferedPercentage': bufferedPercentage,
      'bufferedPosition': bufferedPosition,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    debugPrint('[Media3PlayerController] Emitted onPlayingChanged: $_isPlaying, onBufferingChanged: $_isBuffering');
  }
  
  void _handlePositionChanged(Map<dynamic, dynamic> args) {
    final positionMillis = args['position'] as int? ?? 0;
    final durationMillis = args['duration'] as int? ?? 0;

    _position = Duration(milliseconds: positionMillis);
    _duration = Duration(milliseconds: durationMillis);

    debugPrint('[Media3PlayerController] _handlePositionChanged: position=${_position.inSeconds}s, duration=${_duration.inSeconds}s');

    _positionController.add({
      'position': _position,
      'duration': _duration,
    });
    debugPrint('[Media3PlayerController] Emitted onPositionChanged: position=${_position.inSeconds}s, duration=${_duration.inSeconds}s');
  }
  
  void _handleError(Map<dynamic, dynamic> args) {
    _error = args['error'] as String?;
    debugPrint('[Media3PlayerController] _handleError: $_error');
    _errorController.add(_error);
    debugPrint('[Media3PlayerController] Emitted onError: $_error');
  }
  
  void _handleInitialized() {
    _isInitialized = true;
    debugPrint('[Media3PlayerController] _handleInitialized');
    _initializedController.add(null);
    debugPrint('[Media3PlayerController] Emitted onInitialized');
  }
  
  void _handleVideoSizeChanged(Map<dynamic, dynamic> args) {
    final width = args['width'] as int? ?? 0;
    final height = args['height'] as int? ?? 0;
    final pixelRatio = args['pixelWidthHeightRatio'] as double? ?? 1.0;
    
    debugPrint('[Media3PlayerController] _handleVideoSizeChanged: ${width}x$height, ratio: $pixelRatio');
    _performanceController.add({
      'type': 'videoSizeChanged',
      'width': width,
      'height': height,
      'pixelWidthHeightRatio': pixelRatio,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleFirstFrameRendered() {
    debugPrint('[Media3PlayerController] _handleFirstFrameRendered');
    _performanceController.add({
      'type': 'firstFrameRendered',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleLoadingChanged(Map<dynamic, dynamic> args) {
    final isLoading = args['isLoading'] as bool? ?? false;
    debugPrint('[Media3PlayerController] _handleLoadingChanged: $isLoading');
    _performanceController.add({
      'type': 'loadingChanged',
      'isLoading': isLoading,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleTracksChanged(Map<dynamic, dynamic> args) {
    final videoTracks = args['videoTracks'] as List<dynamic>? ?? [];
    final audioTracks = args['audioTracks'] as List<dynamic>? ?? [];
    final subtitleTracks = args['subtitleTracks'] as List<dynamic>? ?? [];
    
    debugPrint('[Media3PlayerController] _handleTracksChanged: Video: ${videoTracks.length}, Audio: ${audioTracks.length}, Subtitle: ${subtitleTracks.length}');
    _tracksController.add({
      'videoTracks': videoTracks,
      'audioTracks': audioTracks,
      'subtitleTracks': subtitleTracks,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleControlsVisibilityChanged(Map<dynamic, dynamic> args) {
    final visible = args['visible'] as bool? ?? false;
    debugPrint('[Media3PlayerController] _handleControlsVisibilityChanged: $visible');
    _performanceController.add({
      'type': 'controlsVisibilityChanged',
      'visible': visible,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleFullscreenToggle(Map<dynamic, dynamic> args) {
    final isFullscreen = args['isFullscreen'] as bool? ?? false;
    debugPrint('[Media3PlayerController] _handleFullscreenToggle: $isFullscreen');
    _performanceController.add({
      'type': 'fullscreenToggle',
      'isFullscreen': isFullscreen,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  void _handleSystemVolumeChanged(Map<dynamic, dynamic> args) {
    final volume = args['volume'] as double? ?? 0.5;
    debugPrint('[Media3PlayerController] _handleSystemVolumeChanged: $volume');
    _systemVolumeController.add(volume);
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

  /// Get the currently selected audio track index
  Future<int?> getSelectedAudioTrackIndex() async {
    debugPrint('[Media3PlayerController] Invoking native getSelectedAudioTrackIndex()');
    try {
      // Ensure the player is initialized and tracks are available before calling
      // For now, this is a placeholder. The native side needs to implement 'getSelectedAudioTrackIndex'.
      // It should return the index of the currently selected audio track.
      final int? index = await _channel.invokeMethod<int>('getSelectedAudioTrackIndex');
      debugPrint('[Media3PlayerController] Native getSelectedAudioTrackIndex() returned: $index');
      return index;
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native getSelectedAudioTrackIndex(): $e');
      // Return null or a sensible default if the native call fails or is not implemented
      return null;
    }
  }

  /// Get system volume using Media3
  Future<double> getSystemVolume() async {
    debugPrint('[Media3PlayerController] Getting system volume');
    try {
      final result = await _channel.invokeMethod('getSystemVolume');
      double volume = (result as double?) ?? 0.7;
      debugPrint('[Media3PlayerController] System volume: $volume');
      return volume;
    } catch (e) {
      debugPrint('[Media3PlayerController] Error getting system volume: $e');
      return 0.7; // Default volume
    }
  }

  /// Set system volume using Media3
  Future<void> setSystemVolume(double volume) async {
    debugPrint('[Media3PlayerController] Setting system volume to: $volume');
    try {
      await _channel.invokeMethod('setSystemVolume', {'volume': volume});
      debugPrint('[Media3PlayerController] System volume set successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error setting system volume: $e');
    }
  }


  /// Set the resize mode for the player view
  Future<void> setResizeMode(String mode) async {
    debugPrint('[Media3PlayerController] Invoking native setResizeMode($mode)');
    try {
      await _channel.invokeMethod('setResizeMode', {'mode': mode});
      debugPrint('[Media3PlayerController] Native setResizeMode() invoked successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error invoking native setResizeMode(): $e');
      _error = e.toString(); // Optionally propagate error
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
    debugPrint('[Media3PlayerController] Invoking native dispose()');
    _channel.invokeMethod('dispose').catchError((e) {
      debugPrint('[Media3PlayerController] Error disposing native Media3Player: $e');
    });
  }
}