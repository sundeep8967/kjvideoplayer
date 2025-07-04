import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/video_model.dart';
import '../../../enhanced_nextplayer/enhanced_nextplayer_widget.dart';
import '../../../enhanced_nextplayer/enhanced_nextplayer_controller.dart';
import '../../../core/utils/haptic_feedback_helper.dart';

/// Enhanced Video Player Screen with NextPlayer Advanced Features
/// Demonstrates professional video player capabilities including:
/// - Advanced gesture controls (volume, brightness, seek, zoom)
/// - Picture-in-Picture support
/// - Multi-track audio/subtitle support
/// - Professional UI controls
class EnhancedVideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const EnhancedVideoPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<EnhancedVideoPlayerScreen> createState() => _EnhancedVideoPlayerScreenState();
}

class _EnhancedVideoPlayerScreenState extends State<EnhancedVideoPlayerScreen>
    with TickerProviderStateMixin {
  late EnhancedNextPlayerController _controller;
  bool _isInitialized = false;
  bool _controlsVisible = true;
  bool _isLocked = false;
  bool _showSettings = false;
  String? _errorMessage;
  
  // Player state
  NextPlayerState _playerState = NextPlayerState.idle;
  VideoZoom _currentZoom = VideoZoom.bestFit;
  double _currentSpeed = 1.0;
  LoopMode _currentLoopMode = LoopMode.off;
  
  // Tracks
  final List<Map<String, dynamic>> _audioTracks = [];
  final List<Map<String, dynamic>> _subtitleTracks = [];
  int _selectedAudioTrack = -1;
  int _selectedSubtitleTrack = -1;
  
  // Animation controllers
  late AnimationController _controlsAnimationController;
  late AnimationController _settingsAnimationController;
  late Animation<double> _controlsOpacity;
  late Animation<Offset> _settingsSlideAnimation;
  
  // Control timer
  Timer? _hideControlsTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setLandscapeOrientation();
    _controller = EnhancedNextPlayerController();
    _startHideControlsTimer();
  }
  
  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _controlsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _settingsSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _controlsAnimationController.forward();
  }
  
  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  
  void _onPlayerCreated(EnhancedNextPlayerController controller) {
    _controller = controller;
  }
  
  void _onEvent(NextPlayerEvent event) {
    switch (event) {
      case NextPlayerEvent.initialized:
        setState(() {
          _isInitialized = true;
        });
        break;
      case NextPlayerEvent.error:
        setState(() {
          _errorMessage = 'Error playing video';
        });
        break;
      default:
        break;
    }
  }
  
  void _onStateChanged(NextPlayerState state) {
    setState(() {
      _playerState = state;
    });
  }
  
  void _onError(String error) {
    setState(() {
      _errorMessage = error;
    });
  }
  
  void _toggleControls() {
    if (_isLocked) return;
    
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
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible && !_isLocked && !_showSettings) {
        _toggleControls();
      }
    });
  }
  
  void _toggleLock() {
    HapticFeedbackHelper.lightImpact();
    setState(() {
      _isLocked = !_isLocked;
    });
    
    if (_isLocked) {
      _hideControlsTimer?.cancel();
      setState(() {
        _controlsVisible = false;
        _showSettings = false;
      });
      _controlsAnimationController.reverse();
      _settingsAnimationController.reverse();
    } else {
      _toggleControls();
    }
  }
  
  void _toggleSettings() {
    HapticFeedbackHelper.lightImpact();
    setState(() {
      _showSettings = !_showSettings;
    });
    
    if (_showSettings) {
      _settingsAnimationController.forward();
      _hideControlsTimer?.cancel();
    } else {
      _settingsAnimationController.reverse();
      _startHideControlsTimer();
    }
  }
  
  void _changeVideoZoom(VideoZoom zoom) {
    _controller.setVideoZoom(zoom);
    setState(() {
      _currentZoom = zoom;
    });
    HapticFeedbackHelper.selectionClick();
  }
  
  void _changePlaybackSpeed(double speed) {
    _controller.setPlaybackSpeed(speed);
    setState(() {
      _currentSpeed = speed;
    });
    HapticFeedbackHelper.selectionClick();
  }
  
  void _changeLoopMode(LoopMode mode) {
    _controller.setLoopMode(mode);
    setState(() {
      _currentLoopMode = mode;
    });
    HapticFeedbackHelper.selectionClick();
  }
  
  void _enterPictureInPicture() async {
    try {
      await _controller.enterPictureInPicture();
      HapticFeedbackHelper.success();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Picture-in-Picture not supported: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    _settingsAnimationController.dispose();
    _controller.dispose();
    
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
      body: Stack(
        children: [
          // Enhanced NextPlayer Video Player
          Center(
            child: _errorMessage != null
                ? _buildErrorWidget()
                : EnhancedNextPlayerWidget(
                    videoPath: widget.video.path,
                    videoTitle: widget.video.displayName,
                    controller: _controller,
                    autoPlay: true,
                    showControls: false, // We'll use custom controls
                    enableGestures: true,
                    enablePictureInPicture: true,
                    onPlayerCreated: _onPlayerCreated,
                    onEvent: _onEvent,
                    onStateChanged: _onStateChanged,
                    onError: _onError,
                  ),
          ),
          
          // Custom Controls Overlay
          if (_controlsVisible && !_isLocked)
            _buildControlsOverlay(),
          
          // Settings Panel
          if (_showSettings)
            _buildSettingsPanel(),
          
          // Lock Button (always visible)
          Positioned(
            top: 40,
            right: 20,
            child: _buildLockButton(),
          ),
          
          // Loading indicator
          if (!_isInitialized && _errorMessage == null)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.video.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture, color: Colors.white),
            onPressed: _enterPictureInPicture,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _toggleSettings,
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
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
          onPressed: () => _controller.seekRelative(const Duration(seconds: -10)),
        ),
        const SizedBox(width: 40),
        Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _playerState == NextPlayerState.playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 56,
            ),
            onPressed: () {
              if (_playerState == NextPlayerState.playing) {
                _controller.pause();
              } else {
                _controller.play();
              }
            },
          ),
        ),
        const SizedBox(width: 40),
        IconButton(
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
          onPressed: () => _controller.seekRelative(const Duration(seconds: 10)),
        ),
      ],
    );
  }
  
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            '${_currentSpeed}x',
            style: const TextStyle(color: Colors.orange, fontSize: 16),
          ),
          const SizedBox(width: 16),
          Text(
            _getZoomText(_currentZoom),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          Text(
            'Enhanced NextPlayer',
            style: const TextStyle(color: Colors.orange, fontSize: 12),
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
  
  Widget _buildSettingsPanel() {
    return SlideTransition(
      position: _settingsSlideAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 300,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Player Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _toggleSettings,
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildSettingsSection(
                      'Video Zoom',
                      _buildZoomOptions(),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      'Playback Speed',
                      _buildSpeedOptions(),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      'Loop Mode',
                      _buildLoopOptions(),
                    ),
                    const SizedBox(height: 24),
                    if (_audioTracks.isNotEmpty)
                      _buildSettingsSection(
                        'Audio Track',
                        _buildAudioTrackOptions(),
                      ),
                    if (_subtitleTracks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSettingsSection(
                        'Subtitles',
                        _buildSubtitleOptions(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingsSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
  
  Widget _buildZoomOptions() {
    return Column(
      children: VideoZoom.values.map((zoom) {
        return RadioListTile<VideoZoom>(
          title: Text(
            _getZoomText(zoom),
            style: const TextStyle(color: Colors.white),
          ),
          value: zoom,
          groupValue: _currentZoom,
          onChanged: (value) => _changeVideoZoom(value!),
          activeColor: Colors.orange,
        );
      }).toList(),
    );
  }
  
  Widget _buildSpeedOptions() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return Column(
      children: speeds.map((speed) {
        return RadioListTile<double>(
          title: Text(
            '${speed}x',
            style: const TextStyle(color: Colors.white),
          ),
          value: speed,
          groupValue: _currentSpeed,
          onChanged: (value) => _changePlaybackSpeed(value!),
          activeColor: Colors.orange,
        );
      }).toList(),
    );
  }
  
  Widget _buildLoopOptions() {
    return Column(
      children: LoopMode.values.map((mode) {
        return RadioListTile<LoopMode>(
          title: Text(
            _getLoopModeText(mode),
            style: const TextStyle(color: Colors.white),
          ),
          value: mode,
          groupValue: _currentLoopMode,
          onChanged: (value) => _changeLoopMode(value!),
          activeColor: Colors.orange,
        );
      }).toList(),
    );
  }
  
  Widget _buildAudioTrackOptions() {
    return Column(
      children: _audioTracks.map((track) {
        return RadioListTile<int>(
          title: Text(
            track['label'] ?? 'Track ${track['index']}',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            track['language'] ?? 'Unknown',
            style: const TextStyle(color: Colors.grey),
          ),
          value: track['index'],
          groupValue: _selectedAudioTrack,
          onChanged: (value) {
            _controller.switchAudioTrack(value!);
            setState(() {
              _selectedAudioTrack = value;
            });
          },
          activeColor: Colors.orange,
        );
      }).toList(),
    );
  }
  
  Widget _buildSubtitleOptions() {
    return Column(
      children: [
        RadioListTile<int>(
          title: const Text(
            'None',
            style: TextStyle(color: Colors.white),
          ),
          value: -1,
          groupValue: _selectedSubtitleTrack,
          onChanged: (value) {
            _controller.switchSubtitleTrack(value!);
            setState(() {
              _selectedSubtitleTrack = value;
            });
          },
          activeColor: Colors.orange,
        ),
        ..._subtitleTracks.map((track) {
          return RadioListTile<int>(
            title: Text(
              track['label'] ?? 'Track ${track['index']}',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              track['language'] ?? 'Unknown',
              style: const TextStyle(color: Colors.grey),
            ),
            value: track['index'],
            groupValue: _selectedSubtitleTrack,
            onChanged: (value) {
              _controller.switchSubtitleTrack(value!);
              setState(() {
                _selectedSubtitleTrack = value;
              });
            },
            activeColor: Colors.orange,
          );
        }),
      ],
    );
  }
  
  String _getZoomText(VideoZoom zoom) {
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
  
  String _getLoopModeText(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return 'Off';
      case LoopMode.one:
        return 'Repeat One';
      case LoopMode.all:
        return 'Repeat All';
    }
  }
}