import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nextplayer_widget.dart';

/// Complete NextPlayer Video Player with UI Controls
/// Uses ExoPlayer for maximum stability and performance
class NextPlayerVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String videoTitle;
  final bool autoPlay;
  final bool showControls;

  const NextPlayerVideoPlayer({
    Key? key,
    required this.videoPath,
    required this.videoTitle,
    this.autoPlay = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<NextPlayerVideoPlayer> createState() => _NextPlayerVideoPlayerState();
}

class _NextPlayerVideoPlayerState extends State<NextPlayerVideoPlayer>
    with TickerProviderStateMixin {
  NextPlayerController? _controller;
  
  // Player state
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _controlsVisible = true;
  bool _isLocked = false;
  bool _isFullscreen = false;
  String? _errorMessage;
  
  // Playback state
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  Size _videoSize = Size.zero;
  
  // UI controls
  bool _showSpeedMenu = false;
  Timer? _hideControlsTimer;
  
  // Animation controllers
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  
  // Speed options
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setOrientation();
    if (widget.showControls) {
      _startHideControlsTimer();
    }
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
    _controlsAnimationController.forward();
  }

  void _setOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onPlayerCreated(NextPlayerController controller) {
    _controller = controller;
  }

  void _onInitialized() {
    setState(() {
      _isInitialized = true;
    });
  }

  void _onPlaying() {
    setState(() {
      _isPlaying = true;
    });
  }

  void _onPaused() {
    setState(() {
      _isPlaying = false;
    });
  }

  void _onStopped() {
    setState(() {
      _isPlaying = false;
    });
  }

  void _onTimeChanged(Duration time) {
    setState(() {
      _currentPosition = time;
    });
  }

  void _onDurationChanged(Duration duration) {
    setState(() {
      _videoDuration = duration;
    });
  }

  void _onError(String error) {
    setState(() {
      _errorMessage = error;
    });
  }

  void _onVideoSizeChanged(Size size) {
    setState(() {
      _videoSize = size;
    });
  }

  void _onPlaybackSpeedChanged(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  void _changeSpeed(double speed) {
    _controller?.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
      _showSpeedMenu = false;
    });
  }

  void _toggleControls() {
    if (!widget.showControls) return;
    
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

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
    
    if (_isLocked) {
      _hideControlsTimer?.cancel();
      setState(() {
        _controlsVisible = false;
      });
      _controlsAnimationController.reverse();
    } else {
      _toggleControls();
    }
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
  void dispose() {
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    _controller?.dispose();
    
    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Player
            Center(
              child: _errorMessage != null
                  ? _buildErrorWidget()
                  : _buildVideoPlayer(),
            ),
            
            // Controls Overlay
            if (_controlsVisible && !_isLocked && widget.showControls)
              _buildControlsOverlay(),
            
            // Lock Button (always visible)
            if (widget.showControls)
              Positioned(
                top: 20,
                right: 20,
                child: _buildLockButton(),
              ),
            
            // Speed Menu
            if (_showSpeedMenu)
              _buildSpeedMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: widget.showControls ? _toggleControls : null,
      child: AspectRatio(
        aspectRatio: _videoSize.width > 0 && _videoSize.height > 0 
            ? _videoSize.width / _videoSize.height 
            : 16 / 9,
        child: NextPlayerWidget(
          videoPath: widget.videoPath,
          videoTitle: widget.videoTitle,
          autoPlay: widget.autoPlay,
          onPlayerCreated: _onPlayerCreated,
          onInitialized: _onInitialized,
          onPlaying: _onPlaying,
          onPaused: _onPaused,
          onStopped: _onStopped,
          onTimeChanged: _onTimeChanged,
          onDurationChanged: _onDurationChanged,
          onError: _onError,
          onVideoSizeChanged: _onVideoSizeChanged,
          onPlaybackSpeedChanged: _onPlaybackSpeedChanged,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Error playing video',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.videoTitle,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'NextPlayer',
            style: const TextStyle(color: Colors.orange, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
          onPressed: () {
            final newPosition = _currentPosition - const Duration(seconds: 10);
            _seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
          },
        ),
        const SizedBox(width: 32),
        Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
            onPressed: _togglePlayPause,
          ),
        ),
        const SizedBox(width: 32),
        IconButton(
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
          onPressed: () {
            final newPosition = _currentPosition + const Duration(seconds: 10);
            _seekTo(newPosition > _videoDuration ? _videoDuration : newPosition);
          },
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.orange,
                    inactiveTrackColor: Colors.grey,
                    thumbColor: Colors.orange,
                    overlayColor: Colors.orange.withOpacity(0.3),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.speed, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showSpeedMenu = !_showSpeedMenu;
                  });
                },
              ),
              Text(
                '${_playbackSpeed}x',
                style: const TextStyle(color: Colors.orange, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () {
                  // Fullscreen toggle implementation
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(
          _isLocked ? Icons.lock : Icons.lock_open,
          color: Colors.white,
        ),
        onPressed: _toggleLock,
      ),
    );
  }

  Widget _buildSpeedMenu() {
    return Positioned(
      bottom: 120,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _speedOptions.map((speed) {
            return InkWell(
              onTap: () => _changeSpeed(speed),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: _playbackSpeed == speed ? Colors.orange : Colors.white,
                    fontSize: 16,
                    fontWeight: _playbackSpeed == speed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}