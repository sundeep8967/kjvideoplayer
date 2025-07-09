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
  
  // Volume control state
  double _currentVolume = 0.5;
  double? _originalVolume;
  bool _isVolumeAdjusting = false;
  Timer? _volumeDebounceTimer;
  
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
  
  // Timer for zoom indicator auto-hide
  Timer? _zoomIndicatorTimer;
  bool _showZoomIndicator = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('[INIT] Initializing player widget...');
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeBrightness();
    _initializeVolume();
    _initializePlayer();
    _startControlsTimer();
    _enableWakeLock();
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
      begin: 1.0,
      end: 0.0,
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
      
      // Ensure wake lock is active when video is playing
      if (isPlaying) {
        _enableWakeLock();
        debugPrint('[WAKE_LOCK] Video started playing - wake lock reinforced');
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
  static const MethodChannel _brightnessChannel = MethodChannel('com.sundeep.kjvideoplayer/brightness');
  
  Future<void> _initializeBrightness() async {
    try {
      // Try to get current system brightness using custom channel
      final currentBrightness = await _brightnessChannel.invokeMethod<double>('getBrightness');
      if (currentBrightness != null) {
        _currentBrightness = currentBrightness;
        _originalBrightness = currentBrightness;
        debugPrint('[BRIGHTNESS] Brightness control initialized with system brightness: $currentBrightness');
      } else {
        throw Exception('Failed to get brightness from native');
      }
    } catch (e) {
      // Fallback: try to get current window brightness
      try {
        final windowBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? 0.3 : 0.7;
        _currentBrightness = windowBrightness;
        _originalBrightness = windowBrightness;
        debugPrint('[BRIGHTNESS] Using platform brightness fallback: $windowBrightness');
      } catch (e2) {
        // Final fallback to default
        _currentBrightness = 0.5;
        _originalBrightness = 0.5;
        debugPrint('[BRIGHTNESS] Using default brightness: $e2');
      }
    }
  }

  // Volume control methods
  Future<void> _initializeVolume() async {
    // Initialize with default volume
    _currentVolume = 0.5;
    _originalVolume = 0.5;
    debugPrint('[VOLUME] Volume control initialized');
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
      
      // Set actual system brightness
      _brightnessDebounceTimer?.cancel();
      _brightnessDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
        try {
          // Try custom brightness channel first
          await _brightnessChannel.invokeMethod('setBrightness', {'brightness': newBrightness});
          debugPrint('[BRIGHTNESS] System brightness set to: $newBrightness');
        } catch (e) {
          debugPrint('[BRIGHTNESS] Custom brightness channel failed: $e');
          // Fallback: Use window brightness adjustment (limited but works)
          try {
            // This won't change system brightness but will adjust app brightness
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarBrightness: newBrightness > 0.5 ? Brightness.light : Brightness.dark,
                statusBarIconBrightness: newBrightness > 0.5 ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: newBrightness > 0.5 ? Brightness.dark : Brightness.light,
              ),
            );
            debugPrint('[BRIGHTNESS] Applied UI brightness adjustment: $newBrightness');
          } catch (e2) {
            debugPrint('[BRIGHTNESS] All brightness methods failed: $e2');
          }
        }
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

  // Volume control methods
  void _onVolumeStart() {
    setState(() {
      _isVolumeAdjusting = true;
    });
    HapticFeedback.selectionClick();
    _resetControlsTimer();
  }

  void _onVolumeUpdate(DragUpdateDetails details) {
    if (!_isVolumeAdjusting) return;
    
    // Calculate volume change based on vertical swipe
    double screenHeight = MediaQuery.of(context).size.height;
    double sensitivity = screenHeight * 0.4; // Adjust sensitivity
    double delta = -details.delta.dy / sensitivity; // Negative because swipe up should increase volume
    
    // Ignore very small movements
    if (delta.abs() < 0.005) return;
    
    _adjustVolume(delta);
  }

  void _onVolumeEnd() {
    setState(() {
      _isVolumeAdjusting = false;
    });
    _resetControlsTimer();
  }

  void _adjustVolume(double delta) async {
    try {
      double newVolume = (_currentVolume + delta).clamp(0.0, 1.0);
      
      // Only update if there's a meaningful change
      if ((newVolume - _currentVolume).abs() < 0.01) return;
      
      setState(() {
        _currentVolume = newVolume;
        _isMuted = newVolume <= 0.0;
      });
      
      // Debounce the actual volume setting to avoid too many calls
      _volumeDebounceTimer?.cancel();
      _volumeDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
        try {
          // Use the existing _changeVolume method which properly handles both system and player volume
          _changeVolume(newVolume);
          debugPrint('[VOLUME] Applied volume via swipe: $newVolume');
        } catch (e) {
          debugPrint('[VOLUME] Error setting volume: $e');
          // Reset to original volume on error
          setState(() {
            _currentVolume = _originalVolume ?? 0.5;
            _isMuted = (_originalVolume ?? 0.5) <= 0.0;
          });
        }
      });
    } catch (e) {
      debugPrint('[VOLUME] Error calculating volume: $e');
    }
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0.0) {
      return Icons.volume_off;
    } else if (volume < 0.3) {
      return Icons.volume_down;
    } else if (volume < 0.7) {
      return Icons.volume_up;
    } else {
      return Icons.volume_up;
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
  bool _isMultiFingerGesture = false;
  bool _isSingleFingerSwipe = false;
  Offset? _swipeStartPosition;
  
  void _onCombinedScaleStart(ScaleStartDetails details) {
    // Check if it's a multi-finger gesture (pinch-to-zoom)
    if (details.pointerCount > 1) {
      _isMultiFingerGesture = true;
      _isSingleFingerSwipe = false;
      // Handle zoom start
      _baseScaleFactor = _scaleFactor;
    } else {
      // Single finger - potential swipe for volume/brightness
      _isMultiFingerGesture = false;
      _isSingleFingerSwipe = false; // Will be determined in update
      _swipeStartPosition = details.focalPoint;
    }
  }
  
  void _onCombinedScaleUpdate(ScaleUpdateDetails details) {
    if (_isMultiFingerGesture && details.pointerCount > 1) {
      // Handle zoom/pan
      _onScaleUpdate(details);
    } else if (!_isMultiFingerGesture && details.pointerCount == 1) {
      // Single finger gesture - check if it's a swipe
      if (_swipeStartPosition != null) {
        final deltaY = (details.focalPoint.dy - _swipeStartPosition!.dy).abs();
        final deltaX = (details.focalPoint.dx - _swipeStartPosition!.dx).abs();
        
        // If vertical movement is significant and greater than horizontal, treat as swipe
        if (deltaY > 10 && deltaY > deltaX) {
          if (!_isSingleFingerSwipe) {
            // Start swipe gesture
            _isSingleFingerSwipe = true;
            final screenWidth = MediaQuery.of(context).size.width;
            final tapX = details.focalPoint.dx;
            
            if (tapX < screenWidth / 2) {
              _onBrightnessStart();
            } else {
              _onVolumeStart();
            }
          }
          
          // Continue swipe gesture
          if (_isSingleFingerSwipe) {
            final screenWidth = MediaQuery.of(context).size.width;
            final tapX = details.focalPoint.dx;
            
            // Create DragUpdateDetails from ScaleUpdateDetails
            final dragDetails = DragUpdateDetails(
              globalPosition: details.focalPoint,
              delta: details.focalPointDelta,
            );
            
            if (tapX < screenWidth / 2) {
              _onBrightnessUpdate(dragDetails);
            } else {
              _onVolumeUpdate(dragDetails);
            }
          }
        }
      }
    }
  }
  
  void _onCombinedScaleEnd(ScaleEndDetails details) {
    if (_isMultiFingerGesture) {
      // Handle zoom end
      _onScaleEnd(details);
    } else if (_isSingleFingerSwipe) {
      // Handle swipe end
      if (_isBrightnessAdjusting) {
        _onBrightnessEnd();
      }
      if (_isVolumeAdjusting) {
        _onVolumeEnd();
      }
    }
    
    // Reset all flags
    _isMultiFingerGesture = false;
    _isSingleFingerSwipe = false;
    _swipeStartPosition = null;
  }

  // Zoom and pan gesture handlers
  void _onScaleStart(ScaleStartDetails details) {
    // Store initial scale factor when gesture starts
    _baseScaleFactor = _scaleFactor;
    
    // Show zoom indicator when zoom gesture starts
    _showZoomIndicatorWithTimer();
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!mounted) return;
    
    // Keep zoom indicator visible during zoom gesture
    if (!_showZoomIndicator) {
      setState(() {
        _showZoomIndicator = true;
      });
    }
    
    setState(() {
      _scaleFactor = (_baseScaleFactor * details.scale).clamp(0.5, 3.0); // Allow zoom out to 50%
      
      // Only allow panning if significantly zoomed in (not just slightly off 1.0)
      if (_scaleFactor > 1.1) { // Only pan when zoomed in more than 10%
        final screenSize = MediaQuery.of(context).size;
        final scaleDifference = _scaleFactor - 1.0;
        final maxPanX = (screenSize.width * scaleDifference) / 2;
        final maxPanY = (screenSize.height * scaleDifference) / 2;
        
        // Only apply pan delta if the movement is intentional (not just from zoom gesture)
        // Check if this is primarily a zoom gesture vs a pan gesture
        final zoomChange = (details.scale - 1.0).abs();
        final panChange = details.focalPointDelta.distance;
        
        // If zoom change is significant compared to pan change, prioritize zoom over pan
        if (zoomChange > 0.01 || panChange < 5.0) {
          // This is primarily a zoom gesture, don't apply pan
          // Keep existing pan offset but don't add new pan movement
        } else {
          // This is a pan gesture, apply the movement
          _panOffset = Offset(
            (_panOffset.dx + details.focalPointDelta.dx).clamp(-maxPanX, maxPanX),
            (_panOffset.dy + details.focalPointDelta.dy).clamp(-maxPanY, maxPanY),
          );
        }
      } else {
        // Reset pan when not significantly zoomed in
        _panOffset = Offset.zero;
      }
      
      // Update zoom state
      bool isPanned = _panOffset.dx.abs() >= 0.1 || _panOffset.dy.abs() >= 0.1;
      bool isScaled = (_scaleFactor - 1.0).abs() > 0.05; // Less sensitive scale check

      if (isScaled || isPanned) {
         if (_currentZoomMode != ZoomMode.custom) {
            _currentZoomMode = ZoomMode.custom;
            debugPrint('[_Media3PlayerWidgetState] Pinch zoom detected, mode set to Custom. Scale: $_scaleFactor, Pan: $_panOffset');
         }
      }
      _isZoomed = isScaled || isPanned;
    });
  }
  
  void _onScaleEnd(ScaleEndDetails details) {
    if (!mounted) return;

    // Use more reasonable thresholds for determining reset vs maintain zoom
    bool isScaleNearUnity = (_scaleFactor - 1.0).abs() < 0.05; // 5% threshold instead of 0.1%
    bool isPanMinimal = _panOffset.dx.abs() < 10.0 && _panOffset.dy.abs() < 10.0; // 10px threshold

    if (isScaleNearUnity && isPanMinimal) {
      // If ended close to 1.0 scale and minimal pan, reset to center
      debugPrint('[_Media3PlayerWidgetState] Scale ended near 1.0 with minimal pan, resetting to center. Scale: $_scaleFactor');
      _resetZoom(); // This centers the video and resets zoom
    } else {
      // Maintain current zoom/pan state
      _baseScaleFactor = _scaleFactor;

      // Ensure video stays properly centered if not significantly zoomed
      if (_scaleFactor < 1.1) {
        // If zoom is minimal, center the video but keep the scale
        setState(() {
          _panOffset = Offset.zero; // Center the video
          _isZoomed = (_scaleFactor - 1.0).abs() > 0.05;
        });
        debugPrint('[_Media3PlayerWidgetState] Minimal zoom, centering video. Scale: $_scaleFactor');
      } else {
        // Significant zoom, maintain current state
        _isZoomed = true;
        debugPrint('[_Media3PlayerWidgetState] Maintaining zoom state. Scale: $_scaleFactor, Pan: $_panOffset');
      }

      if (_currentZoomMode != ZoomMode.custom) {
          setState(() {
              _currentZoomMode = ZoomMode.custom;
          });
      }
    }
    
    // Restart zoom indicator timer when gesture ends
    _showZoomIndicatorWithTimer();
  }
  
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
          // Combined gesture detection overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                debugPrint('[_Media3PlayerWidgetState] Screen tapped');
                // Toggle controls visibility
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
              onScaleStart: _onCombinedScaleStart,
              onScaleUpdate: _onCombinedScaleUpdate,
              onScaleEnd: _onCombinedScaleEnd,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
            
            // Loading indicator
            if (!_isInitialized)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                ),
              ),
            
            // Buffering indicator (only show after delay to avoid flickering)
            if (_showBufferingIndicator && _isInitialized)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
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
                        color: Color(0xFF007AFF),
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
            
            // Custom video player controls with tap to toggle
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
            ),
              
            // Settings panel
            if (_showSettings)
              _buildSettingsPanel(),

              
          // Brightness indicator (when adjusting brightness) - Left side
          if (_isBrightnessAdjusting)
            _buildBrightnessIndicator(),

          // Volume indicator (when adjusting volume) - Right side
          if (_isVolumeAdjusting)
            _buildVolumeIndicator(),

          // Zoom indicator (for pinch-zoom level)
          if (_showZoomIndicator && _isZoomed && _currentZoomMode == ZoomMode.custom) // Only show during zoom gestures
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
          top: MediaQuery.of(context).padding.top + 8,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.3),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Row(
          children: [
            // Left section with back arrow and title
            Expanded(
              child: Row(
                children: [
                  _buildPureIconButton(
                    icon: Icons.arrow_back_ios_new,
                    onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.videoTitle ?? 'Video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Center section with speed and rotate controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSpeedMenu = !_showSpeedMenu;
                        _showVolumeSlider = false;
                      });
                      _resetControlsTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showSpeedMenu 
                          ? const Color(0xFF007AFF).withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentSpeed}x',
                        style: TextStyle(
                          color: _showSpeedMenu ? const Color(0xFF007AFF) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildPureIconButton(
                    icon: Icons.screen_rotation_outlined,
                    onPressed: () {
                      // Toggle between landscape orientations
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                      _resetControlsTimer();
                    },
                    tooltip: 'Rotate Screen',
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                _buildPureIconButton(
                  icon: Icons.closed_caption_outlined,
                  onPressed: () {
                    if (_controller != null) {
                      SubtitleTracksDialog.show(context, _controller!);
                    }
                    _resetControlsTimer();
                  },
                  tooltip: 'Subtitles',
                ),
                const SizedBox(width: 16),
                _buildPureIconButton(
                  icon: Icons.music_note_outlined,
                  onPressed: () {
                    _showAudioTracksBottomSheet();
                    _resetControlsTimer();
                  },
                  tooltip: 'Audio Tracks',
                ),
                const SizedBox(width: 16),
                _buildPureIconButton(
                  icon: Icons.tune,
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
                  tooltip: 'Settings',
                ),
              ],
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
          _buildCenterControlButton(
            icon: Icons.replay_10,
            onPressed: _seekBackward,
            size: 56,
            iconSize: 28,
            isSecondary: true,
          ),
          
          // Play/Pause - Main button
          _buildCenterControlButton(
            icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPressed: _togglePlayPause,
            size: 72,
            iconSize: 40,
            isSecondary: false,
          ),
          
          // Seek forward
          _buildCenterControlButton(
            icon: Icons.forward_10,
            onPressed: _seekForward,
            size: 56,
            iconSize: 28,
            isSecondary: true,
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced progress bar
            _buildProgressBar(),
            
            const SizedBox(height: 20),
            
            // Control buttons row with playback controls in center
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side - empty space for balance
                const SizedBox(width: 44),
                
                // Center playback controls grouped together
                Row(
                  children: [
                    _buildBottomControlButton(
                      icon: Icons.keyboard_double_arrow_left,
                      onPressed: () {
                        // Fast backward - seek 30 seconds
                        final newPosition = _position - const Duration(seconds: 30);
                        _controller?.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
                        _resetControlsTimer();
                      },
                      tooltip: 'Rewind 30s',
                    ),
                    const SizedBox(width: 16),
                    _buildBottomControlButton(
                      icon: Icons.keyboard_arrow_left,
                      onPressed: _seekBackward,
                      tooltip: 'Rewind 10s',
                    ),
                    const SizedBox(width: 20),
                    _buildBottomControlButton(
                      icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      onPressed: _togglePlayPause,
                      tooltip: _isPlaying ? 'Pause' : 'Play',
                      isActive: _isPlaying,
                    ),
                    const SizedBox(width: 20),
                    _buildBottomControlButton(
                      icon: Icons.keyboard_arrow_right,
                      onPressed: _seekForward,
                      tooltip: 'Forward 10s',
                    ),
                    const SizedBox(width: 16),
                    _buildBottomControlButton(
                      icon: Icons.keyboard_double_arrow_right,
                      onPressed: () {
                        // Fast forward - seek 30 seconds
                        final newPosition = _position + const Duration(seconds: 30);
                        final maxPosition = _duration.inMilliseconds > 0 ? _duration : newPosition;
                        _controller?.seekTo(newPosition > maxPosition ? maxPosition : newPosition);
                        _resetControlsTimer();
                      },
                      tooltip: 'Forward 30s',
                    ),
                  ],
                ),
                
                // Right side controls with volume and zoom
                Row(
                  children: [
                    _buildBottomControlButton(
                      icon: _currentVolume > 0.5 ? Icons.volume_up_rounded :
                            _currentVolume > 0 ? Icons.volume_down_rounded : Icons.volume_off_rounded,
                      onPressed: () {
                        setState(() {
                          _showVolumeSlider = !_showVolumeSlider;
                          _showSpeedMenu = false;
                        });
                        _resetControlsTimer();
                      },
                      tooltip: 'Volume',
                      isActive: _showVolumeSlider,
                    ),
                    const SizedBox(width: 16),
                    _buildBottomControlButton(
                      icon: _currentZoomMode == ZoomMode.fit ? Icons.fit_screen_rounded
                          : _currentZoomMode == ZoomMode.stretch ? Icons.aspect_ratio_rounded
                          : _currentZoomMode == ZoomMode.zoomToFill ? Icons.crop_rounded
                          : Icons.zoom_in_rounded,
                      onPressed: _cycleZoomMode,
                      tooltip: 'Zoom: ${_currentZoomMode.toString().split('.').last}',
                    ),
                    const SizedBox(width: 16),
                    if (_isZoomed)
                      _buildBottomControlButton(
                        icon: Icons.zoom_out_map_rounded,
                        onPressed: _resetZoom,
                        tooltip: 'Reset Zoom',
                      ),
                  ],
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
      bottom: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Playback Speed',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _changePlaybackSpeed(speed),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected 
                ? const Color(0xFF007AFF).withOpacity(0.3)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected 
                ? Border.all(
                    color: const Color(0xFF007AFF).withOpacity(0.5),
                    width: 1,
                  )
                : null,
            ),
            child: Center(
              child: Text(
                '${speed}x',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildVolumeSlider() {
    return Positioned(
      bottom: 100,
      right: 20,
      child: Container(
        height: 180,
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _currentVolume > 0.5 ? Icons.volume_up_rounded :
                _currentVolume > 0 ? Icons.volume_down_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbColor: const Color(0xFF007AFF),
                    activeTrackColor: const Color(0xFF007AFF),
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
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
            const SizedBox(height: 8),
            Text(
              '${(_currentVolume * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
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
    return Positioned(
      left: MediaQuery.of(context).size.width * 0.25 - 40, // Center of left half
      top: MediaQuery.of(context).size.height * 0.5 - 50,
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

  Widget _buildVolumeIndicator() {
    return Positioned(
      right: MediaQuery.of(context).size.width * 0.25 - 40, // Center of right half
      top: MediaQuery.of(context).size.height * 0.5 - 50,
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
              _getVolumeIcon(_currentVolume),
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              '${(_currentVolume * 100).round()}%',
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
                widthFactor: _currentVolume,
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

  // Helper method to build pure icon buttons
  Widget _buildPureIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double iconSize = 24,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  // Helper method to build center control buttons - now pure icons
  Widget _buildCenterControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    required double iconSize,
    required bool isSecondary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  // Helper method to build bottom control buttons
  Widget _buildBottomControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isActive = false,
    Widget? customChild,
    double? iconSize,
  }) {
    // Determine if this is a playback control (arrows and play/pause)
    final isPlaybackControl = icon == Icons.keyboard_double_arrow_left ||
                             icon == Icons.keyboard_arrow_left ||
                             icon == Icons.pause_rounded ||
                             icon == Icons.play_arrow_rounded ||
                             icon == Icons.keyboard_arrow_right ||
                             icon == Icons.keyboard_double_arrow_right;
    
    final size = iconSize ?? (isPlaybackControl ? 32 : 24);
    
    return GestureDetector(
      onTap: onPressed,
      child: customChild ?? Icon(
        icon,
        color: isActive ? const Color(0xFF007AFF) : Colors.white,
        size: size,
      ),
    );
  }

  // Enhanced progress bar widget
  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_position, showPlaceholder: true),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbColor: const Color(0xFF007AFF),
                      activeTrackColor: const Color(0xFF007AFF),
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                        elevation: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
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
                                _controller?.seekTo(Duration(milliseconds: seekTo));
                              }
                              setState(() {
                                _draggingPosition = null;
                              });
                              _resetControlsTimer();
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              Text(
                _formatDuration(_duration, showPlaceholder: true),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel timers
    _controlsTimer?.cancel();
    _errorClearTimer?.cancel();
    _bufferingTimer?.cancel();
    _zoomIndicatorTimer?.cancel();
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