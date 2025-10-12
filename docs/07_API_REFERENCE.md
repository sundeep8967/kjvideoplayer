# API Reference

## Media3PlayerController

### Methods

#### Playback Control

```dart
Future<void> play()
```
Start playback.

```dart
Future<void> pause()
```
Pause playback.

```dart
Future<void> seekTo(Duration position)
```
Seek to position.

```dart
Future<void> setPlaybackSpeed(double speed)
```
Set speed (0.25 - 4.0).

#### Volume Control

```dart
Future<void> setVolume(double volume)
```
Set player volume (0.0 - 1.0).

```dart
Future<double> getSystemVolume()
```
Get system volume.

```dart
Future<void> setSystemVolume(double volume)
```
Set system volume.

#### Track Management

```dart
Future<Map<String, dynamic>?> getTracks()
```
Returns:
```dart
{
  'videoTracks': [
    {'index': 0, 'width': 1920, 'height': 1080, 'codec': 'h264', ...}
  ],
  'audioTracks': [
    {'index': 0, 'name': 'English', 'language': 'en', 'codec': 'aac', ...}
  ],
  'subtitleTracks': [
    {'index': 0, 'name': 'English', 'language': 'en', ...}
  ]
}
```

```dart
Future<void> selectAudioTrack(int index)
```
Select audio track by index. Validates and verifies selection.

```dart
Future<int?> getSelectedAudioTrackIndex()
```
Get currently selected audio track index.

```dart
Future<void> setSubtitleTrack(int index)
```
Enable subtitle track.

```dart
Future<void> disableSubtitle()
```
Disable all subtitles.

#### Advanced Features

```dart
Future<bool> isPictureInPictureSupported()
```
Check PiP availability.

```dart
Future<bool> enterPictureInPicture()
```
Enter PiP mode. Returns true if successful.

```dart
Future<void> setResizeMode(String mode)
```
Mode: 'fit', 'stretch', 'zoomToFill'

```dart
Future<Uint8List?> getThumbnail(Duration position)
```
Generate thumbnail at position.

```dart
Future<void> preload(String videoPath)
```
Preload video for instant playback.

### Events (Streams)

```dart
Stream<bool> onPlayingChanged
```
Emits when playback state changes.

```dart
Stream<bool> onBufferingChanged
```
Emits when buffering state changes.

```dart
Stream<Map<String, Duration>> onPositionChanged
```
Emits position updates every 500ms.
Data: `{'position': Duration, 'duration': Duration}`

```dart
Stream<String?> onError
```
Emits error messages.

```dart
Stream<void> onInitialized
```
Emits when player is ready.

```dart
Stream<Map<String, dynamic>> onTracksChanged
```
Emits when tracks are available or change.

```dart
Stream<double> onSystemVolumeChanged
```
Emits when system volume changes (0.0 - 1.0).

### Properties

```dart
bool get isInitialized
bool get isPlaying
bool get isBuffering
Duration get position
Duration get duration
String? get error
```

## Media3PlayerWidget

### Constructor

```dart
Media3PlayerWidget({
  required String videoPath,
  String? videoTitle,
  bool autoPlay = true,
  Duration? startPosition,
  VoidCallback? onBack,
  Function(Duration)? onPositionChanged,
  Function(Duration)? onBookmarkAdded,
  bool showControls = true,
})
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| videoPath | String | required | Path to video file |
| videoTitle | String? | null | Title displayed in UI |
| autoPlay | bool | true | Auto-start playback |
| startPosition | Duration? | null | Initial position |
| onBack | VoidCallback? | null | Back button callback |
| onPositionChanged | Function(Duration)? | null | Position update callback |
| onBookmarkAdded | Function(Duration)? | null | Bookmark callback |
| showControls | bool | true | Show UI controls |

## Native API (Kotlin)

### Media3PlayerView

#### Constructor
```kotlin
Media3PlayerView(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any>?
)
```

#### Creation Parameters
- `videoPath`: String - Video file path
- `autoPlay`: Boolean - Auto-start playback
- `startPosition`: Long - Initial position (ms)

#### Method Channel Methods

All methods handled via `media3_player_$id` channel.

See Flutter API above for method signatures.

### PlayerPoolManager

```kotlin
fun acquirePlayer(context: Context, videoPath: String): ExoPlayer
```
Get player from pool or create new.

```kotlin
fun releasePlayer(videoPath: String)
```
Return player to pool.

```kotlin
fun preload(context: Context, videoPath: String)
```
Preload video in background.

```kotlin
fun cleanUp()
```
Release all players (call on app exit).
