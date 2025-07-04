import 'dart:async';
import 'package:flutter/services.dart';
import 'gesture_controller.dart';
import 'video_state_manager.dart' as vsm;
import 'decoder_manager.dart' as dm;
import 'playback_speed_manager.dart' as psm;
import 'screen_orientation_manager.dart';
import 'advanced_player_controller.dart' as apc;
import 'audio_manager.dart';
import 'subtitle_manager.dart';
import 'track_selection_manager.dart';

/// NextPlayer Integration Manager
/// Central hub for all NextPlayer features and components
class NextPlayerIntegrationManager {
  static const MethodChannel _channel = MethodChannel('nextplayer_integration');
  
  // Core managers
  late final GestureController _gestureController;
  late final vsm.VideoStateManager _videoStateManager;
  late final dm.DecoderManager _decoderManager;
  late final psm.PlaybackSpeedManager _speedManager;
  late final ScreenOrientationManager _orientationManager;
  late final apc.AdvancedPlayerController _playerController;
  late final AudioManager _audioManager;
  late final SubtitleManager _subtitleManager;
  late final TrackSelectionManager _trackManager;
  
  // Integration state
  bool _isInitialized = false;
  String? _currentVideoPath;
  Duration _position = Duration.zero;
  
  // Event streams
  final StreamController<NextPlayerEvent> _eventController = 
      StreamController<NextPlayerEvent>.broadcast();
  
  Stream<NextPlayerEvent> get events => _eventController.stream;
  
  // Current position getter
  Duration get position => _position;
  
  // Getters for managers
  GestureController get gesture => _gestureController;
  vsm.VideoStateManager get videoState => _videoStateManager;
  dm.DecoderManager get decoder => _decoderManager;
  psm.PlaybackSpeedManager get speed => _speedManager;
  ScreenOrientationManager get orientation => _orientationManager;
  apc.AdvancedPlayerController get player => _playerController;
  AudioManager get audio => _audioManager;
  SubtitleManager get subtitle => _subtitleManager;
  TrackSelectionManager get tracks => _trackManager;
  
  bool get isInitialized => _isInitialized;
  String? get currentVideoPath => _currentVideoPath;
  
  NextPlayerIntegrationManager() {
    _initializeManagers();
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  void _initializeManagers() {
    _gestureController = GestureController();
    _videoStateManager = vsm.VideoStateManager();
    _decoderManager = dm.DecoderManager();
    _speedManager = psm.PlaybackSpeedManager();
    _orientationManager = ScreenOrientationManager();
    _playerController = apc.AdvancedPlayerController();
    _audioManager = AudioManager();
    _subtitleManager = SubtitleManager();
    _trackManager = TrackSelectionManager();
    
    _setupEventListeners();
  }
  
  void _setupEventListeners() {
    // Gesture events
    _gestureController.gestureEvents.listen((event) {
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.gesture,
        data: {'gestureEvent': event},
      ));
    });
    
