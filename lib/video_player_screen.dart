import 'dart:io';
import 'dart:async';
import 'dart:io'; // Already here, just confirming
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Already here
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart'; // Changed import

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
  late VlcPlayerController _vlcController; // Changed controller type

  /// Tracks whether the UI is locked.
  bool _isLocked = false;
  Timer? _volumeDebounce; // <-- Add this line

  /// Whether the main controls (top bar + bottom bar) are visible when NOT locked.
  bool _controlsVisible = false;

  /// When locked, tapping toggles only this single lock button’s visibility.
  bool _lockButtonVisible = false;

  // Duration _videoDuration = Duration.zero; // Replaced by ValueNotifier
  // Duration _currentPosition = Duration.zero; // Replaced by ValueNotifier
  double _currentVolume = 1.0;
  double _volumeFactor = 0.05;

  // ValueNotifiers for reactive UI updates
  late final ValueNotifier<Duration> _currentPositionNotifier;
  late final ValueNotifier<Duration> _videoDurationNotifier;
  late final ValueNotifier<bool> _isPlayingNotifier;
  late final ValueNotifier<bool> _isInitializedNotifier;
  // AspectRatio can also be a ValueNotifier if it can change dynamically,
  // but for video, it's usually fixed after initialization.
  // We'll use _isInitializedNotifier to rebuild the AspectRatio widget.
  late final ValueNotifier<double> _aspectRatioNotifier; // Added for VLC player aspect ratio

