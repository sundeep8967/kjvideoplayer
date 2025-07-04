import 'dart:async';
import 'package:flutter/services.dart';

/// Advanced Player Controller with NextPlayer core features
/// Implements missing core functionality from NextPlayer
class AdvancedPlayerController {
  static const MethodChannel _channel = MethodChannel('advanced_player');
  
  // Player state
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  VideoZoom _videoZoom = VideoZoom.bestFit;
  LoopMode _loopMode = LoopMode.off;
  FastSeek _fastSeek = FastSeek.auto;
  DecoderPriority _decoderPriority = DecoderPriority.preferDevice;
  
  // Audio features
  bool _skipSilenceEnabled = false;
  bool _volumeBoostEnabled = false;
  String _preferredAudioLanguage = "";
  
  // Subtitle features  
  String _preferredSubtitleLanguage = "";
  bool _useSystemCaptionStyle = false;
  
  // Gesture controls
  bool _useSwipeControls = true;
  bool _useSeekControls = true;
  bool _useZoomControls = true;
  bool _useLongPressControls = false;
  double _longPressControlsSpeed = 2.0;
  
  // Playback preferences
  bool _rememberPlayerBrightness = false;
  double _playerBrightness = 0.5;
  bool _rememberSelections = true;
  bool _autoplay = true;
  bool _autoPip = true;
  bool _autoBackgroundPlay = false;
  int _seekIncrement = 10;
  int _controllerAutoHideTimeout = 2;
  
  // Event streams
  final StreamController<PlayerEvent> _eventController = StreamController<PlayerEvent>.broadcast();
  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();
  
  // Getters
  Stream<PlayerEvent> get events => _eventController.stream;
  Stream<PlayerState> get stateStream => _stateController.stream;
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  double get playbackSpeed => _playbackSpeed;
  double get volume => _volume;
  VideoZoom get videoZoom => _videoZoom;
  LoopMode get loopMode => _loopMode;
  FastSeek get fastSeek => _fastSeek;
  DecoderPriority get decoderPriority => _decoderPriority;
  bool get skipSilenceEnabled => _skipSilenceEnabled;
  bool get volumeBoostEnabled => _volumeBoostEnabled;
  
  // Core playback methods
  Future<void> initialize(String videoPath) async {
    try {
      await _channel.invokeMethod('initialize', {
        'videoPath': videoPath,
        'decoderPriority': _decoderPriority.name,
        'fastSeek': _fastSeek.name,
        'preferredAudioLanguage': _preferredAudioLanguage,
        'preferredSubtitleLanguage': _preferredSubtitleLanguage,
        'useSystemCaptionStyle': _useSystemCaptionStyle,
      });
      _isInitialized = true;
      _eventController.add(PlayerEvent.initialized);
    } catch (e) {
      _eventController.add(PlayerEvent.error);
      throw Exception('Failed to initialize player: $e');
    }
  }
  
  Future<void> play() async {
    await _channel.invokeMethod('play');
    _isPlaying = true;
    _stateController.add(PlayerState.playing);
  }
  
  Future<void> pause() async {
    await _channel.invokeMethod('pause');
    _isPlaying = false;
    _stateController.add(PlayerState.paused);
  }
  
  Future<void> seekTo(Duration position) async {
    await _channel.invokeMethod('seekTo', {'position': position.inMilliseconds});
    _position = position;
  }
  
  Future<void> seekRelative(Duration offset) async {
    final newPosition = _position + offset;
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    await seekTo(clampedPosition);
  }
  
  // Advanced playback features
  Future<void> setPlaybackSpeed(double speed) async {
    await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
    _playbackSpeed = speed;
    _eventController.add(PlayerEvent.playbackSpeedChanged);
  }
  
  Future<void> setVideoZoom(VideoZoom zoom) async {
    await _channel.invokeMethod('setVideoZoom', {'zoom': zoom.name});
    _videoZoom = zoom;
    _eventController.add(PlayerEvent.videoZoomChanged);
  }
  
  Future<void> setLoopMode(LoopMode mode) async {
    await _channel.invokeMethod('setLoopMode', {'mode': mode.name});
    _loopMode = mode;
    _eventController.add(PlayerEvent.loopModeChanged);
  }
  
  Future<void> setFastSeek(FastSeek fastSeek) async {
    await _channel.invokeMethod('setFastSeek', {'fastSeek': fastSeek.name});
    _fastSeek = fastSeek;
  }
  
  Future<void> setDecoderPriority(DecoderPriority priority) async {
    await _channel.invokeMethod('setDecoderPriority', {'priority': priority.name});
    _decoderPriority = priority;
  }
  
