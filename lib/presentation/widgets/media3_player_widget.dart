import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/platform/media3_player_controller.dart';
import 'package:flutter/foundation.dart';
// Brightness control without external dependency
import '../../core/platform/media3_player_controller.dart';
import 'subtitle_tracks_dialog.dart';
import 'video_settings_dialog.dart';
import 'player/player_gesture_controls.dart';
import 'player/player_controls.dart';
import 'player/player_settings_panel.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';



/// Media3 Player Widget - Enhanced implementation with comprehensive controls
class Media3PlayerWidget extends StatefulWidget {
  final String videoPath;
  final String? videoTitle;
  final bool autoPlay;
  final Duration? startPosition;
  final VoidCallback? onBack;
  final Function(Duration)? onPositionChanged;
  final Function(Duration)? onBookmarkAdded;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onVideoCompleted;
  final bool showControls;

  const Media3PlayerWidget({
    super.key,
    required this.videoPath,
    this.videoTitle,
    this.autoPlay = true,
    this.startPosition,
    this.onBack,
    this.onPositionChanged,
    this.onBookmarkAdded,
    this.onNext,
    this.onPrevious,
    this.onVideoCompleted,
    this.showControls = true,
  });

  @override
  State<Media3PlayerWidget> createState() => _Media3PlayerWidgetState();
}

class _Media3PlayerWidgetState extends State<Media3PlayerWidget>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // Enum for Zoom Modes
  late Size _videoSize = Size.zero; // Store actual video dimensions

  Media3PlayerController? _controller;
  late StreamSubscription _playingSubscription;
  late StreamSubscription _bufferingSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _errorSubscription;
  late StreamSubscription _initializedSubscription;
  late StreamSubscription _performanceSubscription;
  late StreamSubscription _tracksSubscription;
  
  // UI State
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isInitialized = false;
  bool _showBufferingIndicator = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  
  // Brightness control state
  double _currentBrightness = 0.5;
  Timer? _brightnessDebounceTimer;
  
  // Volume control state
  double _currentVolume = 0.5;
  
  // Temporary state for seekbar dragging
  Duration? _draggingPosition;
  
  // Enhanced UI State
  bool _showControls = true;
  ZoomMode _currentZoomMode = ZoomMode.fit; // Default zoom mode
  bool _showSettings = false;
  bool _showSpeedMenu = false;
  bool _showVolumeSlider = false;
  double _currentSpeed = 1.0;
  bool _isMuted = false;
  int _bufferedPercentage = 0;
  bool _canDismissSettings = false; // Grace period flag
  
  // Zoom and pan state
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  Offset _panOffset = Offset.zero;
  bool _isZoomed = false; // This will now be primarily driven by _scaleFactor != 1.0 || _panOffset != Offset.zero
  
  // Animation controllers
  late AnimationController _controlsAnimationController;
  
  // Volume listener for system volume changes
  StreamSubscription<double>? _volumeSubscription;
  late AnimationController _settingsAnimationController;
  late Animation<double> _controlsOpacity;
  late Animation<double> _settingsSlideAnimation;
  
  // Track information
  List<Map<String, dynamic>> _videoTracks = [];
  List<Map<String, dynamic>> _audioTracks = [];
  List<Map<String, dynamic>> _subtitleTracks = [];
  int? _currentAudioTrackIndex; // To store the currently selected audio track index
  int? _currentSubtitleTrackIndex; // To store the currently selected subtitle track index
  
  // Audio tracks from current video for music panel
  List<Map<String, dynamic>> _videoAudioTracks = [];
  
  // Performance monitoring
  Map<String, dynamic> _performanceData = {};
  String? _zoomModeToastMessage; // For displaying zoom mode name
  Timer? _zoomModeToastTimer;   // Timer for the toast message
  
  // Timer for auto-hiding controls
  Timer? _controlsTimer;
  
  // Timer for auto-clearing temporary errors
  Timer? _errorClearTimer;
  
  // Timer for buffering indicator delay
  Timer? _bufferingTimer;
  
  // Timer for periodic track detection
  Timer? _trackDetectionTimer;

  // Timer for zoom indicator auto-hide
  Timer? _zoomIndicatorTimer;
  bool _showZoomIndicator = false;
  
  // Timer for zoom indicator auto-hide
  
  // Picture-in-Picture state
  bool _isPipSupported = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('[INIT] Initializing player widget...');
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    // Hide system volume UI
    FlutterVolumeController.updateShowSystemUI(false);
    _initializeBrightness();
    _initializeVolume();
    _initializePlayer();
    _startControlsTimer();
    _enableWakeLock();
    _checkPipSupport();
    debugPrint('[INIT] Player widget initialization complete');
  }
  
  Future<void> _fetchAndUpdateCurrentAudioTrackIndex() async {
    if (_controller != null && mounted) {
      final currentIndex = await _controller!.getSelectedAudioTrackIndex();
      if (mounted) {
        setState(() {
          _currentAudioTrackIndex = currentIndex;
          debugPrint('[_Media3PlayerWidgetState] Fetched current audio track index: $_currentAudioTrackIndex');
        });
      }
    }
  }

  void _startTrackDetectionTimer() {
    if (!_isInitialized) return;
    
    debugPrint('[_Media3PlayerWidgetState] Starting periodic track detection timer');
    _trackDetectionTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!_isInitialized || _controller == null) {
        timer.cancel();
        return;
      }
      
      try {
        final tracks = await _controller!.getTracks();
        final audioTracks = tracks?['audioTracks'] as List? ?? [];
        
        if (audioTracks.isNotEmpty) {
          debugPrint('[_Media3PlayerWidgetState] Track detection timer: Found ${audioTracks.length} audio tracks');
          timer.cancel(); // Stop timer once tracks are found
          
          // Update UI with found tracks
          if (mounted) {
            setState(() {
              _audioTracks = audioTracks.cast<Map<String, dynamic>>();
            });
          }
          
          _processVideoAudioTracks();
        } else {
          debugPrint('[_Media3PlayerWidgetState] Track detection timer: Still waiting for audio tracks...');
          
          // Try to refresh tracks
          await _controller!.refreshTracks();
        }
      } catch (e) {
        debugPrint('[_Media3PlayerWidgetState] Error in track detection timer: $e');
      }
    });
    
    // Cancel timer after 30 seconds to avoid infinite polling
    Timer(Duration(seconds: 30), () {
      _trackDetectionTimer?.cancel();
      debugPrint('[_Media3PlayerWidgetState] Track detection timer cancelled after 30 seconds');
    });
  }

  void _stopTrackDetectionTimer() {
    _trackDetectionTimer?.cancel();
    _trackDetectionTimer = null;
  }
  
  Future<void> _checkPipSupport() async {
    if (_controller != null) {
      _isPipSupported = await _controller!.isPictureInPictureSupported();
      if (mounted) setState(() {});
      debugPrint('[PIP] Picture-in-Picture supported: $_isPipSupported');
    }
  }
  
  Future<void> _enterPictureInPicture() async {
    if (!_isPipSupported || _controller == null) {
      debugPrint('[PIP] PiP not supported on this device');
      return;
    }
    
    bool success = await _controller!.enterPictureInPicture();
    if (success) {
      debugPrint('[PIP] Successfully entered Picture-in-Picture mode');
    } else {
      debugPrint('[PIP] Failed to enter Picture-in-Picture mode');
      // Show user feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picture-in-Picture mode not available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250), // Smooth duration
      vsync: this,
    );
    _settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Slightly longer for settings
      vsync: this,
    );
    
    _controlsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut, // Smooth in and out
      reverseCurve: Curves.easeInOut, // Smooth reverse animation
    ));
    
    _settingsSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeInOut, // Smooth slide animation
      reverseCurve: Curves.easeInOut,
    ));
    
    _controlsAnimationController.forward();
  }
  

