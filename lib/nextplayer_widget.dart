import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// NextPlayer Widget - ExoPlayer-based video player
/// Converted from NextPlayer Android app for maximum stability
class NextPlayerWidget extends StatefulWidget {
  final String videoPath;
  final String videoTitle;
  final bool autoPlay;
  final Function(NextPlayerController)? onPlayerCreated;
  final Function()? onInitialized;
  final Function()? onPlaying;
  final Function()? onPaused;
  final Function()? onStopped;
  final Function(Duration)? onTimeChanged;
  final Function(Duration)? onDurationChanged;
  final Function(String)? onError;
  final Function(Size)? onVideoSizeChanged;
  final Function(double)? onPlaybackSpeedChanged;

  const NextPlayerWidget({
    Key? key,
    required this.videoPath,
    required this.videoTitle,
    this.autoPlay = true,
    this.onPlayerCreated,
    this.onInitialized,
    this.onPlaying,
    this.onPaused,
    this.onStopped,
    this.onTimeChanged,
    this.onDurationChanged,
    this.onError,
    this.onVideoSizeChanged,
    this.onPlaybackSpeedChanged,
  }) : super(key: key);

  @override
  State<NextPlayerWidget> createState() => _NextPlayerWidgetState();
}

class _NextPlayerWidgetState extends State<NextPlayerWidget> {
  NextPlayerController? _controller;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'nextplayer_view',
        creationParams: {
          'videoPath': widget.videoPath,
          'autoPlay': widget.autoPlay,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'NextPlayer is only available on Android',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _onPlatformViewCreated(int id) {
    _controller = NextPlayerController._(id);
    _controller!._setupEventListeners(
      onInitialized: widget.onInitialized,
      onPlaying: widget.onPlaying,
      onPaused: widget.onPaused,
      onStopped: widget.onStopped,
      onTimeChanged: widget.onTimeChanged,
      onDurationChanged: widget.onDurationChanged,
      onError: widget.onError,
      onVideoSizeChanged: widget.onVideoSizeChanged,
      onPlaybackSpeedChanged: widget.onPlaybackSpeedChanged,
    );
    
    if (widget.onPlayerCreated != null) {
      widget.onPlayerCreated!(_controller!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Controller for NextPlayer
class NextPlayerController {
  final int _viewId;
  late MethodChannel _channel;
  
  // Player state
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  int _volume = 100;
  int _brightness = 50;
  Size _videoSize = Size.zero;

  NextPlayerController._(this._viewId) {
    _channel = MethodChannel('nextplayer_$_viewId');
  }

  void _setupEventListeners({
    Function()? onInitialized,
    Function()? onPlaying,
    Function()? onPaused,
    Function()? onStopped,
    Function(Duration)? onTimeChanged,
    Function(Duration)? onDurationChanged,
    Function(String)? onError,
    Function(Size)? onVideoSizeChanged,
    Function(double)? onPlaybackSpeedChanged,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onInitialized':
          _isInitialized = true;
          onInitialized?.call();
          break;
          
        case 'onPlaying':
          _isPlaying = true;
          onPlaying?.call();
          break;
          
        case 'onPaused':
          _isPlaying = false;
          onPaused?.call();
          break;
          
        case 'onStopped':
          _isPlaying = false;
          onStopped?.call();
          break;
          
        case 'onTimeChanged':
          final time = call.arguments['time'] as int;
          _currentPosition = Duration(milliseconds: time);
          onTimeChanged?.call(_currentPosition);
          break;
          
        case 'onDurationChanged':
          final duration = call.arguments['duration'] as int;
          _duration = Duration(milliseconds: duration);
          onDurationChanged?.call(_duration);
          break;
          
        case 'onError':
          final error = call.arguments['error'] as String;
          onError?.call(error);
          break;
          
        case 'onVideoSizeChanged':
          final width = call.arguments['width'] as int;
          final height = call.arguments['height'] as int;
          _videoSize = Size(width.toDouble(), height.toDouble());
          onVideoSizeChanged?.call(_videoSize);
          break;
          
        case 'onPlaybackSpeedChanged':
          final speed = call.arguments['speed'] as double;
          _playbackSpeed = speed;
          onPlaybackSpeedChanged?.call(speed);
          break;
      }
    });
  }

  // Playback control methods
  Future<void> setMedia(String path) async {
    try {
      await _channel.invokeMethod('setMedia', {'path': path});
    } catch (e) {
      debugPrint('Error setting media: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('Error playing: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('Error pausing: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('Error stopping: $e');
      rethrow;
    }
  }

  Future<void> seekTo(Duration time) async {
    try {
      await _channel.invokeMethod('seekTo', {'time': time.inMilliseconds});
    } catch (e) {
      debugPrint('Error seeking: $e');
      rethrow;
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
      rethrow;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('Error setting volume: $e');
      rethrow;
    }
  }

  Future<void> setBrightness(int brightness) async {
    try {
      await _channel.invokeMethod('setBrightness', {'brightness': brightness});
    } catch (e) {
      debugPrint('Error setting brightness: $e');
      rethrow;
    }
  }

  Future<void> showVolumeGesture(bool show) async {
    try {
      await _channel.invokeMethod('showVolumeGesture', {'show': show});
    } catch (e) {
      debugPrint('Error showing volume gesture: $e');
      rethrow;
    }
  }

  Future<void> showBrightnessGesture(bool show) async {
    try {
      await _channel.invokeMethod('showBrightnessGesture', {'show': show});
    } catch (e) {
      debugPrint('Error showing brightness gesture: $e');
      rethrow;
    }
  }

  Future<void> showInfo(String text, [String? subtext]) async {
    try {
      await _channel.invokeMethod('showInfo', {
        'text': text,
        'subtext': subtext ?? '',
      });
    } catch (e) {
      debugPrint('Error showing info: $e');
      rethrow;
    }
  }

  Future<void> showTopInfo(String text) async {
    try {
      await _channel.invokeMethod('showTopInfo', {'text': text});
    } catch (e) {
      debugPrint('Error showing top info: $e');
      rethrow;
    }
  }

  // State getters
  Future<bool> isPlaying() async {
    try {
      return await _channel.invokeMethod('isPlaying') ?? false;
    } catch (e) {
      debugPrint('Error checking if playing: $e');
      return false;
    }
  }

  Future<Duration> getDuration() async {
    try {
      final duration = await _channel.invokeMethod('getDuration') ?? 0;
      return Duration(milliseconds: duration);
    } catch (e) {
      debugPrint('Error getting duration: $e');
      return Duration.zero;
    }
  }

  Future<Duration> getCurrentPosition() async {
    try {
      final position = await _channel.invokeMethod('getCurrentPosition') ?? 0;
      return Duration(milliseconds: position);
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return Duration.zero;
    }
  }

  Future<double> getPlaybackSpeed() async {
    try {
      return await _channel.invokeMethod('getPlaybackSpeed') ?? 1.0;
    } catch (e) {
      debugPrint('Error getting playback speed: $e');
      return 1.0;
    }
  }

  Future<int> getVolume() async {
    try {
      return await _channel.invokeMethod('getVolume') ?? 100;
    } catch (e) {
      debugPrint('Error getting volume: $e');
      return 100;
    }
  }

  Future<int> getBrightness() async {
    try {
      return await _channel.invokeMethod('getBrightness') ?? 50;
    } catch (e) {
      debugPrint('Error getting brightness: $e');
      return 50;
    }
  }

  Future<bool> isInitialized() async {
    try {
      return await _channel.invokeMethod('isInitialized') ?? false;
    } catch (e) {
      debugPrint('Error checking if initialized: $e');
      return false;
    }
  }

  // Cached state getters (for performance)
  bool get isInitializedSync => _isInitialized;
  bool get isPlayingSync => _isPlaying;
  Duration get durationSync => _duration;
  Duration get currentPositionSync => _currentPosition;
  double get playbackSpeedSync => _playbackSpeed;
  int get volumeSync => _volume;
  int get brightnessSync => _brightness;
  Size get videoSizeSync => _videoSize;

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}