# Flutter Layer Documentation

## Overview

The Flutter layer provides the UI and controls for video playback, while delegating actual video rendering to the native layer.

## Core Files

### 1. main.dart

**Purpose**: Application entry point

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemUIHelper.initializeSystemUI();
  runApp(const IPlayerApp());
}
```

### 2. Media3PlayerController

**Location**: `lib/core/platform/media3_player_controller.dart`  
**Size**: 846 lines  
**Purpose**: Dart-side controller for native player

#### Architecture

```dart
class Media3PlayerController {
  late final MethodChannel _channel;
  final int viewId;
  
  // State
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  // Streams (Reactive)
  final StreamController<bool> _playingController;
  final StreamController<Map<String, Duration>> _positionController;
  final StreamController<Map<String, dynamic>> _tracksController;
  
  // Public Streams
  Stream<bool> get onPlayingChanged => _playingController.stream;
  Stream<Map<String, Duration>> get onPositionChanged => _positionController.stream;
  Stream<Map<String, dynamic>> get onTracksChanged => _tracksController.stream;
}
```

#### Key Methods

**Playback Control**:
```dart
Future<void> play() async {
  await _channel.invokeMethod('play');
}

Future<void> pause() async {
  await _channel.invokeMethod('pause');
}

Future<void> seekTo(Duration position) async {
  await _channel.invokeMethod('seekTo', {
    'position': position.inMilliseconds,
  });
}