// Enum for Zoom Modes

  void _initializePlayer([int? viewId]) async {
    debugPrint('[_Media3PlayerWidgetState] _initializePlayer called with viewId: $viewId');
    if (viewId != null) {
      _controller = Media3PlayerController(viewId: viewId);
      debugPrint('[_Media3PlayerWidgetState] Media3PlayerController initialized.');
      _setupEventListeners();
      _initializeSystemVolume();
      _listenToSystemVolumeChanges();
      
      // Using Flutter custom UI controls (not native)
      
      // Add delay to ensure tracks are processed after initialization
      await Future.delayed(const Duration(milliseconds: 500));
      _fetchAndUpdateCurrentAudioTrackIndex();
      _processVideoAudioTracks();
      _startTrackDetectionTimer();
      
      debugPrint('[_Media3PlayerWidgetState] Player initialization complete with track processing');
    } else {
      debugPrint('[_Media3PlayerWidgetState] viewId is null, controller not initialized.');
    }
  }
  
  void _setupEventListeners() {
    if (_controller == null) {
      debugPrint('[SETUP] _setupEventListeners: Controller is null, cannot setup listeners.');
      return;
    }
    debugPrint('[SETUP] Setting up event listeners...');
    
    _playingSubscription = _controller!.onPlayingChanged.listen((isPlaying) {
      debugPrint('[_Media3PlayerWidgetState] Event: onPlayingChanged received: isPlaying=$isPlaying. Current state: _isPlaying=$_isPlaying');
      if (!mounted) return;
      setState(() {
        _isPlaying = isPlaying;
        debugPrint('[_Media3PlayerWidgetState] setState: _isPlaying set to $_isPlaying');
      });
      
      // If playing started, hide controls after delay
      if (isPlaying && _showControls) {
        _startControlsTimer();
      }
      
      // Ensure wake lock is active when video is playing
      if (isPlaying) {
        _enableWakeLock();
        debugPrint('[WAKE_LOCK] Video started playing - wake lock reinforced');
      }
    });
    
    // Listen for playback state changes to detect completion
    _controller!.onPerformanceUpdate.listen((data) {
      if (data['type'] == 'playbackStateChanged' && data['state'] == 'ENDED') {
        debugPrint('[_Media3PlayerWidgetState] Video completed (ENDED state)');
        if (widget.onVideoCompleted != null) {
           widget.onVideoCompleted!();
        } else if (widget.onNext != null) {
           // Default behavior: if onVideoCompleted is not provided but onNext is, call onNext
           widget.onNext!();
        }
      }
    });
    
    _bufferingSubscription = _controller!.onBufferingChanged.listen((isBuffering) {
      debugPrint('[_Media3PlayerWidgetState] Event: onBufferingChanged received: isBuffering=$isBuffering. Current state: _isBuffering=$_isBuffering');
      if (!mounted) return;
      // UI logic for _showBufferingIndicator handles setState internally after a delay
      // _isBuffering = isBuffering; // Update internal state immediately - setState below handles it.

      _bufferingTimer?.cancel();
      if (isBuffering) {
        _bufferingTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && _isBuffering) { // Check _isBuffering again in case it changed quickly
            setState(() {
              _showBufferingIndicator = true;
              debugPrint('[_Media3PlayerWidgetState] setState: _showBufferingIndicator set to true');
            });
          }
        });
      } else {
        // If it was buffering and now it's not, ensure indicator is hidden
        if (_showBufferingIndicator) {
           setState(() {
            _showBufferingIndicator = false;
            debugPrint('[_Media3PlayerWidgetState] setState: _showBufferingIndicator set to false');
          });
        }
      }
    });
    
    _positionSubscription = _controller!.onPositionChanged.listen((positionData) {
      final newPosition = positionData['position'] ?? Duration.zero;
      final newDuration = positionData['duration'] ?? Duration.zero;
      // debugPrint('[_Media3PlayerWidgetState] Event: onPositionChanged received: position=${newPosition.inSeconds}s, duration=${newDuration.inSeconds}s. Current state: _position=${_position.inSeconds}s, _duration=${_duration.inSeconds}s');
      if (!mounted) return;
      setState(() {
        _position = newPosition;
        _duration = newDuration;
        // debugPrint('[_Media3PlayerWidgetState] setState: _position set to ${_position.inSeconds}s, _duration set to ${_duration.inSeconds}s');
      });
      widget.onPositionChanged?.call(_position);
    });
    
    _errorSubscription = _controller!.onError.listen((error) {
      debugPrint('[_Media3PlayerWidgetState] Event: onError received: $error');
      if (!mounted) return;
      setState(() {
        _error = error;
      });
      
      if (error != null && _shouldShowErrorDialog(error)) {
        _showErrorDialog(error);
      } else if (error != null) {
        _errorClearTimer?.cancel();
        _errorClearTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _error = null;
            });
          }
        });
      }
    });
    
    _initializedSubscription = _controller!.onInitialized.listen((_) {
      debugPrint('[_Media3PlayerWidgetState] Event: onInitialized received. Current state: _isInitialized=$_isInitialized');
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        debugPrint('[_Media3PlayerWidgetState] setState: _isInitialized set to true');
      });
    });
    
    _performanceSubscription = _controller!.onPerformanceUpdate.listen((data) {
      // This is mostly for debug or advanced metrics, less critical for core controls.
      // debugPrint('[_Media3PlayerWidgetState] Event: onPerformanceUpdate received: $data');
      if (!mounted) return;
      setState(() {
        _performanceData = data;
        if (data['bufferedPercentage'] != null) {
          _bufferedPercentage = data['bufferedPercentage'];
        }
        // Store video size when it's available in performance data or a specific event
        // For now, we'll rely on onVideoSizeChanged from the controller.
      });
    });

    // Listener for video size changes
    _controller!.onVideoSizeChanged.listen((videoSizeData) {
      debugPrint('[_Media3PlayerWidgetState] Event: onVideoSizeChanged received: $videoSizeData');
      if (!mounted) return;
      setState(() {
        _videoSize = Size(
          (videoSizeData['width'] as int?)?.toDouble() ?? 0.0,
          (videoSizeData['height'] as int?)?.toDouble() ?? 0.0,
        );
        debugPrint('[_Media3PlayerWidgetState] setState: _videoSize set to $_videoSize');
      });
    });
    
    _tracksSubscription = _controller!.onTracksChanged.listen((data) {
      debugPrint('[TRACKS] ===== TRACKS CHANGED EVENT =====');
      debugPrint('[TRACKS] Video: ${(data['videoTracks'] as List).length}, Audio: ${(data['audioTracks'] as List).length}, Subtitle: ${(data['subtitleTracks'] as List).length}');
      debugPrint('[TRACKS] Raw audio tracks data: ${data['audioTracks']}');
      if (!mounted) return;
      
      final newVideoTracks = _convertToMapList(data['videoTracks']);
      final newAudioTracks = _convertToMapList(data['audioTracks']);
      final newSubtitleTracks = _convertToMapList(data['subtitleTracks']);
      
      // Update selected indices based on track data
      int? newAudioIndex;
      for (int i = 0; i < newAudioTracks.length; i++) {
        if (newAudioTracks[i]['isSelected'] == true) {
          newAudioIndex = i;
          break;
        }
      }

      int? newSubtitleIndex;
      for (int i = 0; i < newSubtitleTracks.length; i++) {
        if (newSubtitleTracks[i]['isSelected'] == true) {
          newSubtitleIndex = i;
          break;
        }
      }

      setState(() {
        _videoTracks = newVideoTracks;
        _audioTracks = newAudioTracks;
        _subtitleTracks = newSubtitleTracks;
        _currentAudioTrackIndex = newAudioIndex;
        _currentSubtitleTrackIndex = newSubtitleIndex;
      });
      
      debugPrint('[TRACKS] After setState: _audioTracks.length = ${_audioTracks.length}');
      debugPrint('[TRACKS] _audioTracks content: $_audioTracks');
      
      // Process tracks with a small delay to ensure state is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // When tracks change, re-fetch the current audio track index
          _fetchAndUpdateCurrentAudioTrackIndex();
          // Process audio tracks for the music panel
          _processVideoAudioTracks();
          debugPrint('[TRACKS] Track processing completed. Final audio tracks: ${_audioTracks.length}');
          debugPrint('[TRACKS] ===== END TRACKS PROCESSING =====');
        }
      });
    });
    
    // Native controls disabled - using Flutter custom UI
    
    debugPrint('[_Media3PlayerWidgetState] _setupEventListeners: Listeners setup complete.');
  }
  
  void _togglePlayPause() {
    debugPrint('[_Media3PlayerWidgetState] _togglePlayPause called. Current _isPlaying state: $_isPlaying');
    if (_controller == null) {
      debugPrint('[_Media3PlayerWidgetState] _togglePlayPause: Controller is null. Cannot proceed.');
      return;
    }
    
    if (_isPlaying) {
      debugPrint('[_Media3PlayerWidgetState] _togglePlayPause: Calling controller.pause()');
      _controller!.pause();
    } else {
      debugPrint('[_Media3PlayerWidgetState] _togglePlayPause: Calling controller.play()');
      _controller!.play();
    }
    // Note: The actual _isPlaying state will be updated by the onPlayingChanged event from the controller.
    // We don't optimistically set it here to ensure UI reflects the true player state.
    _resetControlsTimer();
  }
  
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (_showControls && _isPlaying) {
        _hideControls();
      }
    });
  }
  
  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (_isPlaying) {
      _startControlsTimer();
    }
  }

  // Brightness control methods
  static const MethodChannel _brightnessChannel = MethodChannel('com.sundeep.kjvideoplayer/brightness');
  
  Future<void> _initializeBrightness() async {
    try {
      // Try to get current system brightness using custom channel
      final currentBrightness = await _brightnessChannel.invokeMethod<double>('getBrightness');
      if (currentBrightness != null) {
        _currentBrightness = currentBrightness;
        debugPrint('[BRIGHTNESS] Brightness control initialized with system brightness: $currentBrightness');
      } else {
        throw Exception('Failed to get brightness from native');
      }
    } catch (e) {
      // Fallback: try to get current window brightness
      try {
        final windowBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? 0.3 : 0.7;
        _currentBrightness = windowBrightness;
        debugPrint('[BRIGHTNESS] Using platform brightness fallback: $windowBrightness');
      } catch (e2) {
        // Final fallback to default
        _currentBrightness = 0.5;
        debugPrint('[BRIGHTNESS] Using default brightness: $e2');
      }
    }
  }

  // Volume control methods
  Future<void> _initializeVolume() async {
    // Initialize with default volume
    _currentVolume = 0.5;
    debugPrint('[VOLUME] Volume control initialized');
  }



  
  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsUI();
    }
  }
  
  void _showControlsUI() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();
    _resetControlsTimer();
  }
  
  void _hideControls() {
    if (!mounted) return;
    setState(() {
      _showControls = false;
      _showSettings = false;
      _showSpeedMenu = false;
      _showVolumeSlider = false;
    });
    _controlsAnimationController.reverse();
    _settingsAnimationController.reverse();
  }
  
  void _changePlaybackSpeed(double speed) {
    debugPrint('[_Media3PlayerWidgetState] _changePlaybackSpeed called with speed: $speed');
    if (_controller == null) {
      debugPrint('[_Media3PlayerWidgetState] _changePlaybackSpeed: Controller is null.');
      return;
    }
    _controller!.setPlaybackSpeed(speed);
    // Optimistically update UI, or wait for confirmation if player provides it
    if (!mounted) return;
    setState(() {
      _currentSpeed = speed;
      _showSpeedMenu = false;
    });
    _resetControlsTimer();
  }
  
  void _changeVolume(double volume) {
    debugPrint('[_Media3PlayerWidgetState] _changeVolume called with volume: $volume');
    if (_controller == null) {
      debugPrint('[_Media3PlayerWidgetState] _changeVolume: Controller is null.');
      return;
    }
    
    // Set system volume first
    _controller!.setSystemVolume(volume);
    
    // Player volume should be 1.0 unless muted
    _controller!.setVolume(volume <= 0.0 ? 0.0 : 1.0);
    
    // Update UI state
    if (!mounted) return;
    setState(() {
      _currentVolume = volume;
      _isMuted = volume <= 0.0;
    });
    
    debugPrint('[_Media3PlayerWidgetState] Volume changed - System: $volume, Player: ${volume <= 0.0 ? 0.0 : 1.0}, Muted: $_isMuted');
  }
  
  void _initializeSystemVolume() async {
    try {
      // Get current system volume using Media3
      if (_controller != null) {
        double systemVolume = await _controller!.getSystemVolume();
        if (mounted) {
          setState(() {
            _currentVolume = systemVolume;
            // Update mute state based on initial volume level
            _isMuted = systemVolume <= 0.0;
          });
          // Set player volume to 1.0 unless muted - system volume controls actual output
          _controller!.setVolume(_isMuted ? 0.0 : 1.0);
        }
        debugPrint('[_Media3PlayerWidgetState] Initialized - System volume: $systemVolume, Player volume: ${_isMuted ? 0.0 : 1.0}, Muted: $_isMuted');
      }
    } catch (e) {
      debugPrint('[_Media3PlayerWidgetState] Failed to get system volume: $e');
      // Use default volume
      if (mounted) {
        setState(() {
          _currentVolume = 0.7;
          _isMuted = false;
        });
        // Set player volume to 1.0 for default case
        _controller?.setVolume(1.0);
      }
    }
  }
  
  void _toggleMute() {
    if (_controller == null) return;
    
    setState(() {
      _isMuted = !_isMuted;
    });
    
    // Set player volume based on mute state
    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    
    // If unmuting and current volume is 0, set to a reasonable level
    if (!_isMuted && _currentVolume <= 0.0) {
      _changeVolume(0.5); // Set to 50% when unmuting from 0
    } else if (_isMuted) {
      // When muting, set system volume to 0
      _controller!.setSystemVolume(0.0);
      setState(() {
        _currentVolume = 0.0;
      });
    }
    
    debugPrint('[_Media3PlayerWidgetState] Mute toggled: $_isMuted, player volume: ${_isMuted ? 0.0 : 1.0}');
  }
  
  void _listenToSystemVolumeChanges() {
    try {
      // Listen to system volume changes using Media3
      if (_controller != null) {
        _volumeSubscription = _controller!.onSystemVolumeChanged.listen((volume) {
          if (!mounted) return;
          final wasMuted = _isMuted;
          final newMuted = volume <= 0.0;
          setState(() {
            _currentVolume = volume;
            _isMuted = newMuted;
          });
          // Only update player volume if mute state changed, to avoid feedback loop
          if (wasMuted != newMuted) {
            _controller!.setVolume(newMuted ? 0.0 : 1.0);
          }
          debugPrint('[_Media3PlayerWidgetState] System volume changed to: $volume, isMuted: $_isMuted, player volume set to: ${_isMuted ? 0.0 : 1.0}');
        });
      }
    } catch (e) {
      debugPrint('[_Media3PlayerWidgetState] Failed to listen to system volume: $e');
    }
  }
  
  void _seekForward() {
    debugPrint('[_Media3PlayerWidgetState] _seekForward called. Current position: $_position, duration: $_duration');
    if (_controller == null || _duration == Duration.zero) {
      debugPrint('[_Media3PlayerWidgetState] _seekForward: Controller is null or duration is zero.');
      return;
    }
    final newPosition = _position + const Duration(seconds: 10);
    final targetPosition = newPosition > _duration ? _duration : newPosition;
    debugPrint('[_Media3PlayerWidgetState] _seekForward: Seeking to $targetPosition');
    _controller!.seekTo(targetPosition);
    // Optimistically update position for smoother UI, actual update comes from onPositionChanged
    if (!mounted) return;
    // setState(() { _position = targetPosition; }); // Optional: for immediate UI feedback
    _resetControlsTimer();
  }
  
  void _seekBackward() {
    debugPrint('[_Media3PlayerWidgetState] _seekBackward called. Current position: $_position');
    if (_controller == null) {
      debugPrint('[_Media3PlayerWidgetState] _seekBackward: Controller is null.');
      return;
    }
    final newPosition = _position - const Duration(seconds: 10);
    final targetPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
    debugPrint('[_Media3PlayerWidgetState] _seekBackward: Seeking to $targetPosition');
    _controller!.seekTo(targetPosition);
    // Optimistically update position for smoother UI
    if (!mounted) return;
    // setState(() { _position = targetPosition; }); // Optional: for immediate UI feedback
    _resetControlsTimer();
  }
  
  void _addBookmark() {
    debugPrint('[_Media3PlayerWidgetState] _addBookmark called at position: $_position');
    widget.onBookmarkAdded?.call(_position);
    _resetControlsTimer();
  }
  
  
  // Combined gesture handlers
  

  // Zoom and pan gesture handlers
  
  void _showZoomIndicatorWithTimer() {
    // Cancel existing timer
    _zoomIndicatorTimer?.cancel();
    
    // Show zoom indicator
    if (!_showZoomIndicator) {
      setState(() {
        _showZoomIndicator = true;
      });
    }
    
    // Hide zoom indicator after 3 seconds
    _zoomIndicatorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showZoomIndicator = false;
        });
      }
    });
  }
  
  void _resetZoom({bool switchToFit = true}) {
    debugPrint('[_Media3PlayerWidgetState] _resetZoom called. switchToFit: $switchToFit');
    if (!mounted) return;
    setState(() {
      _scaleFactor = 1.0;
      _baseScaleFactor = 1.0;
      _panOffset = Offset.zero;
      _isZoomed = false; // Explicitly false after reset
      if (switchToFit) {
        _currentZoomMode = ZoomMode.fit;
        _controller?.setResizeMode('fit');
        _showZoomToast('Fit to Screen');
        debugPrint('[_Media3PlayerWidgetState] Zoom reset to FIT. Scale: $_scaleFactor');
      }
    });
  }

  void _showZoomToast(String message) {
    if (!mounted) return;
    setState(() {
      _zoomModeToastMessage = message;
    });
    _zoomModeToastTimer?.cancel();
    _zoomModeToastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _zoomModeToastMessage = null;
        });
      }
    });
  }

  void _cycleZoomMode() {
    debugPrint('[_Media3PlayerWidgetState] _cycleZoomMode called. Current mode: $_currentZoomMode');
    if (!mounted) return;

    ZoomMode nextMode;
    String nativeModeString;

    switch (_currentZoomMode) {
      case ZoomMode.fit:
        nextMode = ZoomMode.stretch;
        nativeModeString = 'stretch';
        break;
      case ZoomMode.stretch:
        nextMode = ZoomMode.zoomToFill;
        nativeModeString = 'zoomToFill';
        break;
      case ZoomMode.zoomToFill:
        nextMode = ZoomMode.fit;
        nativeModeString = 'fit';
        break;
      case ZoomMode.custom: // If currently custom (pinch-zoomed), cycling starts from fit
        nextMode = ZoomMode.fit;
        nativeModeString = 'fit';
        break;
    }

    setState(() { // Initial setState to update mode and reset scale/pan
      _currentZoomMode = nextMode;
      _scaleFactor = 1.0;
      _baseScaleFactor = 1.0;
      _panOffset = Offset.zero;
      _isZoomed = false;
    });
    _controller?.setResizeMode(nativeModeString);
    _showZoomToast(nativeModeString); // Show toast after mode is set

    debugPrint('[_Media3PlayerWidgetState] Zoom mode cycled to: $_currentZoomMode, native mode: $nativeModeString');
    _resetControlsTimer();
  }
  
  bool _shouldShowErrorDialog(String error) {
    // Don't show dialog for temporary network issues or minor errors
    final lowercaseError = error.toLowerCase();
    
    // Skip common temporary errors
    if (lowercaseError.contains('network') ||
        lowercaseError.contains('timeout') ||
        lowercaseError.contains('buffering') ||
        lowercaseError.contains('loading') ||
        lowercaseError.contains('temporary')) {
      return false;
    }
    
    // Only show for critical errors
    return lowercaseError.contains('failed') ||
           lowercaseError.contains('corrupt') ||
           lowercaseError.contains('unsupported') ||
           lowercaseError.contains('not found');
  }
  
  void _showErrorDialog(String error) {
    // Prevent multiple error dialogs
    if (Navigator.of(context).canPop()) {
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Playback Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear error state when dialog is dismissed
              setState(() {
                _error = null;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for proper resource management
    switch (state) {
      case AppLifecycleState.paused:
        _controller?.pause();
        break;
      case AppLifecycleState.resumed:
        // Player will resume automatically if it was playing
        break;
      default:
        break;
    }
  }
  
  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media3 Platform View with zoom and pan support
          ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translate(_panOffset.dx, _panOffset.dy)
                ..scale(_scaleFactor),
              alignment: Alignment.center,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: AndroidView(
                  viewType: 'media3_player_view',
                  creationParams: {
                    'videoPath': widget.videoPath,
                    'autoPlay': widget.autoPlay,
                    'startPosition': widget.startPosition?.inMilliseconds,
                    'useBuiltInControls': false,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: (int id) {
                    _initializePlayer(id);
                  },
                ),
              ),
            ),
          ),

          // Gesture Controls Overlay
          if (!_showSettings)
            Positioned.fill(
              child: PlayerGestureControls(
                currentVolume: _currentVolume,
                currentBrightness: _currentBrightness,
                currentScale: _scaleFactor,
                onVolumeChanged: _changeVolume,
                onBrightnessChanged: _setBrightness,
                onZoomChanged: (scale, pan) {
                  setState(() {
                    _scaleFactor = scale;
                    _panOffset = pan;
                    _isZoomed = scale > 1.05 || pan.distance > 10;
                    if (_isZoomed && _currentZoomMode != ZoomMode.custom) {
                      _currentZoomMode = ZoomMode.custom;
                    }
                  });
                },
                onTap: () {
                  debugPrint('------------------------------> PlayerGestureControls onTap called. showControls: $_showControls');
                  setState(() {
                    _showControls = !_showControls;
                  });
                  if (_showControls) {
                    _controlsAnimationController.forward();
                    _startControlsTimer();
                  } else {
                    _controlsAnimationController.reverse();
                    _controlsTimer?.cancel();
                  }
                },
                onDoubleTap: _togglePlayPause,
                child: Container(color: Colors.transparent),
              ),
            ),

          // Error overlay
          if (_error != null && _shouldShowErrorDialog(_error!))
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFF007AFF), size: 48),
                    const SizedBox(height: 16),
                    const Text('Playback Error', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            ),

          // Controls Overlay
          AnimatedBuilder(
            animation: _controlsOpacity,
            builder: (context, child) {
              return IgnorePointer(
                ignoring: !_showControls || _error != null,
                child: Opacity(
                  opacity: _error != null ? 0.0 : _controlsOpacity.value,
                  child: child,
                ),
              );
            },
            child: Stack(
              children: [
                PlayerTopControls(
                  title: widget.videoTitle ?? 'Video',
                  onBack: widget.onBack ?? () => Navigator.of(context).pop(),
                  currentSpeed: _currentSpeed,
                  showSpeedMenu: _showSpeedMenu,
                  onSpeedMenuToggle: () {
                    setState(() {
                      _showSpeedMenu = !_showSpeedMenu;
                      _showVolumeSlider = false;
                    });
                    _resetControlsTimer();
                  },
                  onRotate: () {
                    // Toggle between landscape and portrait
                    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                    if (isLandscape) {
                      // Currently landscape, switch to portrait
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                    } else {
                      // Currently portrait, switch to landscape
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    }
                    _resetControlsTimer();
                  },
                  onSubtitles: () {
                    if (_controller != null) {
                      SubtitleTracksDialog.show(context, _controller!);
                    }
                    _resetControlsTimer();
                  },
                  onAudioTracks: () {
                    _showAudioTracksBottomSheet();
                    _resetControlsTimer();
                  },
                  onSettings: () {
                    _controlsTimer?.cancel();
                    setState(() {
                      _showSettings = true;
                      _showControls = false;
                      _showSpeedMenu = false;
                      _showVolumeSlider = false;
                      _canDismissSettings = false; // Reset flag
                    });
                    _settingsAnimationController.forward().then((_) {
                      // Enable dismissal after animation + small buffer
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted && _showSettings) {
                          setState(() => _canDismissSettings = true);
                        }
                      });
                    });
                    _controlsAnimationController.reverse();
                  },
                  onCycleZoom: _cycleZoomMode,
                  currentZoomMode: _currentZoomMode,
                  onPip: () {
                    _enterPictureInPicture();
                  },
                  currentVolume: _currentVolume,
                ),
                
                // Center controls removed as per new UI design
                
                PlayerBottomControls(
                  position: _position,
                  duration: _duration,
                  onSeek: (pos) {
                    _controller?.seekTo(pos);
                    _resetControlsTimer();
                  },
                  onSeekStart: () {
                    _controlsTimer?.cancel();
                  },
                  onSeekEnd: () {
                    _startControlsTimer();
                  },
                  isPlaying: _isPlaying,
                  onPlayPause: _togglePlayPause,

                  onSeekForward: _seekForward,
                  onNext: widget.onNext,
                  onPrevious: widget.onPrevious,
                  onSettings: () {
                    _controlsTimer?.cancel();
                    setState(() {
                      _showSettings = true;
                      // _showControls = false; // Keep controls visible
                      _showSpeedMenu = false;
                      _showVolumeSlider = false;
                      _canDismissSettings = false; // Reset flag
                    });
                    _settingsAnimationController.forward().then((_) {
                      // Enable dismissal after animation + small buffer
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted && _showSettings) {
                          setState(() => _canDismissSettings = true);
                        }
                      });
                    });
                    // _controlsAnimationController.reverse(); // Keep controls visible
                  },
                ),
                
                if (_showSpeedMenu)
                  PlayerSpeedMenu(
                    currentSpeed: _currentSpeed,
                    onSpeedChanged: (speed) {
                      setState(() => _currentSpeed = speed);
                      _controller?.setPlaybackSpeed(speed);
                      setState(() => _showSpeedMenu = false);
                      _startControlsTimer();
                    },
                  ),
                  
                if (_showVolumeSlider)
                  PlayerVolumeSlider(
                    currentVolume: _currentVolume,
                    onVolumeChanged: _changeVolume,
                  ),
              ],
            ),
          ),
          
          // Buffering Indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          
          // Settings Panel
          if (_showSettings)
            PlayerSettingsPanel(
              animation: _settingsSlideAnimation,
              videoTracks: _videoTracks,
              audioTracks: _audioTracks,
              subtitleTracks: _subtitleTracks,
              onClose: () {
                if (!_canDismissSettings) {
                  return;
                }
                _settingsAnimationController.reverse().then((_) {
                  setState(() => _showSettings = false);
                  _showControlsUI();
                });
              },
              onAudioTrackSelected: (index) async {
                await _controller?.setAudioTrack(index);
                // Optimistic update
                setState(() {
                  for (var i = 0; i < _audioTracks.length; i++) {
                    _audioTracks[i]['isSelected'] = i == index;
                  }
                  _currentAudioTrackIndex = index;
                });
              },
              onSubtitleTrackSelected: (index) async {
                await _controller?.setSubtitleTrack(index);
                // Optimistic update
                setState(() {
                  for (var i = 0; i < _subtitleTracks.length; i++) {
                    _subtitleTracks[i]['isSelected'] = i == index;
                  }
                  _currentSubtitleTrackIndex = index;
                });
              },
              currentSpeed: _currentSpeed,
              onSpeedChanged: (speed) {
                setState(() => _currentSpeed = speed);
                _controller?.setPlaybackSpeed(speed);
                // Don't close settings immediately for better UX, or do if preferred.
                // Keeping it open allows changing other settings.
              },
              onRotate: () {
                // Toggle between landscape and portrait or just force landscape
                // Simple toggle logic:
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                if (isLandscape) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                } else {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                }
              },

              onVideoTrackSelected: (index) {
                // TODO: Implement video track selection
              },
            ),
        ],
      ),
    );
  }
  

  
  
  String _formatDuration(Duration duration, {bool showPlaceholder = false}) {
    if (duration.inMilliseconds <= 0) {
      return showPlaceholder ? '--:--' : '00:00';
    }
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
  
  void _processVideoAudioTracks() {
    debugPrint('[_Media3PlayerWidgetState] _processVideoAudioTracks called');
    debugPrint('[_Media3PlayerWidgetState] Current _audioTracks: $_audioTracks');
    
    if (_audioTracks.isEmpty) {
      debugPrint('[_Media3PlayerWidgetState] No audio tracks available');
      setState(() {
        _videoAudioTracks = [];
      });
      return;
    }
    
    try {
      if (!mounted) return;
      
      // Process the audio tracks for the music panel
      final processedTracks = <Map<String, dynamic>>[];
      
      for (int i = 0; i < _audioTracks.length; i++) {
        final track = _audioTracks[i];
        processedTracks.add({
          'index': i,
          'name': track['name'] ?? 'Audio Track ${i + 1}',
          'language': track['language'] ?? 'Unknown',
          'codec': track['codec'] ?? 'Unknown',
          'bitrate': track['bitrate'] ?? 0,
          'sampleRate': track['sampleRate'] ?? 0,
          'channelCount': track['channelCount'] ?? 0,
          'isSelected': track['isSelected'] ?? (_currentAudioTrackIndex == i),
          'isSupported': track['isSupported'] ?? true,
          'displayName': _formatAudioTrackName(
            track['name'] ?? '',
            track['language'] ?? '',
            track['bitrate'] ?? 0
          ),
        });
      }
      
      setState(() {
        _videoAudioTracks = processedTracks;
      });
      
      debugPrint('[_Media3PlayerWidgetState] Processed ${processedTracks.length} audio tracks');
      debugPrint('[_Media3PlayerWidgetState] _videoAudioTracks: $_videoAudioTracks');
    } catch (e) {
      debugPrint('[_Media3PlayerWidgetState] Error processing audio tracks: $e');
      setState(() {
        _videoAudioTracks = [];
      });
    }
  }
  
  String _formatAudioTrackName(String name, String language, int bitrate) {
    String displayName = name;
    
    if (language != 'Unknown' && language.isNotEmpty) {
      displayName += ' ($language)';
    }
    
    if (bitrate > 0) {
      final bitrateKbps = (bitrate / 1000).round();
      displayName += ' - ${bitrateKbps}kbps';
    }
    
    return displayName;
  }

  String _getFullLanguageName(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return 'Unknown';
    
    final languageMap = {
      'en': 'English', 'es': 'Spanish', 'fr': 'French', 'de': 'German', 'it': 'Italian',
      'pt': 'Portuguese', 'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean', 'zh': 'Chinese',
      'ar': 'Arabic', 'hi': 'Hindi', 'ta': 'Tamil', 'te': 'Telugu', 'kn': 'Kannada',
      'ml': 'Malayalam', 'bn': 'Bengali', 'gu': 'Gujarati', 'mr': 'Marathi', 'pa': 'Punjabi',
      'or': 'Odia', 'as': 'Assamese', 'ur': 'Urdu', 'ne': 'Nepali', 'si': 'Sinhala',
      'my': 'Myanmar', 'th': 'Thai', 'vi': 'Vietnamese', 'id': 'Indonesian', 'ms': 'Malay',
      'tl': 'Filipino', 'sw': 'Swahili', 'am': 'Amharic', 'he': 'Hebrew', 'tr': 'Turkish',
      'fa': 'Persian', 'pl': 'Polish', 'cs': 'Czech', 'sk': 'Slovak', 'hu': 'Hungarian',
      'ro': 'Romanian', 'bg': 'Bulgarian', 'hr': 'Croatian', 'sr': 'Serbian', 'sl': 'Slovenian',
      'et': 'Estonian', 'lv': 'Latvian', 'lt': 'Lithuanian', 'fi': 'Finnish', 'sv': 'Swedish',
      'no': 'Norwegian', 'da': 'Danish', 'is': 'Icelandic', 'nl': 'Dutch', 'af': 'Afrikaans',
    };
    
    return languageMap[languageCode.toLowerCase()] ?? languageCode.toUpperCase();
  }

  void _showAudioTracksBottomSheet() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Animated background that fades as panel slides in
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final fadeProgress = animation.value;
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.black.withOpacity(0.7 * fadeProgress),
                        Colors.black.withOpacity(0.5 * fadeProgress),
                        Colors.black.withOpacity(0.3 * fadeProgress),
                        Colors.black.withOpacity(0.15 * fadeProgress),
                        Colors.black.withOpacity(0.05 * fadeProgress),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        0.2,
                        0.4,
                        0.6,
                        0.75,
                        0.85,
                        1.0,
                      ],
                    ),
                  ),
                );
              },
            ),
            // Sliding panel
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withOpacity(0.95),
                          Colors.black.withOpacity(0.9),
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.7, 0.85, 1.0],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(-5, 0),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Audio (${_audioTracks.length})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.close, color: Colors.white70, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Audio tracks list
                          if (_videoAudioTracks.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No audio tracks available',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: _videoAudioTracks.length,
                                itemBuilder: (context, index) {
                                  final track = _videoAudioTracks[index];
                                  final isSelected = track['isSelected'] ?? false;
                                  final displayName = track['displayName'] ?? track['name'] ?? 'Track ${index + 1}';
                                  final languageCode = track['language'] ?? 'Unknown';
                                  final language = _getFullLanguageName(languageCode);
                                  
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected ? Border.all(color: Colors.blue, width: 1) : null,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () async {
                                          try {
                                            final trackIndex = track['index'] ?? index;
                                            await _controller?.selectAudioTrack(trackIndex);
                                            if (mounted) {
                                              Navigator.pop(context);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              Navigator.pop(context);
                                            }
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? Colors.blue : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isSelected ? Colors.blue : Colors.white.withOpacity(0.3),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: isSelected 
                                                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                                                  : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      displayName,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                        fontSize: 11,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      language,
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.blue.shade200 : Colors.white60,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Wake lock methods to keep screen on during video playback
  Future<void> _enableWakeLock() async {
    try {
      // Enable immersive mode and keep screen on
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      
      // Additional wake lock - prevent screen from sleeping
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
      
      // Force keep screen awake during video playback
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      debugPrint('[WAKE_LOCK] Screen wake lock enabled - screen will stay on during video playback');
    } catch (e) {
      debugPrint('[WAKE_LOCK] Failed to enable wake lock: $e');
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
      debugPrint('[WAKE_LOCK] Screen wake lock disabled');
    } catch (e) {
      debugPrint('[WAKE_LOCK] Failed to disable wake lock: $e');
    }
  }


  void _setBrightness(double brightness) async {
    try {
      double newBrightness = brightness.clamp(0.0, 1.0);
      
      // Only update if there's a meaningful change
      if ((newBrightness - _currentBrightness).abs() < 0.01) return;
      
      setState(() {
        _currentBrightness = newBrightness;
      });
      
      // Debounce system brightness setting
      _brightnessDebounceTimer?.cancel();
      _brightnessDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
        try {
          await _brightnessChannel.invokeMethod('setBrightness', {'brightness': newBrightness});
          debugPrint('[BRIGHTNESS] System brightness set to: $newBrightness');
        } catch (e) {
          debugPrint('[BRIGHTNESS] Custom brightness channel failed: $e');
          // Fallback
          try {
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarBrightness: newBrightness > 0.5 ? Brightness.light : Brightness.dark,
                statusBarIconBrightness: newBrightness > 0.5 ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: newBrightness > 0.5 ? Brightness.dark : Brightness.light,
              ),
            );
          } catch (e2) {
            debugPrint('[BRIGHTNESS] All brightness methods failed: $e2');
          }
        }
      });
    } catch (e) {
      debugPrint('[BRIGHTNESS] Error setting brightness: $e');
    }
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Show system volume UI again when leaving player
    FlutterVolumeController.updateShowSystemUI(true);
    // Cancel timers
    _controlsTimer?.cancel();
    _errorClearTimer?.cancel();
    _bufferingTimer?.cancel();
    _stopTrackDetectionTimer();
    
    // Dispose animation controllers
    _controlsAnimationController.dispose();
    _settingsAnimationController.dispose();
    
    // Disable wake lock
    _disableWakeLock();
    
    // Cancel subscriptions
    _playingSubscription.cancel();
    _bufferingSubscription.cancel();
    _positionSubscription.cancel();
    _errorSubscription.cancel();
    _initializedSubscription.cancel();
    _performanceSubscription.cancel();
    _tracksSubscription.cancel();
    _volumeSubscription?.cancel();
    
    // Dispose controller
    _controller?.dispose();
    
    super.dispose();
  }
}