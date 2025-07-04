import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/system_ui_helper.dart';
import 'simple_screen_orientation_manager.dart';

/// Pure ExoPlayer-based Video Player with advanced functionality
/// Uses native Android ExoPlayer through platform channels
class ExoPlayerVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String videoTitle;
  final bool autoPlay;
  final bool showControls;
  final Duration? startPosition;
  final VoidCallback? onBack;
  final Function(Duration)? onPositionChanged;
  final Function(Duration)? onBookmarkAdded;

  const ExoPlayerVideoPlayer({
    super.key,
    required this.videoPath,
    required this.videoTitle,
    this.autoPlay = true,
    this.showControls = true,
    this.startPosition,
    this.onBack,
    this.onPositionChanged,
    this.onBookmarkAdded,
  });

  @override
  State<ExoPlayerVideoPlayer> createState() => _ExoPlayerVideoPlayerState();
}

class _ExoPlayerVideoPlayerState extends State<ExoPlayerVideoPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Platform channel for ExoPlayer communication
  static const MethodChannel _channel = MethodChannel('exoplayer_video_player');
  
  // Player state
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _controlsVisible = true;
  bool _isLocked = false;
  bool _isBuffering = false;
  String? _errorMessage;
  
  // Playback state
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  Size _videoSize = Size.zero;
  
  // UI controls
  bool _showSpeedMenu = false;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _hideControlsTimer;
  
  // Animation controllers
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  late AnimationController _speedMenuController;
  late Animation<double> _speedMenuAnimation;
  
  // Gesture detection
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  
  // Screen orientation manager
  final SimpleScreenOrientationManager _orientationManager = 
      SimpleScreenOrientationManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializePlayer();
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlayerStateChanged':
          final isPlaying = call.arguments['isPlaying'] as bool;
          final isBuffering = call.arguments['isBuffering'] as bool;
          setState(() {
            _isPlaying = isPlaying;
            _isBuffering = isBuffering;
          });
          break;
        case 'onPositionChanged':
          final position = Duration(milliseconds: call.arguments['position']);
          setState(() {
            _currentPosition = position;
          });
          widget.onPositionChanged?.call(position);
          break;
        case 'onDurationChanged':
          final duration = Duration(milliseconds: call.arguments['duration']);
          setState(() {
            _videoDuration = duration;
          });
          break;
        case 'onVideoSizeChanged':
          final width = call.arguments['width'] as double;
          final height = call.arguments['height'] as double;
          setState(() {
            _videoSize = Size(width, height);
          });
          break;
        case 'onError':
          final error = call.arguments['error'] as String;
          setState(() {
            _errorMessage = error;
          });
          break;
        case 'onPlayerReady':
          setState(() {
            _isInitialized = true;
          });
          if (widget.autoPlay) {
            _play();
          }
          if (widget.startPosition != null) {
            _seekTo(widget.startPosition!);
          }
          break;
      }
    });
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));

    _speedMenuController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _speedMenuAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _speedMenuController,
      curve: Curves.easeInOut,
    ));

    _controlsAnimationController.forward();
  }

  Future<void> _initializePlayer() async {
    try {
      await _channel.invokeMethod('initialize', {
        'videoPath': widget.videoPath,
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }

  Future<void> _play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      print('Error playing video: $e');
    }
  }

  Future<void> _pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      print('Error pausing video: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _channel.invokeMethod('seekTo', {
        'position': position.inMilliseconds,
      });
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setPlaybackSpeed', {
        'speed': speed,
      });
      setState(() {
        _playbackSpeed = speed;
      });
    } catch (e) {
      print('Error setting playback speed: $e');
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    if (_controlsVisible) {
      _controlsAnimationController.forward();
      _startHideControlsTimer();
    } else {
      _controlsAnimationController.reverse();
      _hideControlsTimer?.cancel();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controlsVisible && _isPlaying) {
        _toggleControls();
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
      _controlsAnimationController.forward();
    }
    _startHideControlsTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ExoPlayer View
            Center(
              child: AspectRatio(
                aspectRatio: _videoSize.width > 0 && _videoSize.height > 0
                    ? _videoSize.width / _videoSize.height
                    : 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _isInitialized
                      ? AndroidView(
                          viewType: 'nextplayer_view',
                          creationParams: {'videoPath': widget.videoPath},
                          creationParamsCodec: const StandardMessageCodec(),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),

            // Error overlay
            if (_errorMessage != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
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
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                          _initializePlayer();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),

            // Gesture detector for controls
            GestureDetector(
              onTap: _toggleControls,
              onDoubleTap: _togglePlayPause,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),

            // Controls overlay
            if (widget.showControls)
              AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _controlsAnimation.value,
                    child: _buildControlsOverlay(),
                  );
                },
              ),

            // Loading indicator
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top controls
          _buildTopControls(),
          
          // Center controls
          Expanded(
            child: _buildCenterControls(),
          ),
          
          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.videoTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isLocked = !_isLocked;
              });
            },
            icon: Icon(
              _isLocked ? Icons.lock : Icons.lock_open,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: () {
            final newPosition = _currentPosition - const Duration(seconds: 10);
            _seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
          },
          icon: const Icon(
            Icons.replay_10,
            color: Colors.white,
            size: 48,
          ),
        ),
        IconButton(
          onPressed: _togglePlayPause,
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 64,
          ),
        ),
        IconButton(
          onPressed: () {
            final newPosition = _currentPosition + const Duration(seconds: 10);
            _seekTo(newPosition < _videoDuration ? newPosition : _videoDuration);
          },
          icon: const Icon(
            Icons.forward_10,
            color: Colors.white,
            size: 48,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.red,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _videoDuration.inMilliseconds > 0
                        ? _currentPosition.inMilliseconds / _videoDuration.inMilliseconds
                        : 0.0,
                    onChanged: (value) {
                      final position = Duration(
                        milliseconds: (value * _videoDuration.inMilliseconds).round(),
                      );
                      _seekTo(position);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_videoDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _showSpeedMenu = !_showSpeedMenu;
                  });
                },
                icon: const Icon(
                  Icons.speed,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              IconButton(
                onPressed: () => _orientationManager.toggle(),
                icon: const Icon(
                  Icons.screen_rotation,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              IconButton(
                onPressed: () {
                  if (widget.onBookmarkAdded != null) {
                    widget.onBookmarkAdded!(_currentPosition);
                  }
                },
                icon: const Icon(
                  Icons.bookmark_add,
                  color: Colors.white,
                  size: 24,
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
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    _speedMenuController.dispose();
    _channel.invokeMethod('dispose');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}