    // Video state events
    _videoStateManager.stateStream.listen((state) {
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.stateChanged,
        data: {'videoState': state},
      ));
    });
    
    // Decoder events
    _decoderManager.decoderEvents.listen((event) {
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.decoder,
        data: {'decoderEvent': event},
      ));
    });
    
    // Speed events
    _speedManager.speedStream.listen((speed) {
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.speedChanged,
        data: {'speed': speed},
      ));
    });
    
    // Orientation events
    _orientationManager.orientationStream.listen((orientation) {
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.orientationChanged,
        data: {'orientation': orientation},
      ));
    });
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVideoLoaded':
        _currentVideoPath = call.arguments['videoPath'] as String?;
        await _onVideoLoaded();
        break;
      case 'onVideoUnloaded':
        await _onVideoUnloaded();
        _currentVideoPath = null;
        break;
      case 'onPlayerError':
        final error = call.arguments['error'] as String;
        _eventController.add(NextPlayerEvent(
          type: NextPlayerEventType.error,
          data: {'error': error},
        ));
        break;
    }
  }
  
  /// Initialize the integration manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize all managers
      await Future.wait([
        _gestureController.initialize(),
        _videoStateManager.initialize(),
        _decoderManager.initialize(),
        _speedManager.initialize(),
        _orientationManager.initialize(),
        _playerController.initialize(''),
        _audioManager.initialize(),
        _subtitleManager.initialize(),
        Future.value(), // TrackSelectionManager doesn't have initialize method
      ]);
      
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.initialized,
        data: {},
      ));
    } catch (e) {
      throw Exception('Failed to initialize NextPlayer integration: $e');
    }
  }
  
  /// Load a video file
  Future<void> loadVideo(String videoPath) async {
    try {
      await _channel.invokeMethod('loadVideo', {'videoPath': videoPath});
      _currentVideoPath = videoPath;
      await _onVideoLoaded();
    } catch (e) {
      throw Exception('Failed to load video: $e');
    }
  }
  
  /// Handle video loaded event
  Future<void> _onVideoLoaded() async {
    if (_currentVideoPath == null) return;
    
    try {
      // Restore video state if available
      final savedState = await _videoStateManager.getVideoState(_currentVideoPath!);
      if (savedState != null) {
        await _restoreVideoState(savedState);
      }
      
      // Get decoder info
      final decoderInfo = await _decoderManager.getDecoderInfo(_currentVideoPath!);
      
      // Setup orientation based on video dimensions
      // This would need video metadata to determine aspect ratio
      
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.videoLoaded,
        data: {
          'videoPath': _currentVideoPath,
          'decoderInfo': decoderInfo,
          'savedState': savedState,
        },
      ));
    } catch (e) {
      print('Error handling video loaded: $e');
    }
  }
  
  /// Handle video unloaded event
  Future<void> _onVideoUnloaded() async {
    if (_currentVideoPath == null) return;
    
    try {
      // Save current video state
      await _saveCurrentVideoState();
      
      _eventController.add(NextPlayerEvent(
        type: NextPlayerEventType.videoUnloaded,
        data: {'videoPath': _currentVideoPath},
      ));
    } catch (e) {
      print('Error handling video unloaded: $e');
    }
  }
  
  /// Restore video state
  Future<void> _restoreVideoState(vsm.VideoState state) async {
    try {
      // Restore playback position
      await _playerController.seekTo(state.position);
      
      // Restore playback speed
      await _speedManager.setSpeed(state.playbackSpeed);
      
      // Restore video zoom - convert between VideoZoom types
      await _playerController.setVideoZoom(apc.VideoZoom.bestFit); // Default for now
      
      // Restore audio track
      if (state.audioTrack >= 0) {
        await _audioManager.switchAudioTrack(state.audioTrack);
      }
      
      // Restore subtitle track
      if (state.subtitleTrack >= 0) {
        await _subtitleManager.switchSubtitleTrack(state.subtitleTrack);
      }
      
      // Restore brightness if enabled
      if (_videoStateManager.rememberPlayerBrightness && state.brightness > 0) {
        _gestureController.applyBrightness(state.brightness);
      }
    } catch (e) {
      print('Error restoring video state: $e');
    }
  }
  
  /// Save current video state
  Future<void> _saveCurrentVideoState() async {
    if (_currentVideoPath == null) return;
    
    try {
      await _videoStateManager.updateVideoState(
        _currentVideoPath!,
        position: _playerController.position,
        playbackSpeed: _speedManager.currentSpeed,
        videoZoom: vsm.VideoZoom.bestFit, // Convert from player controller
        audioTrack: (_trackManager.selectedAudioTrack is int) ? _trackManager.selectedAudioTrack as int : -1,
        subtitleTrack: (_trackManager.selectedSubtitleTrack is int) ? _trackManager.selectedSubtitleTrack as int : -1,
        brightness: _gestureController.currentBrightness,
      );
    } catch (e) {
      print('Error saving video state: $e');
    }
  }
  
  /// Apply NextPlayer preferences
  Future<void> applyPreferences(NextPlayerPreferences preferences) async {
    try {
      // Apply gesture preferences
      // Note: Individual gesture control methods need to be implemented in GestureController
      // For now, we'll skip these specific method calls
      // TODO: Implement setSwipeControls, setSeekControls, setZoomControls in GestureController
      
      await _gestureController.setDoubleTapGesture(preferences.doubleTapGesture);
      
      // Apply decoder preferences
      await _decoderManager.setDecoderPriority(preferences.decoderPriority);
      await _decoderManager.setHardwareAcceleration(preferences.useHardwareAcceleration);
      
      // Apply speed preferences
      await _speedManager.setRememberSpeed(preferences.rememberSpeed);
      await _speedManager.setFastSeek(preferences.fastSeek);
      await _speedManager.setLongPressSpeed(preferences.longPressSpeed);
      
      // Apply orientation preferences
      await _orientationManager.setOrientation(preferences.screenOrientation);
      await _orientationManager.setAutoRotateEnabled(preferences.autoRotate);
      
      // Apply video state preferences
      // Note: Resume mode is now a string, convert if needed
      // await _videoStateManager.setResumeMode(preferences.resumeMode);
      await _videoStateManager.setRememberSelections(preferences.rememberSelections);
      await _videoStateManager.setRememberPlayerBrightness(preferences.rememberPlayerBrightness);
      
      // Apply audio preferences
      await _audioManager.setSkipSilenceEnabled(preferences.skipSilence);
      await _audioManager.setVolumeBoostEnabled(preferences.volumeBoost);
      await _audioManager.setPreferredAudioLanguage(preferences.preferredAudioLanguage);
      
      // Apply subtitle preferences
      await _subtitleManager.setPreferredSubtitleLanguage(preferences.preferredSubtitleLanguage);
      await _subtitleManager.setUseSystemCaptionStyle(preferences.useSystemCaptionStyle);
      
    } catch (e) {
      throw Exception('Failed to apply preferences: $e');
    }
  }
  
  /// Get current NextPlayer preferences
  NextPlayerPreferences getCurrentPreferences() {
    return NextPlayerPreferences(
      // Gesture preferences
      useSwipeControls: _gestureController.useSwipeControls,
      useSeekControls: _gestureController.useSeekControls,
      useZoomControls: _gestureController.useZoomControls,
      useLongPressControls: _gestureController.useLongPressControls,
      doubleTapGesture: _gestureController.doubleTapGesture,
      
      // Decoder preferences
      decoderPriority: _decoderManager.decoderPriority,
      useHardwareAcceleration: _decoderManager.useHardwareAcceleration,
      
      // Speed preferences
      rememberSpeed: _speedManager.rememberSpeed,
      fastSeek: _speedManager.fastSeek,
      longPressSpeed: _speedManager.longPressSpeed,
      
      // Orientation preferences
      screenOrientation: _orientationManager.orientation,
      autoRotate: _orientationManager.autoRotateEnabled,
      
      // Video state preferences
      resumeMode: 'yes', // Default string value
      rememberSelections: _videoStateManager.rememberSelections,
      rememberPlayerBrightness: _videoStateManager.rememberPlayerBrightness,
      
      // Audio preferences
      skipSilence: _audioManager.skipSilenceEnabled,
      volumeBoost: _audioManager.volumeBoostEnabled,
      preferredAudioLanguage: _audioManager.preferredAudioLanguage,
      
      // Subtitle preferences
      preferredSubtitleLanguage: _subtitleManager.preferredSubtitleLanguage,
      useSystemCaptionStyle: _subtitleManager.useSystemCaptionStyle,
    );
  }
  
  /// Switch audio track
  Future<void> switchAudioTrack(int trackIndex) async {
    await _audioManager.switchAudioTrack(trackIndex);
  }
  
  /// Switch subtitle track
  Future<void> switchSubtitleTrack(int trackIndex) async {
    await _subtitleManager.switchSubtitleTrack(trackIndex);
  }
  
  void dispose() {
    _gestureController.dispose();
    _videoStateManager.dispose();
    _decoderManager.dispose();
    _speedManager.dispose();
    _orientationManager.dispose();
    _playerController.dispose();
    _audioManager.dispose();
    _subtitleManager.dispose();
    _trackManager.dispose();
    _eventController.close();
  }
}

