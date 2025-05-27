import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';





class CustomVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String videoTitle;

  CustomVideoPlayer({
    required this.videoPath,
    required this.videoTitle,
  });

  @override
  _CustomVideoPlayerState createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late VideoPlayerController _controller;

  /// Tracks whether the UI is locked.
  bool _isLocked = false;
  Timer? _volumeDebounce; // <-- Add this line

  /// Whether the main controls (top bar + bottom bar) are visible when NOT locked.
  bool _controlsVisible = false;

  /// When locked, tapping toggles only this single lock button’s visibility.
  bool _lockButtonVisible = false;

  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  double _currentVolume = 1.0;
  double _volumeFactor = 0.05;
@override

  void initState() {
    
    super.initState();
// Set black colors for status and navigation bars
   // Set the status bar and navigation bar colors
PerfectVolumeControl.hideUI = true;

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent, // Fully transparent divider

    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));
 SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _videoDuration = _controller.value.duration;
        });
        _controller.play();
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.black, // Set status bar color to black
             statusBarIconBrightness: Brightness.light, // Light icons for dark background
            systemNavigationBarColor: Colors.transparent, // Set navigation bar color to black
                    systemNavigationBarDividerColor: Colors.transparent, // Transparent divider

            systemNavigationBarIconBrightness: Brightness.light, // Light icons for dark background
        ));
      });

    _controller.addListener(() {
      if (_controller.value.isInitialized) {
        setState(() {
          _currentPosition = _controller.value.position;
        });
      }
    });
    // Lock the screen orientation to landscape
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);

    
  

    // Initialize the volume when the player is ready
    _initializeVolume();
  }

  @override
  void dispose() {
     _volumeDebounce?.cancel(); // Cancel the debounce timer if active
    _controller.dispose();
     // Optionally, release screen wake locks
   
    super.dispose();
  }

  /// Initialize system volume using volume_controller
  Future<void> _initializeVolume() async {
    try {
      final currentVol = await PerfectVolumeControl.getVolume();
      setState(() {
        _currentVolume = currentVol;
      });
    } catch (e) {
      print('Error initializing volume: $e');
    }

  }

