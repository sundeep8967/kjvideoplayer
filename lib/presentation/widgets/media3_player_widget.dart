import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/platform/media3_player_controller.dart';

/// Media3 Player Widget - Clean implementation without NextPlayer dependencies
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
    with WidgetsBindingObserver {
  
  Media3PlayerController? _controller;
  late StreamSubscription _playingSubscription;
  late StreamSubscription _bufferingSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _errorSubscription;
  late StreamSubscription _initializedSubscription;
  
  // UI State
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }
  
  void _initializePlayer() {
    _controller = Media3PlayerController();
    _setupEventListeners();
  }
  
  void _setupEventListeners() {
    if (_controller == null) return;
    
    _playingSubscription = _controller!.onPlayingChanged.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });
    
    _bufferingSubscription = _controller!.onBufferingChanged.listen((isBuffering) {
      // Media3 handles buffering indicators internally
    });
    
    _positionSubscription = _controller!.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
        _duration = _controller!.duration;
      });
      
      widget.onPositionChanged?.call(position);
    });
    
    _errorSubscription = _controller!.onError.listen((error) {
      setState(() {
        _error = error;
      });
      
      if (error != null) {
        _showErrorDialog(error);
      }
    });
    
    _initializedSubscription = _controller!.onInitialized.listen((_) {
      // Media3 handles initialization internally
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
  
  // Media3 handles controls internally, so these methods are not needed
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
      body: GestureDetector(
        onTap: null, // Media3 handles controls internally
        child: Stack(
          children: [
            // Media3 Platform View with built-in controls
            Container(
              width: double.infinity,
              height: double.infinity,
              child: AndroidView(
                viewType: 'media3_player_view',
                creationParams: {
                  'videoPath': widget.videoPath,
                  'autoPlay': widget.autoPlay,
                  'startPosition': widget.startPosition?.inMilliseconds,
                  'useBuiltInControls': true, // Use Media3's excellent controls
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
            
            // Note: Media3 handles its own loading and buffering indicators
            // when useBuiltInControls is true, so we don't need custom ones
            
            // Error overlay
            if (_error != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                    ],
                  ),
                ),
              ),
            
            // Optional: Add custom overlay controls if needed
            // Media3's built-in controls are comprehensive and professional
            if (widget.showControls && _error == null)
              _buildCustomOverlay(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCustomOverlay() {
    // Minimal custom overlay - Media3 handles most controls
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  widget.videoTitle ?? 'Video',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            // Top bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.videoTitle ?? 'Video',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Center play/pause button
            Center(
              child: IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            
            const Spacer(),
            
            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Progress bar
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? _position.inMilliseconds / _duration.inMilliseconds
                              : 0.0,
                          onChanged: (value) {
                            final position = Duration(
                              milliseconds: (value * _duration.inMilliseconds).round(),
                            );
                            _controller?.seekTo(position);
                          },
                          activeColor: Colors.red,
                          inactiveColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  
                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => _controller?.setPlaybackSpeed(0.5),
                        icon: const Text('0.5x', style: TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        onPressed: () => _controller?.setPlaybackSpeed(1.0),
                        icon: const Text('1x', style: TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        onPressed: () => _controller?.setPlaybackSpeed(1.5),
                        icon: const Text('1.5x', style: TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        onPressed: () => _controller?.setPlaybackSpeed(2.0),
                        icon: const Text('2x', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Media3 handles controls internally
    
    // Cancel subscriptions
    _playingSubscription.cancel();
    _bufferingSubscription.cancel();
    _positionSubscription.cancel();
    _errorSubscription.cancel();
    _initializedSubscription.cancel();
    
    // Dispose controller
    _controller?.dispose();
    
    super.dispose();
  }
}