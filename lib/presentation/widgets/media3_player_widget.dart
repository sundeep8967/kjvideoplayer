import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
// Brightness control without external dependency
import '../../core/platform/media3_player_controller.dart';
import 'subtitle_tracks_dialog.dart';
import 'video_settings_dialog.dart';

// Enum for Zoom Modes
enum ZoomMode { fit, stretch, zoomToFill, custom }

/// Media3 Player Widget - Enhanced implementation with comprehensive controls
class Media3PlayerWidget extends StatefulWidget {
  final String videoPath;
  final String? videoTitle;
  final bool autoPlay;
  final Duration? startPosition;
  final VoidCallback? onBack;
  final Function(Duration)? onPositionChanged;
  final Function(Duration)? onBookmarkAdded;
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
  double? _originalBrightness;
  bool _isBrightnessAdjusting = false;
  Timer? _brightnessDebounceTimer;
  
  // Temporary state for seekbar dragging
  Duration? _draggingPosition;
  
  // Enhanced UI State
  bool _showControls = true;
  ZoomMode _currentZoomMode = ZoomMode.fit; // Default zoom mode
  bool _showSettings = false;
  bool _showSpeedMenu = false;
  bool _showVolumeSlider = false;
  double _currentSpeed = 1.0;
  double _currentVolume = 1.0;
  bool _isMuted = false;
  int _bufferedPercentage = 0;
  
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
  