/// Handle vertical swipe for volume adjustment
  void _onVerticalSwipe(DragUpdateDetails details) {
    double delta = details.primaryDelta ?? 0.0;
    double newVolume = _currentVolume;

    if (delta > 0) {
      // Swiping down - decrease volume
      newVolume = (_currentVolume - _volumeFactor).clamp(0.0, 1.0);
    } else if (delta < 0) {
      // Swiping up - increase volume
      newVolume = (_currentVolume + _volumeFactor).clamp(0.0, 1.0);
    }

    // Debounce volume changes to prevent excessive setState calls
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(Duration(milliseconds: 100), () {
      setState(() {
        _currentVolume = newVolume;
      });
    });

    // Update the system volume asynchronously
    PerfectVolumeControl.setVolume(newVolume).catchError((e) {
      print('Error setting volume: $e');
    });
  }
  /// Handle horizontal swipe for seeking
  void _onHorizontalDrag(DragUpdateDetails details) {
    double delta = details.primaryDelta ?? 0.0;
    final newPosition = _currentPosition +
        Duration(
          seconds: (delta /
                  MediaQuery.of(context).size.width *
                  _videoDuration.inSeconds)
              .round(),
        );

    _controller.seekTo(
      _clampDuration(newPosition, Duration.zero, _videoDuration),
    );
    setState(() {
      _currentPosition =
          _clampDuration(newPosition, Duration.zero, _videoDuration);
    });
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    return Duration(
      milliseconds:
          value.inMilliseconds.clamp(min.inMilliseconds, max.inMilliseconds),
    );
  }

  /// Tapping on the screen:
  /// - if locked => toggles _lockButtonVisible
  /// - if unlocked => toggles full controls
  void _toggleControlsVisibility() {
    if (_isLocked) {
      // If locked, only toggle lock button visibility
      setState(() {
        _lockButtonVisible = !_lockButtonVisible;
      });
    } else {
      // If unlocked, toggle the entire UI
      setState(() {
        _controlsVisible = !_controlsVisible;
        if (_controlsVisible) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
        }
      });
    }
  }

  /// Tapping the lock button toggles the locked state
  /// - if locking => hide all UI
  /// - if unlocking => bring everything back
  void _toggleLock() {
    setState(() {
      // Toggle isLocked
      _isLocked = !_isLocked;
      if (_isLocked) {
        // On locking, hide everything
        _controlsVisible = false;
        _lockButtonVisible = false; // will show only if user taps again
      } else {
        // On unlocking, show full UI
        _controlsVisible = true;
        _lockButtonVisible = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControlsVisibility,
        onVerticalDragUpdate: _onVerticalSwipe,
        onHorizontalDragUpdate: _onHorizontalDrag,
        child: Stack(
          children: [
            // Video
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : CircularProgressIndicator(),
            ),

            // Show top & bottom bars only if not locked and controls are visible
            if (!_isLocked && _controlsVisible) ...[
              _buildTopBar(),
              _buildBottomBar(),
            ],

            // Show lock button in top-right only if locked AND lockButtonVisible
            if (_isLocked && _lockButtonVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: GestureDetector(
                  onTap: _toggleLock,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Top bar (unchanged)
  /// Top bar with SafeArea
Widget _buildTopBar() {
  return SafeArea(
    child: Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.videoTitle,
              style: TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.subtitles, color: Colors.white),
            onPressed: () => _showSubtitlesPanel(context),
          ),
          IconButton(
            icon: Icon(Icons.music_note, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    ),
  );
}


void _showSubtitlesPanel(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true, // Allow dismissal by tapping outside
    barrierColor: Colors.transparent, // No dark overlay effect
    builder: (BuildContext context) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent, // Allow transparency for Material widget
          child: Container(
            width: MediaQuery.of(context).size.width * 0.3, // 40% width of the screen
            height: MediaQuery.of(context).size.height, // Full height of the screen
            color: Colors.black87, // Background color
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  title: Text('Subtitles Options'),
                  leading: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    children: [
                      ListTile(
                        leading: Icon(Icons.smart_toy, color: Colors.white),
                        title: Text('AI Subtitles', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: Implement AI Subtitles functionality
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.folder_open, color: Colors.white),
                        title: Text('Open', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: Implement Open functionality
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.cloud_download, color: Colors.white),
                        title: Text('Online Subtitles', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: Implement Online Subtitles functionality
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}


  /// Bottom bar with time, slider, time, skip/play/skip, fit/fill, fullscreen
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: current time, slider, total time
              Row(
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Colors.white54,
                        thumbColor: Colors.blueAccent,
                        trackHeight: 2.0,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
                      ),
                      child: Slider(
                        value: _currentPosition.inSeconds
                            .toDouble()
                            .clamp(0, _videoDuration.inSeconds.toDouble()),
                        min: 0,
                        max: _videoDuration.inSeconds.toDouble(),
                        onChanged: (value) {
                          setState(() {
                            _controller.seekTo(Duration(seconds: value.toInt()));
                          });
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(_videoDuration),
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),

              // Bottom row: skip-previous, play/pause, skip-next, fit/fill, fullscreen, etc.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: () {
                      // Implement skip-previous logic if needed
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () {
                      // Implement skip-next logic if needed
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.fit_screen, color: Colors.white),
                    onPressed: () {
                      // Implement fit/fill logic
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () {
                      // Implement fullscreen logic
                    },
                  ),
                  
                  // Optionally, you could place an "Unlock/Lock" icon here 
                  // if you want to lock from the bottom bar. 
                  // But in the logic above, we do that only from the bottom bar
                  // if we want to see it from start, or remove it entirely
                  // if you prefer the top-right approach only after locking.
                  //
                  // Example:
                   IconButton(
                     icon: Icon(Icons.lock_open, color: Colors.white),
                     onPressed: _toggleLock,
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format Duration to HH:MM:SS or MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