Future<void> setPlaybackSpeed(double speed) async {
  await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
}
```

**Track Management**:
```dart
Future<void> selectAudioTrack(int index) async {
  // Validate index
  final tracks = await getTracks();
  final audioTracks = tracks?['audioTracks'] as List? ?? [];
  
  if (index < 0 || index >= audioTracks.length) {
    throw Exception('Invalid track index');
  }
  
  // Select track
  await _channel.invokeMethod('setAudioTrack', {'index': index});
  
  // Verify selection
  await Future.delayed(Duration(milliseconds: 1500));
  final updatedTracks = await getTracks();
  final updatedIndex = updatedTracks?['currentAudioTrackIndex'];
  
  if (updatedIndex != index) {
    throw Exception('Track selection failed');
  }
}
```

**Event Handling**:
```dart
void _setupMethodCallHandler() {
  _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onPlayingChanged':
        _isPlaying = call.arguments as bool;
        _playingController.add(_isPlaying);
        break;
        
      case 'onPositionChanged':
        final args = call.arguments as Map;
        _position = Duration(milliseconds: args['position']);
        _duration = Duration(milliseconds: args['duration']);
        _positionController.add({
          'position': _position,
          'duration': _duration,
        });
        break;
        
      case 'onTracksChanged':
        _tracksController.add(call.arguments);
        break;
    }
  });
}
```

### 3. Media3PlayerWidget

**Location**: `lib/presentation/widgets/media3_player_widget.dart`  
**Size**: 2,852 lines  
**Purpose**: Main video player UI widget

#### Features

1. **Video Display**: Native platform view for video rendering
2. **Playback Controls**: Play/pause, seek, speed control
3. **Gesture Controls**: 
   - Horizontal swipe: Seek forward/backward
   - Vertical swipe (left): Brightness control
   - Vertical swipe (right): Volume control
   - Double tap: Play/pause
   - Pinch: Zoom
4. **UI Elements**:
   - Progress bar with buffering indication
   - Time display (current/duration)
   - Settings menu
   - Audio track selector
   - Subtitle selector
   - Speed control (0.25x - 4.0x)
5. **Advanced Features**:
   - Picture-in-Picture mode
   - Auto-hide controls
   - Zoom modes (fit, stretch, zoom to fill)
   - System volume/brightness integration

#### State Management

```dart
class _Media3PlayerWidgetState extends State<Media3PlayerWidget> 
    with WidgetsBindingObserver, TickerProviderStateMixin {
  
  // Player
  Media3PlayerController? _controller;
  
  // State
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  // UI State
  bool _showControls = true;
  ZoomMode _currentZoomMode = ZoomMode.fit;
  double _currentSpeed = 1.0;
  
  // Tracks
  List<Map<String, dynamic>> _audioTracks = [];
  List<Map<String, dynamic>> _subtitleTracks = [];
  int? _currentAudioTrackIndex;
  
  // Streams
  late StreamSubscription _playingSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _tracksSubscription;
}
```

#### Lifecycle

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _initializeAnimations();
  _initializeBrightness();
  _initializeVolume();
  _enableWakeLock();
}

void _initializePlayer(int viewId) {
  _controller = Media3PlayerController(viewId: viewId);
  _setupEventListeners();
}

void _setupEventListeners() {
  _playingSubscription = _controller!.onPlayingChanged.listen((isPlaying) {
    setState(() => _isPlaying = isPlaying);
  });
  
  _positionSubscription = _controller!.onPositionChanged.listen((data) {
    setState(() {
      _position = data['position'];
      _duration = data['duration'];
    });
  });
  
  _tracksSubscription = _controller!.onTracksChanged.listen((data) {
    setState(() {
      _audioTracks = _convertToMapList(data['audioTracks']);
      _subtitleTracks = _convertToMapList(data['subtitleTracks']);
    });
  });
}

@override
void dispose() {
  _playingSubscription.cancel();
  _positionSubscription.cancel();
  _tracksSubscription.cancel();
  _controller?.dispose();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

#### Gesture Handling

```dart
GestureDetector(
  onTap: () => _toggleControls(),
  onDoubleTap: () => _togglePlayPause(),
  onHorizontalDragUpdate: (details) => _handleSeekGesture(details),
  onVerticalDragUpdate: (details) {
    if (details.localPosition.dx < MediaQuery.of(context).size.width / 2) {
      _handleBrightnessGesture(details);  // Left side
    } else {
      _handleVolumeGesture(details);      // Right side
    }
  },
  child: _buildPlayerView(),
)
```

#### Platform View Integration

```dart
Widget _buildPlayerView() {
  return PlatformViewLink(
    viewType: 'media3_player_view',
    surfaceFactory: (context, controller) {
      return AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      );
    },
    onCreatePlatformView: (params) {
      final viewId = params.id;
      _initializePlayer(viewId);  // Initialize controller with viewId
      
      return PlatformViewsService.initSurfaceAndroidView(
        id: viewId,
        viewType: 'media3_player_view',
        layoutDirection: TextDirection.ltr,
        creationParams: {
          'videoPath': widget.videoPath,
          'autoPlay': widget.autoPlay,
          'startPosition': widget.startPosition?.inMilliseconds,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onFocus: () => params.onFocusChanged(true),
      )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
       ..create();
    },
  );
}
```

## UI Components

### 1. Progress Bar

```dart
Widget _buildProgressBar() {
  final progress = _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;
      
  return Slider(
    value: progress.clamp(0.0, 1.0),
    onChanged: (value) {
      final newPosition = Duration(
        milliseconds: (value * _duration.inMilliseconds).round(),
      );
      _controller?.seekTo(newPosition);
    },
  );
}
```

### 2. Audio Track Selector

```dart
void _showAudioTrackDialog() {
  showDialog(
    context: context,
    builder: (context) => AudioTracksDialog(
      audioTracks: _audioTracks,
      currentIndex: _currentAudioTrackIndex,
      onTrackSelected: (index) async {
        await _controller?.selectAudioTrack(index);
        setState(() => _currentAudioTrackIndex = index);
      },
    ),
  );
}
```

### 3. Speed Control

```dart
Widget _buildSpeedMenu() {
  final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  
  return ListView.builder(
    itemCount: speeds.length,
    itemBuilder: (context, index) {
      final speed = speeds[index];
      return ListTile(
        title: Text('${speed}x'),
        selected: _currentSpeed == speed,
        onTap: () {
          _controller?.setPlaybackSpeed(speed);
          setState(() => _currentSpeed = speed);
        },
      );
    },
  );
}
```

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Storage & Files
  shared_preferences: ^2.3.4
  path_provider: ^2.1.5
  permission_handler: ^11.3.1
  
  # Media
  video_thumbnail: ^0.5.3
  
  # UI
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  percent_indicator: ^4.2.4
  
  # Utils
  crypto: ^3.0.3
  intl: ^0.20.1
  path: ^1.9.0
  provider: ^6.1.2
```
