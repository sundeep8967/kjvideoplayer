import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'enhanced_nextplayer_controller.dart';

/// Enhanced NextPlayer Widget with Professional Video Player Features
/// Utilizes NextPlayer's advanced capabilities including gestures, PiP, and professional controls
class EnhancedNextPlayerWidget extends StatefulWidget {
  final String videoPath;
  final String? videoTitle;
  final EnhancedNextPlayerController? controller;
  final bool autoPlay;
  final bool showControls;
  final bool enableGestures;
  final bool enablePictureInPicture;
  final bool enableBackgroundPlayback;
  final VideoZoom initialVideoZoom;
  final double initialPlaybackSpeed;
  final LoopMode initialLoopMode;
  final DecoderPriority decoderPriority;
  final Function(EnhancedNextPlayerController)? onPlayerCreated;
  final Function(NextPlayerEvent)? onEvent;
  final Function(NextPlayerState)? onStateChanged;
  final Function(String)? onError;

  const EnhancedNextPlayerWidget({
    super.key,
    required this.videoPath,
    this.videoTitle,
    this.controller,
    this.autoPlay = true,
    this.showControls = true,
    this.enableGestures = true,
    this.enablePictureInPicture = true,
    this.enableBackgroundPlayback = false,
    this.initialVideoZoom = VideoZoom.bestFit,
    this.initialPlaybackSpeed = 1.0,
    this.initialLoopMode = LoopMode.off,
    this.decoderPriority = DecoderPriority.preferDevice,
    this.onPlayerCreated,
    this.onEvent,
    this.onStateChanged,
    this.onError,
  });

  @override
  State<EnhancedNextPlayerWidget> createState() => _EnhancedNextPlayerWidgetState();
}

