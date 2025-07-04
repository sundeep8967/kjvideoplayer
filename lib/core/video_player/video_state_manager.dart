import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Video State Manager for saving and restoring playback state
/// Implements NextPlayer's video state persistence
class VideoStateManager {
  static const MethodChannel _channel = MethodChannel('video_state_manager');
  static const String _statePrefix = 'video_state_';
  
  SharedPreferences? _prefs;
  
  // Resume settings
  Resume _resumeMode = Resume.yes;
  bool _rememberSelections = true;
  bool _rememberPlayerBrightness = false;
  
  // Event streams
  final StreamController<VideoState> _stateController = 
      StreamController<VideoState>.broadcast();
  
  Stream<VideoState> get stateStream => _stateController.stream;
  
  // Getters
  Resume get resumeMode => _resumeMode;
  bool get rememberSelections => _rememberSelections;
  bool get rememberPlayerBrightness => _rememberPlayerBrightness;
  
  VideoStateManager() {
    _initializePreferences();
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVideoStateChanged':
        final state = VideoState.fromMap(call.arguments);
        _stateController.add(state);
        break;
    }
  }
  
  /// Initialize video state manager
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize', {
        'resumeMode': _resumeMode.name,
        'rememberSelections': _rememberSelections,
        'rememberPlayerBrightness': _rememberPlayerBrightness,
      });
    } catch (e) {
      throw Exception('Failed to initialize video state manager: $e');
    }
  }
  
  /// Set resume mode
  Future<void> setResumeMode(Resume mode) async {
    try {
      await _channel.invokeMethod('setResumeMode', {'mode': mode.name});
      _resumeMode = mode;
    } catch (e) {
      throw Exception('Failed to set resume mode: $e');
    }
  }
  
  /// Set remember selections
  Future<void> setRememberSelections(bool remember) async {
    try {
      await _channel.invokeMethod('setRememberSelections', {'remember': remember});
      _rememberSelections = remember;
    } catch (e) {
      throw Exception('Failed to set remember selections: $e');
    }
  }
  
  /// Set remember player brightness
  Future<void> setRememberPlayerBrightness(bool remember) async {
    try {
      await _channel.invokeMethod('setRememberPlayerBrightness', {'remember': remember});
      _rememberPlayerBrightness = remember;
    } catch (e) {
      throw Exception('Failed to set remember player brightness: $e');
    }
  }
  
  /// Save video state
  Future<void> saveVideoState(String videoPath, VideoState state) async {
    try {
      if (_prefs == null) await _initializePreferences();
      
      final key = _getStateKey(videoPath);
      final stateJson = jsonEncode(state.toMap());
      await _prefs!.setString(key, stateJson);
      
      // Also save to native side for ExoPlayer integration
      await _channel.invokeMethod('saveVideoState', {
        'videoPath': videoPath,
        'state': state.toMap(),
      });
    } catch (e) {
      throw Exception('Failed to save video state: $e');
    }
  }
  
  /// Get video state
  Future<VideoState?> getVideoState(String videoPath) async {
    try {
      if (_prefs == null) await _initializePreferences();
      
      final key = _getStateKey(videoPath);
      final stateJson = _prefs!.getString(key);
      
      if (stateJson != null) {
        final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
        return VideoState.fromMap(stateMap);
      }
      
      // Try to get from native side
      final result = await _channel.invokeMethod('getVideoState', {'videoPath': videoPath});
      if (result != null) {
        return VideoState.fromMap(result);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Delete video state
  Future<void> deleteVideoState(String videoPath) async {
    try {
      if (_prefs == null) await _initializePreferences();
      
      final key = _getStateKey(videoPath);
      await _prefs!.remove(key);
      
      await _channel.invokeMethod('deleteVideoState', {'videoPath': videoPath});
    } catch (e) {
      throw Exception('Failed to delete video state: $e');
    }
  }
  
  /// Clear all video states
  Future<void> clearAllStates() async {
    try {
      if (_prefs == null) await _initializePreferences();
      
      final keys = _prefs!.getKeys().where((key) => key.startsWith(_statePrefix));
      for (final key in keys) {
        await _prefs!.remove(key);
      }
      
      await _channel.invokeMethod('clearAllStates');
    } catch (e) {
      throw Exception('Failed to clear all states: $e');
    }
  }
  
  /// Get all video states
  Future<Map<String, VideoState>> getAllStates() async {
    try {
      if (_prefs == null) await _initializePreferences();
      
      final states = <String, VideoState>{};
      final keys = _prefs!.getKeys().where((key) => key.startsWith(_statePrefix));
      
      for (final key in keys) {
        final stateJson = _prefs!.getString(key);
        if (stateJson != null) {
          final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
          final videoPath = key.substring(_statePrefix.length);
          states[videoPath] = VideoState.fromMap(stateMap);
        }
      }
      
      return states;
    } catch (e) {
      return {};
    }
  }
  
  /// Should resume playback based on settings and video duration
  bool shouldResumePlayback(Duration videoDuration, Duration lastPosition) {
    switch (_resumeMode) {
      case Resume.no:
        return false;
      case Resume.yes:
        return lastPosition > Duration.zero && 
               lastPosition < videoDuration - const Duration(seconds: 10);
      case Resume.ask:
        // This should trigger a dialog in the UI
        return lastPosition > Duration.zero && 
               lastPosition < videoDuration - const Duration(seconds: 10);
    }
  }
  
  /// Update video state with current playback info
  Future<void> updateVideoState(String videoPath, {
    Duration? position,
    double? playbackSpeed,
    VideoZoom? videoZoom,
    int? audioTrack,
    int? subtitleTrack,
    double? brightness,
    double? zoom,
  }) async {
    try {
      final currentState = await getVideoState(videoPath) ?? VideoState.empty(videoPath);
      
      final updatedState = currentState.copyWith(
        position: position,
        playbackSpeed: playbackSpeed,
        videoZoom: videoZoom,
        audioTrack: audioTrack,
        subtitleTrack: subtitleTrack,
        brightness: brightness,
        zoom: zoom,
        lastPlayed: DateTime.now(),
      );
      
      await saveVideoState(videoPath, updatedState);
    } catch (e) {
      throw Exception('Failed to update video state: $e');
    }
  }
  
  String _getStateKey(String videoPath) {
    return '$_statePrefix${videoPath.hashCode}';
  }
  
  void dispose() {
    _stateController.close();
  }
}

/// Resume Mode enum
enum Resume {
  no,
  yes,
  ask;
  
  String get name => toString().split('.').last;
}

/// Video Zoom enum
enum VideoZoom {
  bestFit,
  stretch,
  crop,
  hundredPercent;
  
  String get name => toString().split('.').last;
}

/// Video State model
class VideoState {
  final String videoPath;
  final Duration position;
  final double playbackSpeed;
  final VideoZoom videoZoom;
  final int audioTrack;
  final int subtitleTrack;
  final double brightness;
  final double zoom;
  final DateTime lastPlayed;
  
  const VideoState({
    required this.videoPath,
    required this.position,
    required this.playbackSpeed,
    required this.videoZoom,
    required this.audioTrack,
    required this.subtitleTrack,
    required this.brightness,
    required this.zoom,
    required this.lastPlayed,
  });
  
  factory VideoState.empty(String videoPath) {
    return VideoState(
      videoPath: videoPath,
      position: Duration.zero,
      playbackSpeed: 1.0,
      videoZoom: VideoZoom.bestFit,
      audioTrack: -1,
      subtitleTrack: -1,
      brightness: 0.5,
      zoom: 1.0,
      lastPlayed: DateTime.now(),
    );
  }
  
  factory VideoState.fromMap(Map<String, dynamic> map) {
    return VideoState(
      videoPath: map['videoPath'] ?? '',
      position: Duration(milliseconds: map['position'] ?? 0),
      playbackSpeed: map['playbackSpeed']?.toDouble() ?? 1.0,
      videoZoom: VideoZoom.values.firstWhere(
        (e) => e.name == map['videoZoom'],
        orElse: () => VideoZoom.bestFit,
      ),
      audioTrack: map['audioTrack'] ?? -1,
      subtitleTrack: map['subtitleTrack'] ?? -1,
      brightness: map['brightness']?.toDouble() ?? 0.5,
      zoom: map['zoom']?.toDouble() ?? 1.0,
      lastPlayed: DateTime.fromMillisecondsSinceEpoch(
        map['lastPlayed'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'videoPath': videoPath,
      'position': position.inMilliseconds,
      'playbackSpeed': playbackSpeed,
      'videoZoom': videoZoom.name,
      'audioTrack': audioTrack,
      'subtitleTrack': subtitleTrack,
      'brightness': brightness,
      'zoom': zoom,
      'lastPlayed': lastPlayed.millisecondsSinceEpoch,
    };
  }
  
  VideoState copyWith({
    String? videoPath,
    Duration? position,
    double? playbackSpeed,
    VideoZoom? videoZoom,
    int? audioTrack,
    int? subtitleTrack,
    double? brightness,
    double? zoom,
    DateTime? lastPlayed,
  }) {
    return VideoState(
      videoPath: videoPath ?? this.videoPath,
      position: position ?? this.position,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      videoZoom: videoZoom ?? this.videoZoom,
      audioTrack: audioTrack ?? this.audioTrack,
      subtitleTrack: subtitleTrack ?? this.subtitleTrack,
      brightness: brightness ?? this.brightness,
      zoom: zoom ?? this.zoom,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
  
  @override
  String toString() {
    return 'VideoState(videoPath: $videoPath, position: $position, '
           'playbackSpeed: $playbackSpeed, videoZoom: $videoZoom, '
           'audioTrack: $audioTrack, subtitleTrack: $subtitleTrack, '
           'brightness: $brightness, zoom: $zoom, lastPlayed: $lastPlayed)';
  }
}