/// NextPlayer Event Types
enum NextPlayerEventType {
  initialized,
  videoLoaded,
  videoUnloaded,
  stateChanged,
  gesture,
  decoder,
  speedChanged,
  orientationChanged,
  error,
}

/// NextPlayer Event
class NextPlayerEvent {
  final NextPlayerEventType type;
  final Map<String, dynamic> data;
  
  const NextPlayerEvent({
    required this.type,
    required this.data,
  });
  
  @override
  String toString() => 'NextPlayerEvent(type: $type, data: $data)';
}

/// NextPlayer Preferences
class NextPlayerPreferences {
  // Gesture preferences
  final bool useSwipeControls;
  final bool useSeekControls;
  final bool useZoomControls;
  final bool useLongPressControls;
  final DoubleTapGesture doubleTapGesture;
  
  // Decoder preferences
  final dm.DecoderPriority decoderPriority;
  final bool useHardwareAcceleration;
  
  // Speed preferences
  final bool rememberSpeed;
  final psm.FastSeek fastSeek;
  final double longPressSpeed;
  
  // Orientation preferences
  final ScreenOrientation screenOrientation;
  final bool autoRotate;
  
  // Video state preferences
  final String resumeMode;
  final bool rememberSelections;
  final bool rememberPlayerBrightness;
  
  // Audio preferences
  final bool skipSilence;
  final bool volumeBoost;
  final String preferredAudioLanguage;
  
  // Subtitle preferences
  final String preferredSubtitleLanguage;
  final bool useSystemCaptionStyle;
  
  const NextPlayerPreferences({
    this.useSwipeControls = true,
    this.useSeekControls = true,
    this.useZoomControls = true,
    this.useLongPressControls = false,
    this.doubleTapGesture = DoubleTapGesture.both,
    this.decoderPriority = dm.DecoderPriority.preferDevice,
    this.useHardwareAcceleration = true,
    this.rememberSpeed = false,
    this.fastSeek = psm.FastSeek.auto,
    this.longPressSpeed = 2.0,
    this.screenOrientation = ScreenOrientation.auto,
    this.autoRotate = true,
    this.resumeMode = 'yes',
    this.rememberSelections = true,
    this.rememberPlayerBrightness = false,
    this.skipSilence = false,
    this.volumeBoost = false,
    this.preferredAudioLanguage = "",
    this.preferredSubtitleLanguage = "",
    this.useSystemCaptionStyle = false,
  });
}