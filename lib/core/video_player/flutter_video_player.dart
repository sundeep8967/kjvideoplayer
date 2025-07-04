import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Removed video_player dependency - using ExoPlayer instead
import '../utils/system_ui_helper.dart';
import 'simple_screen_orientation_manager.dart';

/// Pure Flutter Video Player with advanced functionality
/// Uses native Flutter video_player package for reliable video playback
class FlutterVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String videoTitle;
  final bool autoPlay;
  final bool showControls;
  final Duration? startPosition;
  final VoidCallback? onBack;
  final Function(Duration)? onPositionChanged;
  final Function(Duration)? onBookmarkAdded;

  const FlutterVideoPlayer({
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
  State<FlutterVideoPlayer> createState() => _FlutterVideoPlayerState();
}

class _FlutterVideoPlayerState extends State<FlutterVideoPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Video player controller - using ExoPlayer instead
  // VideoPlayerController? _controller;
  
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
  
  // Gesture and settings
  double _currentVolume = 1.0;
  double _currentBrightness = 1.0;
  
  // Speed options (same as NextPlayer)
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializePlayer();
    SystemUIHelper.setVideoPlaybackUI();
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
      curve: Curves.easeOut,
    ));

    _controlsAnimationController.forward();
  }

  Future<void> _initializePlayer() async {
    try {
      // Check if file exists
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'Video file not found';
        });
        return;
      }

      // Initialize video player controller
      // _controller = VideoPlayerController.file(file); // Replaced with ExoPlayer
      
      // Add listeners - commented out for ExoPlayer migration
      // _controller!.addListener(_videoPlayerListener);
      
      // Initialize the controller - commented out for ExoPlayer migration
      // await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          // _videoDuration = _controller!.value.duration;
          // _videoSize = _controller!.value.size;
        });

        // Seek to start position if provided
        if (widget.startPosition != null) {
          await _controller!.seekTo(widget.startPosition!);
        }

        // Auto play if enabled
        if (widget.autoPlay) {
          await _controller!.play();
        }

        _startPositionUpdater();
        _resetHideControlsTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  void _videoPlayerListener() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;
    
    setState(() {
      _isPlaying = value.isPlaying;
      _isBuffering = value.isBuffering;
      _currentPosition = value.position;
      
      if (value.hasError) {
        _errorMessage = value.errorDescription ?? 'Unknown error occurred';
      }
    });

    // Notify position changes
    widget.onPositionChanged?.call(_currentPosition);
  }

  void _startPositionUpdater() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _controller == null || !_controller!.value.isInitialized) {
        timer.cancel();
        return;
      }
      
      if (_controller!.value.isPlaying) {
        setState(() {
          _currentPosition = _controller!.value.position;
        });
        widget.onPositionChanged?.call(_currentPosition);
      }
    });
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_isPlaying && !_isLocked) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controlsVisible) {
          _hideControls();
        }
      });
    }
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
      _controlsAnimationController.forward();
    }
    _resetHideControlsTimer();
  }

  void _hideControls() {
    if (_controlsVisible && !_isLocked) {
      setState(() {
        _controlsVisible = false;
      });
      _controlsAnimationController.reverse();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
      _resetHideControlsTimer();
    }
  }

  void _seekTo(Duration position) {
    if (_controller == null || !_isInitialized) return;
    _controller!.seekTo(position);
  }

  void _seekRelative(Duration offset) {
    final newPosition = _currentPosition + offset;
    Duration clampedPosition;
    
    if (newPosition < Duration.zero) {
      clampedPosition = Duration.zero;
    } else if (newPosition > _videoDuration) {
      clampedPosition = _videoDuration;
    } else {
      clampedPosition = newPosition;
    }
    
    _seekTo(clampedPosition);
  }

  void _setPlaybackSpeed(double speed) {
    if (_controller == null || !_isInitialized) return;
    
    setState(() {
      _playbackSpeed = speed;
      _showSpeedMenu = false;
    });
    
    _controller!.setPlaybackSpeed(speed);
    _speedMenuController.reverse();
  }

  void _toggleSpeedMenu() {
    setState(() {
      _showSpeedMenu = !_showSpeedMenu;
    });
    
    if (_showSpeedMenu) {
      _speedMenuController.forward();
    } else {
      _speedMenuController.reverse();
    }
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
    
    if (_isLocked) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _onTap() {
    if (_isLocked) return;
    
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _onDoubleTapLeft() {
    _seekRelative(const Duration(seconds: -10));
    _showControls();
  }

  void _onDoubleTapRight() {
    _seekRelative(const Duration(seconds: 10));
    _showControls();
  }

  void _onBack() {
    SystemUIHelper.restoreNormalUI();
    widget.onBack?.call();
    Navigator.of(context).pop();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoPlayerListener);
    _controller?.dispose();
    _controlsAnimationController.dispose();
    _speedMenuController.dispose();
    SystemUIHelper.restoreNormalUI();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          Center(
            child: _buildVideoPlayer(),
          ),
          
          // Controls overlay
          if (widget.showControls)
            _buildControlsOverlay(),
          
          // Error overlay
          if (_errorMessage != null)
            _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return const SizedBox.shrink();
    }
    
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap: _onTap,
      onDoubleTap: () {
        // Handle double tap based on position
        final screenWidth = MediaQuery.of(context).size.width;
        // This is a simplified version - you'd need to track tap position
        _onDoubleTapRight();
      },
      child: AspectRatio(
        aspectRatio: 16/9, // Default aspect ratio
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Use ExoPlayerVideoPlayer instead',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsVisible ? _controlsAnimation.value : 0.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
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
          ),
        );
      },
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Back button
            IconButton(
              onPressed: _onBack,
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Video title
            Expanded(
              child: Text(
                widget.videoTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Lock button
            IconButton(
              onPressed: _toggleLock,
              icon: Icon(
                _isLocked ? Icons.lock : Icons.lock_open,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    if (_isLocked) {
      return Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isLocked = false;
            });
            _showControls();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.lock,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Seek backward
        _buildControlButton(
          icon: Icons.replay_10,
          onPressed: () => _onDoubleTapLeft(),
        ),
        
        // Play/Pause
        _buildControlButton(
          icon: _isPlaying ? Icons.pause : Icons.play_arrow,
          onPressed: _togglePlayPause,
          size: 64,
        ),
        
        // Seek forward
        _buildControlButton(
          icon: Icons.forward_10,
          onPressed: () => _onDoubleTapRight(),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF007AFF),
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: const Color(0xFF007AFF),
                    overlayColor: const Color(0xFF007AFF).withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
              
              const SizedBox(width: 16),
              
              Text(
                _formatDuration(_videoDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed control
              _buildControlButton(
                icon: Icons.speed,
                label: '${_playbackSpeed}x',
                onPressed: _toggleSpeedMenu,
              ),
              
              // Bookmark
              _buildControlButton(
                icon: Icons.bookmark_add,
                onPressed: () {
                  widget.onBookmarkAdded?.call(_currentPosition);
                },
              ),
              
              // Fullscreen (placeholder)
              _buildControlButton(
                icon: Icons.fullscreen,
                onPressed: () {
                  // Fullscreen toggle would go here
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? label,
    double size = 32,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: size,
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _onBack,
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}