  @override
  void initState() {
    super.initState();
    debugPrint('[INIT] Initializing player widget...');
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeBrightness();
    _initializePlayer();
    _startControlsTimer();
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _controlsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _settingsSlideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeInOut,
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
        debugPrint('[_Media3PlayerWidgetState] setState: _isPlaying set to $isPlaying');
      });
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
      debugPrint('[_Media3PlayerWidgetState] Event: onPositionChanged received: position=${newPosition.inSeconds}s, duration=${newDuration.inSeconds}s. Current state: _position=${_position.inSeconds}s, _duration=${_duration.inSeconds}s');
      if (!mounted) return;
      setState(() {
        _position = newPosition;
        _duration = newDuration;
        debugPrint('[_Media3PlayerWidgetState] setState: _position set to ${_position.inSeconds}s, _duration set to ${_duration.inSeconds}s');
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
      
      setState(() {
        _videoTracks = newVideoTracks;
        _audioTracks = newAudioTracks;
        _subtitleTracks = newSubtitleTracks;
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
  Future<void> _initializeBrightness() async {
    // Initialize with default brightness (simulated)
    _currentBrightness = 0.5;
    _originalBrightness = 0.5;
    debugPrint('[BRIGHTNESS] Brightness control initialized (simulated)');
  }

  void _onBrightnessStart() {
    setState(() {
      _isBrightnessAdjusting = true;
    });
    HapticFeedback.selectionClick();
    _resetControlsTimer();
  }

  void _onBrightnessUpdate(DragUpdateDetails details) {
    if (!_isBrightnessAdjusting) return;
    
    // Calculate brightness change based on vertical swipe
    double screenHeight = MediaQuery.of(context).size.height;
    double sensitivity = screenHeight * 0.4; // Adjust sensitivity
    double delta = -details.delta.dy / sensitivity; // Negative because swipe up should increase brightness
    
    // Ignore very small movements
    if (delta.abs() < 0.005) return;
    
    _adjustBrightness(delta);
  }

  void _onBrightnessEnd() {
    setState(() {
      _isBrightnessAdjusting = false;
    });
    _resetControlsTimer();
  }

  void _adjustBrightness(double delta) async {
    try {
      double newBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
      
      // Only update if there's a meaningful change
      if ((newBrightness - _currentBrightness).abs() < 0.01) return;
      
      setState(() {
        _currentBrightness = newBrightness;
      });
      
      // Simulate brightness setting (visual feedback only)
      _brightnessDebounceTimer?.cancel();
      _brightnessDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
        debugPrint('[BRIGHTNESS] Simulated brightness: $newBrightness');
        // TODO: Integrate with actual system brightness control
      });
    } catch (e) {
      debugPrint('[BRIGHTNESS] Error calculating brightness: $e');
    }
  }

  IconData _getBrightnessIcon(double brightness) {
    if (brightness < 0.3) {
      return Icons.brightness_low;
    } else if (brightness < 0.7) {
      return Icons.brightness_medium;
    } else {
      return Icons.brightness_high;
    }
  }
  
  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsUI();
    }
  }
  
  void _showControlsUI() {
    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();
    _resetControlsTimer();
  }
  
  void _hideControls() {
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
  
  // Zoom and pan gesture handlers
  void _onScaleStart(ScaleStartDetails details) {
    // Store initial scale factor when gesture starts
    _baseScaleFactor = _scaleFactor;
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!mounted) return;
    setState(() {
      _scaleFactor = (_baseScaleFactor * details.scale).clamp(0.5, 3.0); // Allow zoom out to 50%
      
      if (_scaleFactor != 1.0) { // Pan only if zoomed in or out
        final screenSize = MediaQuery.of(context).size;
        // Use absolute value to handle both zoom in and zoom out correctly
        final scaleDifference = (_scaleFactor - 1.0).abs();
        final maxPanX = (screenSize.width * scaleDifference) / 2;
        final maxPanY = (screenSize.height * scaleDifference) / 2;
        
        _panOffset = Offset(
          (_panOffset.dx + details.focalPointDelta.dx).clamp(-maxPanX, maxPanX),
          (_panOffset.dy + details.focalPointDelta.dy).clamp(-maxPanY, maxPanY),
        );
      } else {
        // Reset pan when at 1.0 scale
        _panOffset = Offset.zero;
      }
      // If scale or pan happens, it's custom zoom
      bool isPanned = _panOffset.dx.abs() >= 0.1 || _panOffset.dy.abs() >= 0.1; // More sensitive pan check
      bool isScaled = (_scaleFactor - 1.0).abs() > 0.001; // Very small epsilon for scale being different from 1.0

      if (isScaled || isPanned) {
         if (_currentZoomMode != ZoomMode.custom) { // Avoid redundant setState if already custom
            _currentZoomMode = ZoomMode.custom;
            debugPrint('[_Media3PlayerWidgetState] Pinch zoom detected, mode set to Custom. Scale: $_scaleFactor, Pan: $_panOffset');
         }
      }
      _isZoomed = isScaled || isPanned; // Update _isZoomed based on actual state
    });
  }
  
  void _onScaleEnd(ScaleEndDetails details) {
    if (!mounted) return;

    // Determine if the current state is effectively the "default" (non-zoomed, non-panned) state.
    // Use a very small epsilon for floating point comparisons to 1.0.
    bool isScaleEffectivelyUnity = (_scaleFactor - 1.0).abs() < 0.001;
    bool isPanEffectivelyZero = _panOffset.dx.abs() < 0.1 && _panOffset.dy.abs() < 0.1;

    if (isScaleEffectivelyUnity && isPanEffectivelyZero) {
      // If ended very close to 1.0 scale and no pan, treat as reset.
      debugPrint('[_Media3PlayerWidgetState] Scale ended at/very near 1.0 and no pan, resetting to Fit mode. Scale: $_scaleFactor');
      _resetZoom(); // This sets mode to fit, calls native resize, and resets scale/pan.
    } else {
      // Otherwise, the current custom zoom/pan is persisted.
      _baseScaleFactor = _scaleFactor; // This is crucial for the next gesture to be incremental.

      // Ensure _isZoomed is true if we are not in the reset state.
      _isZoomed = true;

      // If not already in custom mode (e.g., if a predefined mode was active and user just started pinching),
      // set it to custom.
      if (_currentZoomMode != ZoomMode.custom) {
          setState(() {
              _currentZoomMode = ZoomMode.custom;
              debugPrint('[_Media3PlayerWidgetState] Zoom gesture ended, mode is Custom. Scale: $_scaleFactor, Pan: $_panOffset');
          });
      } else {
        // If already in custom mode, just ensure _isZoomed is correctly reflecting the state.
        // This might involve a setState if _isZoomed was somehow false but should be true.
        // However, _onScaleUpdate should keep _isZoomed fairly accurate.
        // Forcing a setState here can be redundant if _onScaleUpdate handled it.
        // Let's rely on _onScaleUpdate for _isZoomed during the gesture.
         debugPrint('[_Media3PlayerWidgetState] Zoom gesture ended, remaining in Custom. Scale: $_scaleFactor, Pan: $_panOffset');
      }
    }
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
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: AndroidView(
                    viewType: 'media3_player_view',
                    creationParams: {
                      'videoPath': widget.videoPath,
                      'autoPlay': widget.autoPlay,
                      'startPosition': widget.startPosition?.inMilliseconds,
                      'useBuiltInControls': false, // Hide Media3's built-in controls to use custom Flutter controls
                    },
                    creationParamsCodec: const StandardMessageCodec(),
                    onPlatformViewCreated: (int id) {
                      debugPrint('[_Media3PlayerWidgetState] onPlatformViewCreated called with id: $id');
                      _initializePlayer(id);
                    },
                  ),
                ),
              ),
            ),
          ),
          // Gesture detection overlay with left/right split
          Positioned.fill(
            child: Row(
              children: [
                // Left side for brightness control (1/4 of screen)
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: _toggleControls,
                    onPanStart: (_) => _onBrightnessStart(),
                    onPanUpdate: _onBrightnessUpdate,
                    onPanEnd: (_) => _onBrightnessEnd(),
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      color: Colors.transparent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                // Right side for video controls (3/4 of screen)
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _toggleControls,
                    onDoubleTap: _togglePlayPause,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
            
            // Loading indicator
            if (!_isInitialized)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            
            // Buffering indicator (only show after delay to avoid flickering)
            if (_showBufferingIndicator && _isInitialized)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            
            // Error overlay (only for critical errors)
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Playback Error',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                          });
                        },
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Custom video player controls
            Visibility(
              visible: _showControls && _error == null, // Only build/layout when visible
              child: AnimatedBuilder(
                animation: _controlsOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _controlsOpacity.value, // Still use opacity for fade effect
                    child: Stack(
                      children: [
                        // Top controls (back button, title, settings)
                        _buildTopControls(),
                        
                        // Center controls (play/pause, seek)
                        _buildCenterControls(),
                        
                        // Bottom controls (progress bar, volume, speed, etc.)
                        _buildBottomControls(),
                        
                        // Speed menu
                        if (_showSpeedMenu)
                          _buildSpeedMenu(),
                          
                        // Volume slider
                        if (_showVolumeSlider)
                          _buildVolumeSlider(),
                      ],
                    ),
                  );
                },
              ),
            ),
              
            // Settings panel
            if (_showSettings)
              _buildSettingsPanel(),

              
          // Brightness indicator (when adjusting brightness)
          if (_isBrightnessAdjusting)
            _buildBrightnessIndicator(),

          // Zoom indicator (for pinch-zoom level)
          if (_isZoomed && _currentZoomMode == ZoomMode.custom) // Only show for custom pinch zoom
            _buildZoomIndicator(),

          // Zoom Mode Toast
          AnimatedOpacity(
            opacity: _zoomModeToastMessage != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _zoomModeToastMessage == null
                ? const SizedBox.shrink()
                : Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        _zoomModeToastMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  

  
  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.videoTitle ?? 'Video',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_performanceData.isNotEmpty)
                    Text(
                      'Buffer: $_bufferedPercentage%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // Subtitle control
            IconButton(
              onPressed: () {
                if (_controller != null) {
                  SubtitleTracksDialog.show(context, _controller!);
                }
                _resetControlsTimer();
              },
              icon: const Icon(Icons.subtitles, color: Colors.white, size: 24),
              tooltip: 'Subtitles',
            ),
            // Music button - Show available audio tracks
            IconButton(
              onPressed: () {
                _showAudioTracksBottomSheet();
                _resetControlsTimer();
              },
              icon: const Icon(Icons.music_note, color: Colors.white, size: 24),
              tooltip: 'Audio Tracks',
            ),
            // Settings button
            IconButton(
              onPressed: () {
                VideoSettingsDialog.show(
                  context,
                  _controller,
                  currentSpeed: _currentSpeed,
                  currentVolume: _currentVolume,
                  isMuted: _isMuted,
                  onSpeedChanged: (speed) {
                    setState(() {
                      _currentSpeed = speed;
                    });
                    _controller?.setPlaybackSpeed(speed);
                  },
                  onVolumeChanged: (volume) {
                    setState(() {
                      _currentVolume = volume;
                    });
                    _controller?.setVolume(volume);
                  },
                  onMuteChanged: (muted) {
                    setState(() {
                      _isMuted = muted;
                    });
                    _controller?.setVolume(muted ? 0.0 : _currentVolume);
                  },
                );
                _resetControlsTimer();
              },
              icon: const Icon(Icons.settings, color: Colors.white, size: 24),
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Seek backward
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _seekBackward,
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
            ),
          ),
          
          // Play/Pause
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          
          // Seek forward
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _seekForward,
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar with buffer indicator
            Row(
              children: [
                Text(
                  _formatDuration(_position, showPlaceholder: true),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbColor: _isPlaying ? Colors.blue : Colors.red,
                      activeTrackColor: _isPlaying ? Colors.blue : Colors.red,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: (_duration.inMilliseconds > 0)
                          ? ((_draggingPosition ?? _position).inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (_duration.inMilliseconds > 0)
                          ? (value) {
                              if (!mounted) return;
                              final newDraggingPosition = Duration(milliseconds: (value * _duration.inMilliseconds).round());
                              debugPrint('[_Media3PlayerWidgetState] Slider onChanged: value=$value, newDraggingPosition=${newDraggingPosition.inSeconds}s');
                              setState(() {
                                _draggingPosition = newDraggingPosition;
                              });
                              _resetControlsTimer();
                            }
                          : null,
                      onChangeEnd: (_duration.inMilliseconds > 0)
                          ? (value) {
                              if (!mounted) return;
                              if (_draggingPosition != null) {
                                final seekTo = _draggingPosition!.inMilliseconds.clamp(0, _duration.inMilliseconds);
                                debugPrint('[_Media3PlayerWidgetState] Slider onChangeEnd: seeking to ${Duration(milliseconds: seekTo).inSeconds}s');
                                _controller?.seekTo(Duration(milliseconds: seekTo));
                                // UI will update via onPositionChanged stream, but can optimistically update if needed
                                // setState(() {
                                //   _position = Duration(milliseconds: seekTo);
                                // });
                              }
                              setState(() { // Clear dragging position whether it was null or not
                                  _draggingPosition = null;
                              });
                              _resetControlsTimer();
                            }
                          : null,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_duration, showPlaceholder: true), // Duration should update via onPositionChanged
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Control buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Speed control
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showSpeedMenu = !_showSpeedMenu;
                      _showVolumeSlider = false;
                    });
                    _resetControlsTimer();
                  },
                  icon: Text(
                    '${_currentSpeed}x',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                
                
                // Volume control
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showVolumeSlider = !_showVolumeSlider;
                      _showSpeedMenu = false;
                    });
                    _resetControlsTimer();
                  },
                  icon: Icon(
                    _currentVolume > 0.5 ? Icons.volume_up :
                    _currentVolume > 0 ? Icons.volume_down : Icons.volume_off,
                    color: Colors.white,
                  ),
                ),
                
                // Zoom Cycle Button
                IconButton(
                  onPressed: _cycleZoomMode,
                  icon: Icon(
                    _currentZoomMode == ZoomMode.fit ? Icons.fullscreen_exit // Or Icons.fit_screen
                    : _currentZoomMode == ZoomMode.stretch ? Icons.aspect_ratio // Or Icons.settings_overscan
                    : _currentZoomMode == ZoomMode.zoomToFill ? Icons.crop // Or Icons.zoom_in_map
                    : Icons.zoom_in, // Custom zoom might show a generic zoom icon
                    color: Colors.white,
                  ),
                  tooltip: 'Cycle Zoom Mode (${_currentZoomMode.toString().split('.').last})',
                ),
                
                // Zoom reset button (only show when zoomed)
                if (_isZoomed)
                  IconButton(
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                    tooltip: 'Reset Zoom',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpeedMenu() {
    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSpeedOption(0.5),
            _buildSpeedOption(0.75),
            _buildSpeedOption(1.0),
            _buildSpeedOption(1.25),
            _buildSpeedOption(1.5),
            _buildSpeedOption(2.0),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpeedOption(double speed) {
    final isSelected = _currentSpeed == speed;
    return InkWell(
      onTap: () => _changePlaybackSpeed(speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withOpacity(0.3) : Colors.transparent,
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: isSelected ? Colors.red : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildVolumeSlider() {
    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        height: 150,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Icon(
              _currentVolume > 0.5 ? Icons.volume_up :
              _currentVolume > 0 ? Icons.volume_down : Icons.volume_off,
              color: Colors.white,
              size: 20,
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbColor: Colors.red,
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                  ),
                  child: Slider(
                    value: _currentVolume,
                    onChanged: _changeVolume,
                    min: 0.0,
                    max: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingsPanel() {
    return AnimatedBuilder(
      animation: _settingsSlideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_settingsSlideAnimation.value * 300, 0),
          child: Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 300,
            child: Container(
              color: Colors.black.withOpacity(0.9),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Text(
                            'Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showSettings = false;
                              });
                              _settingsAnimationController.reverse();
                            },
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(color: Colors.white24),
                    
                    // Video tracks
                    if (_videoTracks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Video Quality',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ..._videoTracks.asMap().entries.map((entry) => ListTile(
                        title: Text(
                          entry.value['name'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${entry.value['width']}x${entry.value['height']} - ${entry.value['bitrate']} kbps',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () async {
                          // TODO: Implement video track selection (if needed)
                        },
                      )),
                    ],
                    
                    // Audio tracks
                    if (_audioTracks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Audio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ..._audioTracks.asMap().entries.map((entry) => ListTile(
                        title: Text(
                          entry.value['name'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          entry.value['language'] ?? 'Unknown language',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () async {
                          await _controller?.setAudioTrack(entry.key);
                          // After setting the track, fetch and update the current index
                          await _fetchAndUpdateCurrentAudioTrackIndex();
                        },
                      )),
                    ],
                    
                    // Subtitle tracks - Always show section
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Subtitles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_subtitleTracks.isNotEmpty) ...[
                      ..._subtitleTracks.asMap().entries.map((entry) => ListTile(
                        title: Text(
                          entry.value['name'] ?? 'Subtitle ${entry.key + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          entry.value['language'] ?? 'Unknown language',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () async {
                          await _controller?.setSubtitleTrack(entry.key);
                          setState(() {});
                        },
                      )),
                      ListTile(
                        title: const Text('Disable Subtitles', style: TextStyle(color: Colors.white)),
                        onTap: () async {
                          await _controller?.disableSubtitle();
                          setState(() {});
                        },
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No subtitle tracks detected in this video',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                    
                    // Debug information
                    const Divider(color: Colors.white24),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Debug Info',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Video Tracks: ${_videoTracks.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Audio Tracks: ${_audioTracks.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Subtitle Tracks: ${_subtitleTracks.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Initialized: $_isInitialized',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Zoom: ${(_scaleFactor * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (_isZoomed)
                            Text(
                              'Pan: (${_panOffset.dx.toInt()}, ${_panOffset.dy.toInt()})',
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    
                    // Performance info
                    if (_performanceData.isNotEmpty) ...[
                      const Divider(color: Colors.white24),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Performance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buffer: $_bufferedPercentage%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (_performanceData['width'] != null)
                              Text(
                                'Resolution: ${_performanceData['width']}x${_performanceData['height']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildBrightnessIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBrightnessIcon(_currentBrightness),
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              '${(_currentBrightness * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _currentBrightness,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomIndicator() {
    return Positioned(
      top: 100,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.zoom_in,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '${(_scaleFactor * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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

  void _showAudioTracksBottomSheet() {
    // Debug: Print current state
    debugPrint('=== AUDIO TRACKS DEBUG ===');
    debugPrint('_audioTracks.length: ${_audioTracks.length}');
    debugPrint('_audioTracks: $_audioTracks');
    debugPrint('_currentAudioTrackIndex: $_currentAudioTrackIndex');
    debugPrint('_isInitialized: $_isInitialized');
    debugPrint('========================');
    
    // Ensure we have the latest tracks data
    _processVideoAudioTracks();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Flexible(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.music_note, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Audio Tracks (${_audioTracks.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              
              // Audio tracks list
              if (_videoAudioTracks.isEmpty)
                Flexible(
                  flex: 0,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No audio tracks available',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _videoAudioTracks.length,
                    itemBuilder: (context, index) {
                      final track = _videoAudioTracks[index];
                      final isSelected = track['isSelected'] ?? false;
                      final displayName = track['displayName'] ?? track['name'] ?? 'Unknown Track';
                      final language = track['language'] ?? 'Unknown';
                      final codec = track['codec'] ?? 'Unknown';
                      final bitrate = track['bitrate'] ?? 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                        ),
                        child: ListTile(
                          leading: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.blue : Colors.white70,
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Language: $language', 
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('Codec: $codec', 
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (bitrate > 0) Text('Bitrate: ${bitrate} bps', 
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          onTap: () async {
                            try {
                              final trackIndex = track['index'] ?? index;
                              debugPrint('Attempting to select track at index: $trackIndex');
                              
                              await _controller?.selectAudioTrack(trackIndex);
                              await _fetchAndUpdateCurrentAudioTrackIndex();
                              _processVideoAudioTracks();
                              
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Audio track selected successfully'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error selecting audio track: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to select audio track: $e'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel timers
    _controlsTimer?.cancel();
    _errorClearTimer?.cancel();
    _bufferingTimer?.cancel();
    _stopTrackDetectionTimer();
    
    // Dispose animation controllers
    _controlsAnimationController.dispose();
    _settingsAnimationController.dispose();
    
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