class _EnhancedNextPlayerWidgetState extends State<EnhancedNextPlayerWidget>
    with TickerProviderStateMixin {
  late EnhancedNextPlayerController _controller;
  bool _controlsVisible = true;
  bool _isInitialized = false;
  String? _errorMessage;
  
  // Animation controllers for professional UI
  late AnimationController _controlsAnimationController;
  late AnimationController _gestureAnimationController;
  late Animation<double> _controlsOpacity;
  late Animation<double> _gestureOpacity;
  
  // Gesture state
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  bool _showSeekIndicator = false;
  double _gestureValue = 0.0;
  String _gestureText = '';
  
  // Control state
  Timer? _hideControlsTimer;
  
  void _onPlatformViewCreated(int id) {
    _controller = widget.controller ?? EnhancedNextPlayerController();
    
    // Initialize the plugin first
    _controller.initializePlugin().then((result) {
      print('Enhanced NextPlayer plugin initialized: $result');
    }).catchError((error) {
      print('Failed to initialize Enhanced NextPlayer plugin: $error');
    });
    
    // Set up event listeners
    _controller.events.listen((event) {
      widget.onEvent?.call(event);
    });
    
    _controller.stateStream.listen((state) {
      setState(() {
        _isInitialized = state == NextPlayerState.ready;
      });
      widget.onStateChanged?.call(state);
    });
    
    widget.onPlayerCreated?.call(_controller);
  }
  bool _isLocked = false;
  
  @override
  void initState() {
    super.initState();
    _initializeController();
    _setupAnimations();
    _setupEventListeners();
  }
  
  void _initializeController() {
    _controller = widget.controller ?? EnhancedNextPlayerController();
    
    // Initialize with advanced settings
    _initializePlayer();
    
    if (widget.onPlayerCreated != null) {
      widget.onPlayerCreated!(_controller);
    }
  }
  
  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _gestureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _controlsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _gestureOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gestureAnimationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.showControls) {
      _controlsAnimationController.forward();
    }
  }
  
  void _setupEventListeners() {
    _controller.events.listen((event) {
      if (widget.onEvent != null) {
        widget.onEvent!(event);
      }
      
      switch (event) {
        case NextPlayerEvent.initialized:
          setState(() {
            _isInitialized = true;
            _errorMessage = null;
          });
          break;
          
        case NextPlayerEvent.error:
          setState(() {
            _errorMessage = 'Playback error occurred';
          });
          if (widget.onError != null) {
            widget.onError!(_errorMessage!);
          }
          break;
          
        case NextPlayerEvent.volumeGesture:
          _showGestureIndicator('Volume', (_controller.volume * 100).round());
          break;
          
        case NextPlayerEvent.brightnessGesture:
          _showGestureIndicator('Brightness', 50); // Placeholder value
          break;
          
        case NextPlayerEvent.seekGesture:
          _showGestureIndicator('Seek', _controller.position.inSeconds);
          break;
          
        default:
          break;
      }
    });
    
    _controller.stateStream.listen((state) {
      if (widget.onStateChanged != null) {
        widget.onStateChanged!(state);
      }
      
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        widget.videoPath,
        title: widget.videoTitle,
      );
      
      // Configure advanced settings
      await _controller.setVideoZoom(widget.initialVideoZoom);
      await _controller.setPlaybackSpeed(widget.initialPlaybackSpeed);
      await _controller.setLoopMode(widget.initialLoopMode);
      await _controller.setDecoderPriority(widget.decoderPriority);
      await _controller.enableGestures(widget.enableGestures);
      await _controller.enableBackgroundPlayback(widget.enableBackgroundPlayback);
      
      if (widget.autoPlay) {
        await _controller.play();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }
  
  void _showGestureIndicator(String type, int value) {
    setState(() {
      _gestureText = '$type: $value${type == 'Volume' || type == 'Brightness' ? '%' : 's'}';
      _gestureValue = value.toDouble();
    });
    
    _gestureAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _gestureAnimationController.reverse();
        }
      });
    });
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
      if (mounted && _controlsVisible && !_isLocked) {
        _toggleControls();
      }
    });
  }
  
  void _togglePlayPause() {
    if (_controller.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }
  
  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
    
    if (_isLocked) {
      _hideControlsTimer?.cancel();
      _controlsAnimationController.reverse();
    } else {
      _controlsAnimationController.forward();
      _startHideControlsTimer();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main video player view
          Positioned.fill(
            child: _buildPlayerView(),
          ),
          
          // Gesture indicators
          if (widget.enableGestures) ...[
            _buildGestureIndicator(),
          ],
          
          // Controls overlay
          if (widget.showControls && !_isLocked) ...[
            _buildControlsOverlay(),
          ],
          
          // Lock controls
          if (_isLocked) ...[
            _buildLockControls(),
          ],
          
          // Error overlay
          if (_errorMessage != null) ...[
            _buildErrorOverlay(),
          ],
          
          // Loading indicator
          if (!_isInitialized && _errorMessage == null) ...[
            _buildLoadingIndicator(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPlayerView() {
    return GestureDetector(
      onTap: () {
        if (widget.showControls) {
          _toggleControls();
        }
      },
      onDoubleTap: () {
        _togglePlayPause();
      },
      child: AndroidView(
        viewType: 'enhanced_nextplayer',
        creationParams: {
          'videoPath': widget.videoPath,
          'videoTitle': widget.videoTitle,
          'autoPlay': widget.autoPlay,
          'enableGestures': widget.enableGestures,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
  
  Widget _buildGestureIndicator() {
    return AnimatedBuilder(
      animation: _gestureOpacity,
      builder: (context, child) {
        return Opacity(
          opacity: _gestureOpacity.value,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _gestureText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildControlsOverlay() {
    return AnimatedBuilder(
      animation: _controlsOpacity,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsOpacity.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: Column(
              children: [
                _buildTopControls(),
                const Spacer(),
                _buildCenterControls(),
                const Spacer(),
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
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.videoTitle ?? 'Video Player',
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
              onPressed: _toggleLock,
              icon: Icon(
                _isLocked ? Icons.lock : Icons.lock_open,
                color: Colors.white,
              ),
            ),
            if (widget.enablePictureInPicture) ...[
              IconButton(
                onPressed: () => _controller.enterPictureInPicture(),
                icon: const Icon(Icons.picture_in_picture, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: () => _controller.seekTo(
            Duration(seconds: (_controller.position.inSeconds - 10).clamp(0, _controller.duration.inSeconds)),
          ),
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _togglePlayPause,
            icon: Icon(
              _controller.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _controller.seekTo(
            Duration(seconds: (_controller.position.inSeconds + 10).clamp(0, _controller.duration.inSeconds)),
          ),
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
        ),
      ],
    );
  }
  
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          StreamBuilder<NextPlayerEvent>(
            stream: _controller.events.where((event) => event == NextPlayerEvent.positionChanged),
            builder: (context, snapshot) {
              final progress = _controller.duration.inMilliseconds > 0
                  ? _controller.position.inMilliseconds / _controller.duration.inMilliseconds
                  : 0.0;
              
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.red,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (value) {
                    final position = Duration(
                      milliseconds: (value * _controller.duration.inMilliseconds).round(),
                    );
                    _controller.seekTo(position);
                  },
                ),
              );
            },
          ),
          
          // Control buttons row
          Row(
            children: [
              Text(
                _formatDuration(_controller.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showSpeedDialog(),
                icon: const Icon(Icons.speed, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _showVideoZoomDialog(),
                icon: const Icon(Icons.aspect_ratio, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _showTrackSelectionDialog(),
                icon: const Icon(Icons.subtitles, color: Colors.white),
              ),
              const Spacer(),
              Text(
                _formatDuration(_controller.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLockControls() {
    return Center(
      child: GestureDetector(
        onTap: _toggleLock,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
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
  
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
    );
  }
  
  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      ),
    );
  }
  
  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              leading: Radio<double>(
                value: speed,
                groupValue: _controller.playbackSpeed,
                onChanged: (value) {
                  if (value != null) {
                    _controller.setPlaybackSpeed(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  void _showVideoZoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Zoom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: VideoZoom.values.map((zoom) {
            return ListTile(
              title: Text(_getZoomName(zoom)),
              leading: Radio<VideoZoom>(
                value: zoom,
                groupValue: _controller.videoZoom,
                onChanged: (value) {
                  if (value != null) {
                    _controller.setVideoZoom(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  void _showTrackSelectionDialog() async {
    final audioTracks = await _controller.getAudioTracks();
    final subtitleTracks = await _controller.getSubtitleTracks();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio & Subtitles'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Audio Tracks:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...audioTracks.map((track) => ListTile(
              title: Text(track.label.isNotEmpty ? track.label : 'Track ${track.index}'),
              subtitle: Text(track.language),
              leading: Radio<int>(
                value: track.index,
                groupValue: audioTracks.firstWhere((t) => t.isSelected, orElse: () => audioTracks.first).index,
                onChanged: (value) {
                  if (value != null) {
                    _controller.selectAudioTrack(value);
                  }
                },
              ),
            )),
            const SizedBox(height: 16),
            const Text('Subtitle Tracks:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...subtitleTracks.map((track) => ListTile(
              title: Text(track.label.isNotEmpty ? track.label : 'Track ${track.index}'),
              subtitle: Text('${track.language}${track.isExternal ? ' (External)' : ''}'),
              leading: Radio<int>(
                value: track.index,
                groupValue: subtitleTracks.firstWhere((t) => t.isSelected, orElse: () => subtitleTracks.first).index,
                onChanged: (value) {
                  if (value != null) {
                    _controller.selectSubtitleTrack(value);
                  }
                },
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  String _getZoomName(VideoZoom zoom) {
    switch (zoom) {
      case VideoZoom.bestFit:
        return 'Best Fit';
      case VideoZoom.stretch:
        return 'Stretch';
      case VideoZoom.crop:
        return 'Crop';
      case VideoZoom.hundredPercent:
        return '100%';
    }
  }
  
  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    _gestureAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }
}