@override
  void initState() {
    super.initState();

    // Initialize ValueNotifiers
    _currentPositionNotifier = ValueNotifier(Duration.zero);
    _videoDurationNotifier = ValueNotifier(Duration.zero);
    _isPlayingNotifier = ValueNotifier(false);
    _isInitializedNotifier = ValueNotifier(false);
    _aspectRatioNotifier = ValueNotifier(16 / 9); // Default aspect ratio

    PerfectVolumeControl.hideUI = true;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

    _vlcController = VlcPlayerController.file(
      File(widget.videoPath),
      hwAcc: HwAcc.FULL,
      autoPlay: false, // We will call play explicitly via listener
      options: VlcPlayerOptions(
        // Example options (refer to VLC documentation for more)
        // options: [
        //   '--no-audio', // Example: disable audio
        //   '--rtsp-tcp', // Use RTSP over TCP
        // ],
        // subtitle: VlcSubtitle.file(File('/path/to/subtitle.srt')), // Example for subtitles
      ),
    );

    // Add listener BEFORE any potential play calls or other interactions
    _vlcController.addListener(_vlcPlayerListener);

    // VlcPlayerController initializes itself. We don't call a separate initialize() method.
    // Play will be triggered from the listener once isInitialized is true.

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    _initializeVolume();
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    _vlcController.removeListener(_vlcPlayerListener);
    _vlcController.stop(); // Recommended before dispose for VLC
    _vlcController.dispose();
    _currentPositionNotifier.dispose();
    _videoDurationNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isInitializedNotifier.dispose();
    _aspectRatioNotifier.dispose();
    super.dispose();
  }

  bool _hasPlayedOnce = false; // To ensure play is called only once automatically

  // Listener function for VlcPlayerController
  void _vlcPlayerListener() {
    if (!mounted) return;

    final value = _vlcController.value;

    // Update initialization state
    if (value.isInitialized != _isInitializedNotifier.value) {
      _isInitializedNotifier.value = value.isInitialized;
    }

    // Update duration
    if (value.duration != _videoDurationNotifier.value) {
      _videoDurationNotifier.value = value.duration;
    }

    // Update position
    if (value.position != _currentPositionNotifier.value) {
      _currentPositionNotifier.value = value.position;
    }

    // Update playing state
    if (value.isPlaying != _isPlayingNotifier.value) {
      _isPlayingNotifier.value = value.isPlaying;
    }
    
    // Update aspect ratio
    if (value.aspectRatio != 0.0 && value.aspectRatio != _aspectRatioNotifier.value) {
        _aspectRatioNotifier.value = value.aspectRatio;
    }


    // Auto-play logic: Play once when initialized and stopped
    if (value.isInitialized && !_hasPlayedOnce && value.playingState == PlayingState.stopped) {
        _vlcController.play();
        _hasPlayedOnce = true; 
        // _isPlayingNotifier.value will be updated by the next listener call reacting to play()
    }
    
    // Error handling
    if (value.hasError) {
      print('VLC Player Error: ${value.errorDescription}');
      // Optionally, set an error state here to display in the UI
      // For example: _errorDescriptionNotifier.value = value.errorDescription;
    }
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
    if (!_isInitializedNotifier.value) return; // Don't seek if video not ready

    double delta = details.primaryDelta ?? 0.0;
    final currentPositionMs = _currentPositionNotifier.value.inMilliseconds;
    final videoDurationMs = _videoDurationNotifier.value.inMilliseconds;

    if (videoDurationMs == 0) return; // Avoid division by zero if duration is not yet known

    final newPositionMs = currentPositionMs +
        (delta / MediaQuery.of(context).size.width * videoDurationMs).round();
    
    final newPosition = Duration(milliseconds: newPositionMs);

    final clampedPosition = _clampDuration(newPosition, Duration.zero, _videoDurationNotifier.value);
    _vlcController.seekTo(clampedPosition); // Use VlcController
    // The listener will update _currentPositionNotifier.value.
    // For immediate feedback during drag, update directly:
    _currentPositionNotifier.value = clampedPosition;
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
              child: ValueListenableBuilder<bool>(
                valueListenable: _isInitializedNotifier,
                builder: (context, isInitialized, _) {
                  if (isInitialized) {
                    return ValueListenableBuilder<double>(
                      valueListenable: _aspectRatioNotifier,
                      builder: (context, aspectRatio, _) {
                        return VlcPlayer(
                          controller: _vlcController,
                          aspectRatio: aspectRatio == 0.0 ? 16/9 : aspectRatio, // Use default if 0
                          placeholder: Center(child: CircularProgressIndicator()),
                        );
                      }
                    );
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
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
                  ValueListenableBuilder<Duration>(
                    valueListenable: _currentPositionNotifier,
                    builder: (context, position, child) {
                      return Text(
                        _formatDuration(position),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      );
                    },
                  ),
                  Expanded(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _videoDurationNotifier,
                      builder: (context, videoDuration, child) {
                        // Also listen to current position for the slider's value
                        return ValueListenableBuilder<Duration>(
                          valueListenable: _currentPositionNotifier,
                          builder: (context, currentPosition, child) {
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blue,
                                inactiveTrackColor: Colors.white54,
                                thumbColor: Colors.blueAccent,
                                trackHeight: 2.0,
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
                              ),
                              child: Slider(
                                value: currentPosition.inSeconds
                                    .toDouble()
                                    .clamp(0, videoDuration.inSeconds.toDouble()),
                                min: 0,
                                max: videoDuration.inSeconds.toDouble() > 0 
                                     ? videoDuration.inSeconds.toDouble()
                                     : 1.0, // Avoid max <= min if duration is 0
                                onChanged: (value) {
                                  _vlcController.seekTo(Duration(seconds: value.toInt()));
                                  // Optional: for immediate feedback, though listener should catch it
                                  _currentPositionNotifier.value = Duration(seconds: value.toInt());
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _videoDurationNotifier,
                    builder: (context, duration, child) {
                      return Text(
                        _formatDuration(duration),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      );
                    },
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
                      // Example: _vlcController.seekTo(Duration.zero);
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (context, isPlaying, child) {
                      return IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            _vlcController.pause();
                            // Listener will update _isPlayingNotifier.value
                          } else {
                            _vlcController.play();
                             // Listener will update _isPlayingNotifier.value
                          }
                        },
                      );
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