  // Audio features
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    await _channel.invokeMethod('setSkipSilenceEnabled', {'enabled': enabled});
    _skipSilenceEnabled = enabled;
  }
  
  Future<void> setVolumeBoostEnabled(bool enabled) async {
    await _channel.invokeMethod('setVolumeBoostEnabled', {'enabled': enabled});
    _volumeBoostEnabled = enabled;
  }
  
  Future<void> setVolume(double volume) async {
    await _channel.invokeMethod('setVolume', {'volume': volume});
    _volume = volume;
  }
  
  Future<void> setPreferredAudioLanguage(String language) async {
    await _channel.invokeMethod('setPreferredAudioLanguage', {'language': language});
    _preferredAudioLanguage = language;
  }
  
  // Subtitle features
  Future<void> setPreferredSubtitleLanguage(String language) async {
    await _channel.invokeMethod('setPreferredSubtitleLanguage', {'language': language});
    _preferredSubtitleLanguage = language;
  }
  
  Future<void> setUseSystemCaptionStyle(bool use) async {
    await _channel.invokeMethod('setUseSystemCaptionStyle', {'use': use});
    _useSystemCaptionStyle = use;
  }
  
  Future<void> addSubtitleTrack(String subtitlePath) async {
    await _channel.invokeMethod('addSubtitleTrack', {'path': subtitlePath});
  }
  
  // Track selection
  Future<List<AudioTrack>> getAudioTracks() async {
    final result = await _channel.invokeMethod('getAudioTracks');
    return (result as List).map((track) => AudioTrack.fromMap(track)).toList();
  }
  
  Future<List<SubtitleTrack>> getSubtitleTracks() async {
    final result = await _channel.invokeMethod('getSubtitleTracks');
    return (result as List).map((track) => SubtitleTrack.fromMap(track)).toList();
  }
  
  Future<void> switchAudioTrack(int trackIndex) async {
    await _channel.invokeMethod('switchAudioTrack', {'trackIndex': trackIndex});
  }
  
  Future<void> switchSubtitleTrack(int trackIndex) async {
    await _channel.invokeMethod('switchSubtitleTrack', {'trackIndex': trackIndex});
  }
  
  // Gesture controls
  Future<void> setGestureControlsEnabled({
    bool? swipeControls,
    bool? seekControls,
    bool? zoomControls,
    bool? longPressControls,
  }) async {
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
  }
  
  Future<void> setLongPressSpeed(double speed) async {
    await _channel.invokeMethod('setLongPressSpeed', {'speed': speed});
    _longPressControlsSpeed = speed;
  }
  
  // Player preferences
  Future<void> setPlayerBrightness(double brightness) async {
    await _channel.invokeMethod('setPlayerBrightness', {'brightness': brightness});
    _playerBrightness = brightness;
  }
  
  Future<void> setRememberPlayerBrightness(bool remember) async {
    await _channel.invokeMethod('setRememberPlayerBrightness', {'remember': remember});
    _rememberPlayerBrightness = remember;
  }
  
  Future<void> setSeekIncrement(int seconds) async {
    await _channel.invokeMethod('setSeekIncrement', {'seconds': seconds});
    _seekIncrement = seconds;
  }
  
  Future<void> setAutoHideTimeout(int seconds) async {
    await _channel.invokeMethod('setAutoHideTimeout', {'seconds': seconds});
    _controllerAutoHideTimeout = seconds;
  }
  
  // Picture-in-Picture
  Future<bool> enterPictureInPicture() async {
    try {
      final result = await _channel.invokeMethod('enterPictureInPicture');
      return result as bool;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> isPictureInPictureSupported() async {
    try {
      final result = await _channel.invokeMethod('isPictureInPictureSupported');
      return result as bool;
    } catch (e) {
      return false;
    }
  }
  
  // Background playback
  Future<void> setBackgroundPlayEnabled(bool enabled) async {
    await _channel.invokeMethod('setBackgroundPlayEnabled', {'enabled': enabled});
    _autoBackgroundPlay = enabled;
  }
  
  // State management
  Future<void> saveVideoState(String videoPath) async {
    await _channel.invokeMethod('saveVideoState', {
      'videoPath': videoPath,
      'position': _position.inMilliseconds,
      'zoom': _videoZoom.name,
      'speed': _playbackSpeed,
    });
  }
  
  Future<VideoState?> getVideoState(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('getVideoState', {'videoPath': videoPath});
      return result != null ? VideoState.fromMap(result) : null;
    } catch (e) {
      return null;
    }
  }
  
  void dispose() {
    _eventController.close();
    _stateController.close();
    _channel.invokeMethod('dispose');
  }
}

// Enums and data classes
enum VideoZoom { bestFit, stretch, crop, hundredPercent }
enum LoopMode { off, one, all }
enum FastSeek { auto, enable, disable }
enum DecoderPriority { preferDevice, preferApp, deviceOnly }
enum PlayerEvent { initialized, error, playbackSpeedChanged, videoZoomChanged, loopModeChanged }
enum PlayerState { idle, buffering, ready, playing, paused, ended }

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
  
  SubtitleTrack({
    required this.index,
    required this.language,
    required this.label,
    required this.isSelected,
  });
  
  factory SubtitleTrack.fromMap(Map<String, dynamic> map) {
    return SubtitleTrack(
      index: map['index'] ?? 0,
      language: map['language'] ?? '',
      label: map['label'] ?? '',
      isSelected: map['isSelected'] ?? false,
    );
  }
}

class VideoState {
  final Duration position;
  final VideoZoom zoom;
  final double speed;
  final DateTime lastPlayed;
  
  VideoState({
    required this.position,
    required this.zoom,
    required this.speed,
    required this.lastPlayed,
  });
  
  factory VideoState.fromMap(Map<String, dynamic> map) {
    return VideoState(
      position: Duration(milliseconds: map['position'] ?? 0),
      zoom: VideoZoom.values.firstWhere(
        (z) => z.name == map['zoom'],
        orElse: () => VideoZoom.bestFit,
      ),
      speed: map['speed']?.toDouble() ?? 1.0,
      lastPlayed: DateTime.fromMillisecondsSinceEpoch(map['lastPlayed'] ?? 0),
    );
  }
}