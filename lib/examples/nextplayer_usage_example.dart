import 'package:flutter/material.dart';
import '../core/video_player/nextplayer_integration_manager.dart';
import '../enhanced_nextplayer/enhanced_nextplayer_controller.dart';
import '../enhanced_nextplayer/enhanced_nextplayer_widget.dart';
import '../core/video_player/gesture_controller.dart';
import '../core/video_player/decoder_manager.dart' as dm;
import '../core/video_player/playback_speed_manager.dart' as psm;
import '../core/video_player/screen_orientation_manager.dart';

/// Example demonstrating how to use NextPlayer integration
/// Shows all the advanced features working together
class NextPlayerUsageExample extends StatefulWidget {
  final String videoPath;
  
  const NextPlayerUsageExample({
    super.key,
    required this.videoPath,
  });
  
  @override
  State<NextPlayerUsageExample> createState() => _NextPlayerUsageExampleState();
}

class _NextPlayerUsageExampleState extends State<NextPlayerUsageExample> {
  late NextPlayerIntegrationManager _integrationManager;
  late EnhancedNextPlayerController _controller;
  
  bool _isInitialized = false;
  String _gestureText = '';
  bool _showGestureOverlay = false;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    _integrationManager = NextPlayerIntegrationManager();
    _controller = EnhancedNextPlayerController();
    
    // Setup event listeners
    _setupEventListeners();
    
    // Initialize with NextPlayer preferences
    await _initializeWithPreferences();
    
    // Load the video
    await _integrationManager.loadVideo(widget.videoPath);
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  void _setupEventListeners() {
    // Listen to integration manager events
    _integrationManager.events.listen((event) {
      if (event.type == NextPlayerEventType.gesture) {
        final gestureType = event.data['gestureType'] as String? ?? 'unknown';
        _showGestureOverlay = true;
        
        switch (gestureType) {
          case 'volume':
            _gestureText = 'Volume: ${event.data['value']}%';
            break;
          case 'brightness':
            _gestureText = 'Brightness: ${event.data['value']}%';
            break;
          case 'seek':
            _gestureText = 'Seek: ${event.data['value']}s';
            break;
          case 'zoom':
            _gestureText = 'Zoom: ${event.data['value']}x';
            break;
          default:
            _gestureText = 'Gesture detected';
            break;
        }
        
        setState(() {});
        
        // Hide gesture overlay after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showGestureOverlay = false;
            });
          }
        });
      }
    });
    
    // Listen to video state changes
    _integrationManager.videoState.stateStream.listen((state) {
      print('Video state updated: ${state.position}');
    });
    
    // Listen to decoder events
    _integrationManager.decoder.decoderEvents.listen((event) {
      print('Decoder event: ${event.message}');
    });
    
    // Listen to speed changes
    _integrationManager.speed.speedStream.listen((speed) {
      print('Playback speed changed: ${speed}x');
    });
    
    // Listen to orientation changes
    _integrationManager.orientation.orientationStream.listen((orientation) {
      print('Orientation changed: $orientation');
    });
  }
  
  Future<void> _initializeWithPreferences() async {
    // Initialize the integration manager
    await _integrationManager.initialize();
    
    // Apply NextPlayer preferences
    const preferences = NextPlayerPreferences(
      // Enable all gesture controls
      useSwipeControls: true,
      useSeekControls: true,
      useZoomControls: true,
      useLongPressControls: true,
      doubleTapGesture: DoubleTapGesture.both,
      
      // Prefer hardware decoding
      decoderPriority: dm.DecoderPriority.preferDevice,
      useHardwareAcceleration: true,
      
      // Enable fast seek for long videos
      fastSeek: psm.FastSeek.auto,
      longPressSpeed: 2.0,
      
      // Auto orientation
      screenOrientation: ScreenOrientation.auto,
      autoRotate: true,
      
      // Remember playback state
      resumeMode: 'yes',
      rememberSelections: true,
      rememberPlayerBrightness: true,
      
      // Audio enhancements
      skipSilence: false,
      volumeBoost: true,
      preferredAudioLanguage: "en",
      
      // Subtitle preferences
      preferredSubtitleLanguage: "en",
      useSystemCaptionStyle: true,
    );
    
    await _integrationManager.applyPreferences(preferences);
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: EnhancedNextPlayerWidget(
                videoPath: widget.videoPath,
                controller: _controller,
                onPlayerCreated: (controller) {
                  // Player is ready
                },
                onEvent: (event) {
                  // Handle player events
                },
              ),
            ),
          ),
          
          // Gesture overlay
          if (_showGestureOverlay)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _gestureText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Control panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControlPanel(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _integrationManager.speed.decreaseSpeed(),
                icon: const Icon(Icons.fast_rewind, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  if (_controller.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                },
                icon: Icon(
                  _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => _integrationManager.speed.increaseSpeed(),
                icon: const Icon(Icons.fast_forward, color: Colors.white),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Advanced controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.settings,
                label: 'Settings',
                onPressed: () => _showSettingsDialog(),
              ),
              _buildControlButton(
                icon: Icons.track_changes,
                label: 'Tracks',
                onPressed: () => _showTrackSelectionDialog(),
              ),
              _buildControlButton(
                icon: Icons.speed,
                label: 'Speed',
                onPressed: () => _showSpeedDialog(),
              ),
              _buildControlButton(
                icon: Icons.screen_rotation,
                label: 'Rotate',
                onPressed: () => _integrationManager.orientation.toggleFullscreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NextPlayer Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Hardware Acceleration'),
              value: _integrationManager.decoder.useHardwareAcceleration,
              onChanged: (value) {
                _integrationManager.decoder.setHardwareAcceleration(value);
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Volume Boost'),
              value: _integrationManager.audio.volumeBoostEnabled,
              onChanged: (value) {
                _integrationManager.audio.setVolumeBoostEnabled(value);
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Skip Silence'),
              value: _integrationManager.audio.skipSilenceEnabled,
              onChanged: (value) {
                _integrationManager.audio.setSkipSilenceEnabled(value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showTrackSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Track Selection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Audio Tracks'),
              subtitle: Text('Current: ${_integrationManager.tracks.selectedAudioTrack}'),
              onTap: () {
                // Show audio track selection
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Subtitle Tracks'),
              subtitle: Text('Current: ${_integrationManager.tracks.selectedSubtitleTrack}'),
              onTap: () {
                // Show subtitle track selection
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
          children: _integrationManager.speed.availableSpeeds
              .map((speed) => ListTile(
                    title: Text('${speed}x'),
                    selected: speed == _integrationManager.speed.currentSpeed,
                    onTap: () {
                      _integrationManager.speed.setSpeed(speed);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _integrationManager.dispose();
    _controller.dispose();
    super.dispose();
  }
}

/// Usage example in your app:
/// 
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: NextPlayerUsageExample(
///         videoPath: '/path/to/your/video.mp4',
///       ),
///     );
///   }
/// }
/// ```