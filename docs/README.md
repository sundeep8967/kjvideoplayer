# Video Player App Documentation

## Quick Navigation

1. **[Overview & Architecture](01_OVERVIEW_AND_ARCHITECTURE.md)**
   - Project overview
   - Technology stack
   - System architecture
   - Design patterns

2. **[Android Native Layer](02_ANDROID_NATIVE_LAYER.md)**
   - MainActivity.java
   - Media3PlayerPlugin.kt
   - Media3PlayerView.kt (Core Engine)
   - PlayerPoolManager.kt
   - Build configuration

3. **[Flutter Layer](03_FLUTTER_LAYER.md)**
   - Media3PlayerController
   - Media3PlayerWidget
   - State management
   - Platform view integration

4. **[Features & Usage](04_FEATURES_AND_USAGE.md)**
   - Key features
   - Usage examples
   - Code snippets

5. **[Development Guide](05_DEVELOPMENT_GUIDE.md)**
   - Setup instructions
   - Adding features
   - Building & testing

6. **[Troubleshooting](06_TROUBLESHOOTING.md)**
   - Common issues
   - Debugging tools
   - Performance tips

7. **[API Reference](07_API_REFERENCE.md)**
   - Complete API documentation
   - Method signatures
   - Event streams

8. **[Native Controls Implementation](08_NATIVE_CONTROLS_IMPLEMENTATION.md)** ⭐ NEW
   - Native Media3 controls (replaces Flutter overlays)
   - Video title display
   - Subtitle & audio track selection
   - Complete usage guide

## Quick Start

### Play a Video

```dart
Media3PlayerWidget(
  videoPath: '/path/to/video.mp4',
  videoTitle: 'My Video',
  autoPlay: true,
)
```

### Control Playback

```dart
final controller = Media3PlayerController(viewId: viewId);
await controller.play();
await controller.pause();
await controller.seekTo(Duration(seconds: 30));
```

### Listen to Events

```dart
controller.onPlayingChanged.listen((isPlaying) {
  print('Playing: $isPlaying');
});
```

## Architecture Summary

```
Flutter UI (Dart)
      ↕ MethodChannel
Native Player (Kotlin)
      ↕
Media3 ExoPlayer
```

## Key Files

### Android Native
- `Media3PlayerView.kt` - 1,753 lines - Core video engine
- `PlayerPoolManager.kt` - Player instance pooling
- `Media3PlayerPlugin.kt` - Flutter plugin registration

### Flutter
- `media3_player_controller.dart` - 846 lines - Controller
- `media3_player_widget.dart` - 2,852 lines - UI widget

## Core Features

✅ **Native Media3 Controls** ⭐ NEW  
✅ Multiple audio tracks  
✅ Subtitle support  
✅ Picture-in-Picture  
✅ Gesture controls  
✅ Speed control (0.25x - 4.0x)  
✅ Zoom modes  
✅ Player pooling  
✅ MediaSession integration  
✅ Video title in native UI  
✅ Native subtitle/audio track buttons  

## Technology Stack

- **Flutter**: 3.6.1+
- **Media3**: 1.4.1
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 35 (Android 15)
- **Kotlin**: JVM 11

## Contact & Support

For issues or questions, refer to the troubleshooting guide or check the individual documentation files.
