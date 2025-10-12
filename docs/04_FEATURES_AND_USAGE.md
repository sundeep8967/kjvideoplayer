# Features & Usage Guide

## Key Features

### 1. Video Playback
- **Formats**: MP4, MKV, AVI, MOV, WebM, 3GP, FLV
- **Codecs**: H.264, H.265, VP8, VP9, AV1
- **Audio**: AAC, MP3, Opus, Vorbis, FLAC
- **Subtitles**: SRT, VTT, TTML, SSA/ASS

### 2. Audio Track Management
- Multiple audio track detection
- Seamless track switching
- Track info: language, codec, bitrate
- Auto-selection by language

### 3. Gesture Controls
- **Horizontal swipe**: Seek ±10s
- **Vertical left**: Brightness
- **Vertical right**: Volume
- **Double tap**: Play/Pause
- **Pinch**: Zoom
- **Single tap**: Controls

### 4. Display Modes
- Fit (maintain aspect ratio)
- Stretch (fill screen)
- Zoom to Fill
- Custom zoom/pan

### 5. Picture-in-Picture
- Android 8.0+ support
- Auto aspect ratio
- Background playback

## Usage Examples

### Basic Playback

```dart
Media3PlayerWidget(
  videoPath: '/path/to/video.mp4',
  videoTitle: 'My Video',
  autoPlay: true,
  startPosition: Duration(seconds: 30),
)
```

### Track Selection

```dart
// Get tracks
final tracks = await controller.getTracks();

// Select audio track
await controller.selectAudioTrack(1);

// Disable subtitles
await controller.disableSubtitle();
```

### Event Listening

```dart
controller.onPlayingChanged.listen((isPlaying) {
  print('Playing: $isPlaying');
});

controller.onPositionChanged.listen((data) {
  print('${data['position']} / ${data['duration']}');
});
```
