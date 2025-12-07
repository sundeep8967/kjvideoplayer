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
  final StreamController<Map<String, dynamic>> _nativeButtonController = StreamController<Map<String, dynamic>>.broadcast();
  
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
  Stream<Map<String, dynamic>> get onNativeButtonClicked => _nativeButtonController.stream;
  
  Media3PlayerController({required this.viewId}) {
    _channel = MethodChannel('media3_player_$viewId');
    _setupMethodCallHandler();
}
  

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      // debugPrint('[Media3PlayerController] Native call: ${call.method} args: ${call.arguments}');
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
        case 'onSubtitleButtonClicked':
          _handleNativeButtonClick('subtitle', call.arguments);
          break;
        case 'onAudioTrackButtonClicked':
          _handleNativeButtonClick('audioTrack', call.arguments);
          break;
        case 'onSettingsButtonClicked':
          _handleNativeButtonClick('settings', call.arguments);
          break;
        case 'onBackButtonClicked':
          _handleNativeButtonClick('back', call.arguments);
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

    // debugPrint('[Media3PlayerController] _handlePositionChanged: position=${_position.inSeconds}s, duration=${_duration.inSeconds}s');
    
    _positionController.add({
      'position': _position,
      'duration': _duration,
    });
    // debugPrint('[Media3PlayerController] Emitted onPositionChanged: position=${_position.inSeconds}s, duration=${_duration.inSeconds}s');
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
    try {
      debugPrint('=== TRACKS UPDATE ===');
      
      // Safely convert the tracks data with proper type casting
      final audioTracks = (args['audioTracks'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
      final videoTracks = (args['videoTracks'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
      final subtitleTracks = (args['subtitleTracks'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
      final currentIndex = args['currentAudioTrackIndex'] as int?;
      
      // Validate track data
      if (audioTracks.isEmpty) {
        debugPrint('No audio tracks available');
        _tracksController.add({
          'videoTracks': _convertToMapList(videoTracks),
          'audioTracks': <Map<String, dynamic>>[],
          'subtitleTracks': _convertToMapList(subtitleTracks),
          'currentAudioTrackIndex': null,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        return;
      }

      // Ensure index is within bounds
      final validatedIndex = currentIndex?.clamp(0, audioTracks.length - 1);
      
      debugPrint('=== TRACKS UPDATE ===');
      debugPrint('Valid audio tracks: ${audioTracks.length}');
      debugPrint('Current index: $validatedIndex');
      
      // Convert to proper format
      final convertedAudioTracks = _convertToMapList(audioTracks);
      final convertedVideoTracks = _convertToMapList(videoTracks);
      final convertedSubtitleTracks = _convertToMapList(subtitleTracks);
      
      // Mark selected track
      for (int i = 0; i < convertedAudioTracks.length; i++) {
        convertedAudioTracks[i]['isSelected'] = i == validatedIndex;
      }
      
      debugPrint('Track details:');
      for (var i = 0; i < convertedAudioTracks.length; i++) {
        final track = convertedAudioTracks[i];
        debugPrint('[$i] ${track['name'] ?? 'Unknown'} (${track['language'] ?? 'Unknown'}) - '
            'Selected: ${track['isSelected']}');
      }

      _tracksController.add({
        'videoTracks': convertedVideoTracks,
        'audioTracks': convertedAudioTracks,
        'subtitleTracks': convertedSubtitleTracks,
        'currentAudioTrackIndex': validatedIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error processing tracks: $e');
      // Send empty tracks on error to prevent UI crashes
      _tracksController.add({
        'videoTracks': <Map<String, dynamic>>[],
        'audioTracks': <Map<String, dynamic>>[],
        'subtitleTracks': <Map<String, dynamic>>[],
        'currentAudioTrackIndex': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Safely convert dynamic list to List<Map<String, dynamic>>
  List<Map<String, dynamic>> _convertToMapList(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    
    return data.map((item) {
      if (item is Map) {
        // Convert any Map type to Map<String, dynamic>
        return Map<String, dynamic>.from(item);
      }
      return <String, dynamic>{};
    }).toList();
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
  
  void _handleNativeButtonClick(String buttonType, dynamic data) {
    debugPrint('[Media3PlayerController] Native button clicked: $buttonType');
    _nativeButtonController.add({
      'buttonType': buttonType,
      'data': data,
    });
  }
  
  /// Safe audio track selection with comprehensive validation
  Future<void> selectAudioTrack(int index) async {
    try {
      debugPrint('Attempting to select audio track $index');
      
      // First get current tracks to validate index
      final tracks = await getTracks();
      final audioTracks = tracks?['audioTracks'] as List? ?? [];
      
      if (index < 0 || index >= audioTracks.length) {
        throw Exception('Invalid track index: $index (available: 0-${audioTracks.length - 1})');
      }
      
      await _channel.invokeMethod('setAudioTrack', {'index': index});
      
      // Verify the change was applied - wait longer due to staged execution in native code
      await Future.delayed(Duration(milliseconds: 1500));
      final updatedTracks = await getTracks();
      final updatedIndex = updatedTracks?['currentAudioTrackIndex'] as int?;
      
      debugPrint('Track selection verification: expected=$index, actual=$updatedIndex');
      
      if (updatedIndex != index) {
        // Try one more verification attempt before failing
        await Future.delayed(Duration(milliseconds: 500));
        final finalTracks = await getTracks();
        final finalIndex = finalTracks?['currentAudioTrackIndex'] as int?;
        
        if (finalIndex != index) {
          throw Exception('Track selection verification failed. Expected $index but got $finalIndex');
        }
      }
      
      debugPrint('Successfully selected audio track $index');
    } catch (e) {
      debugPrint('Error selecting audio track: $e');
      _error = 'Failed to select audio track: ${e.toString()}';
      _errorController.add(_error);
      rethrow;
    }
  }

  /// Select audio track by index with enhanced error handling (legacy method)
  Future<void> setAudioTrack(int index) async {
    try {
      debugPrint('Attempting to set audio track to index $index');
      final tracks = await getTracks();
      final audioTracks = _convertToMapList(tracks?['audioTracks']);
      
      if (audioTracks.isEmpty) {
        throw Exception('No audio tracks available');
      }
      
      if (index < 0 || index >= audioTracks.length) {
        throw Exception('Invalid audio track index: $index (available: 0-${audioTracks.length - 1})');
      }
      
      await _channel.invokeMethod('setAudioTrack', {'index': index});
      debugPrint('Successfully set audio track to index $index');
      
      // Verify the change was applied
      await Future.delayed(Duration(milliseconds: 300)); // Wait for change to apply
      final newTracks = await getTracks();
      final newAudioTracks = _convertToMapList(newTracks?['audioTracks']);
      if (index < newAudioTracks.length && newAudioTracks[index]['isSelected'] != true) {
        debugPrint('Warning: Track selection may not have been applied');
      }
    } catch (e) {
      debugPrint('Error setting audio track: $e');
      _error = 'Failed to set audio track: ${e.toString()}';
      _errorController.add(_error);
      rethrow;
    }
  }

  /// Get the currently selected audio track index
  Future<int?> getSelectedAudioTrackIndex() async {
    debugPrint('[Media3PlayerController] Invoking native getSelectedAudioTrackIndex()');
    try {
      final result = await _channel.invokeMethod('getSelectedAudioTrackIndex');
      final int? index = result as int?;
      debugPrint('[Media3PlayerController] Native getSelectedAudioTrackIndex() returned: $index');
      return index;
    } catch (e) {
      debugPrint('[Media3PlayerController] Error getting selected audio track index: $e');
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
  
  /// Set the video title in native UI overlay
  Future<void> setVideoTitle(String title) async {
    debugPrint('[Media3PlayerController] Setting video title: $title');
    try {
      await _channel.invokeMethod('setVideoTitle', {'title': title});
      debugPrint('[Media3PlayerController] Video title set successfully');
    } catch (e) {
      debugPrint('[Media3PlayerController] Error setting video title: $e');
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

  /// Get current tracks information manually with proper type casting
  Future<Map<String, dynamic>?> getTracks() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTracks');
      if (result == null) return null;
      
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Error getting tracks: $e');
      return null;
    }
  }

  /// Get tracks directly from player with proper type casting
  Future<Map<String, dynamic>?> getTracksFromPlayer() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTracksFromPlayer');
      if (result == null) return null;
      
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Error getting tracks from player: $e');
      return null;
    }
  }

  /// Test all track detection methods for debugging
  Future<Map<String, dynamic>?> testAllTrackMethods() async {
    try {
      final result = await _channel.invokeMethod('testAllTrackMethods');
      return result as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error testing track methods: $e');
      return null;
    }
  }

  /// Get current audio track index
  Future<int?> getCurrentAudioTrackIndex() async {
    try {
      final tracks = await getTracks();
      if (tracks == null || tracks['audioTracks'] == null) return null;
      
      final audioTracks = _convertToMapList(tracks['audioTracks']);
      for (var i = 0; i < audioTracks.length; i++) {
        if (audioTracks[i]['isSelected'] == true) {
          return i;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current audio track: $e');
      return null;
    }
  }

  /// Manually refresh tracks
  Future<void> refreshTracks() async {
    try {
      await _channel.invokeMethod('refreshTracks');
    } catch (e) {
      debugPrint('Error refreshing tracks: $e');
    }
  }

  /// Picture-in-Picture functionality
  Future<bool> isPictureInPictureSupported() async {
    try {
      final result = await _channel.invokeMethod('isPictureInPictureSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking PiP support: $e');
      return false;
    }
  }
  
  Future<bool> enterPictureInPicture() async {
    try {
      final result = await _channel.invokeMethod('enterPictureInPicture');
      return result ?? false;
    } catch (e) {
      debugPrint('Error entering PiP: $e');
      return false;
    }
  }

  /// Check audio tracks availability and debug info
  Future<void> checkAudioTracks() async {
    debugPrint('Checking audio tracks...');
    final tracks = await getTracks();
    debugPrint('Audio tracks: ${tracks?['audioTracks']}');
    
    if (tracks?['audioTracks']?.isEmpty ?? true) {
      debugPrint('No audio tracks available - possible causes:');
      debugPrint('1. Media file has no audio');
      debugPrint('2. Audio codec not supported');
      debugPrint('3. Track detection timing issue');
      debugPrint('4. Platform channel communication error');
    }
  }

  /// Verify media file properties
  void verifyMediaFile(String path) {
    debugPrint('Media file properties:');
    debugPrint('Path: $path');
    debugPrint('Extension: ${path.split('.').last}');
    debugPrint('File exists: ${path.isNotEmpty}');
  }

  /// Debug audio tracks for troubleshooting
  Future<void> debugAudioTracks() async {
    try {
      await _channel.invokeMethod('debugAudioTracks');
    } catch (e) {
      debugPrint('Error debugging audio tracks: $e');
    }
  }

  /// Debug current audio track selection
  Future<void> debugCurrentAudioTrack() async {
    try {
      await _channel.invokeMethod('debugCurrentAudioTrack');
    } catch (e) {
      debugPrint('Error debugging current audio track: $e');
    }
  }

  /// Add a list of media items to the playlist
  Future<void> addMediaItems(List<String> mediaItems) async {
    try {
      await _channel.invokeMethod('addMediaItems', {'mediaItems': mediaItems});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Remove a media item from the playlist at a specific index
  Future<void> removeMediaItem(int index) async {
    try {
      await _channel.invokeMethod('removeMediaItem', {'index': index});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Seek to the next media item in the playlist
  Future<void> seekToNext() async {
    try {
      await _channel.invokeMethod('seekToNext');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Seek to the previous media item in the playlist
  Future<void> seekToPrevious() async {
    try {
      await _channel.invokeMethod('seekToPrevious');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Seek to a specific media item in the playlist by index
  Future<void> seekToMediaItem(int index) async {
    try {
      await _channel.invokeMethod('seekToMediaItem', {'index': index});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Clear the entire playlist
  Future<void> clearPlaylist() async {
    try {
      await _channel.invokeMethod('clearPlaylist');
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Get a thumbnail from the video at a specific position.
  /// Returns a Uint8List of the image data (JPEG).
  Future<Uint8List?> getThumbnail(Duration position) async {
    try {
      final thumbnail = await _channel.invokeMethod<Uint8List>(
        'getThumbnail', 
        {'position': position.inMilliseconds},
      );
      return thumbnail;
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
      return null;
    }
  }

  /// Preload a video to be played in the future.
  Future<void> preload(String videoPath) async {
    try {
      await _channel.invokeMethod('preload', {'videoPath': videoPath});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Release a player back to the pool.
  Future<void> releasePlayer(String videoPath) async {
    try {
      await _channel.invokeMethod('releasePlayer', {'videoPath': videoPath});
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
    }
  }

  /// Enter Picture-in-Picture mode.
  /// This will only work on Android O and above.
  /// Returns true if the request to enter PiP was successful.
  Future<bool> enterPictureInPictureMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPictureInPicture');
      return result ?? false;
    } catch (e) {
      _error = e.toString();
      _errorController.add(_error);
      return false;
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
    _nativeButtonController.close();
    // Dispose the native player
    debugPrint('[Media3PlayerController] Invoking native dispose()');
    _channel.invokeMethod('dispose').catchError((e) {
      debugPrint('[Media3PlayerController] Error disposing native Media3Player: $e');
    });
  }
}