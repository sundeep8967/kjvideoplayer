# Troubleshooting Guide

## Common Issues

### 1. Audio Tracks Not Detected

**Symptoms**: No audio tracks in dialog, or empty track list

**Causes**:
- Tracks not loaded yet (timing issue)
- Unsupported audio codec
- File has no audio

**Solutions**:
```dart
// Wait for tracks to load
await Future.delayed(Duration(seconds: 2));
await controller.refreshTracks();

// Check if audio format exists
final tracks = await controller.getTracks();
print('Audio tracks: ${tracks?['audioTracks']}');
```

**Native Debug**:
```kotlin
// In Media3PlayerView.kt
debugAudioTracks()  // Logs all track info
```

### 2. Audio Track Switching Fails

**Symptoms**: Selected track doesn't change audio

**Solution**: Already implemented with multi-stage approach:
```kotlin
// Current implementation:
1. Apply track selection
2. Stop player
3. Prepare player
4. Restore position/state
5. Verify selection
```

### 3. Video Not Playing

**Checklist**:
- [ ] File path correct?
- [ ] File readable?
- [ ] Codec supported?
- [ ] Permissions granted?

**Debug**:
```dart
controller.onError.listen((error) {
  print('Error: $error');
});
```

### 4. PiP Not Working

**Requirements**:
- Android 8.0+ (API 26+)
- Manifest permission
- Activity configuration

**Manifest Check**:
```xml
<activity
    android:supportsPictureInPicture="true"
    android:configChanges="orientation|screenSize|...">
</activity>
```

### 5. Memory Issues

**Symptoms**: App crashes or slows down

**Solutions**:
- Player pooling (already implemented)
- Dispose players properly:
```dart
@override
void dispose() {
  _controller?.dispose();
  super.dispose();
}
```

### 6. Buffering Issues

**Symptoms**: Frequent buffering, stuttering

**Solution**: Adjust buffer settings in `PlayerPoolManager.kt`:
```kotlin
val loadControl = DefaultLoadControl.Builder()
    .setBufferDurationsMs(
        30_000,  // Increase min buffer
        60_000,  // Increase max buffer
        2_500,   // Playback buffer
        5_000    // Rebuffer
    )
    .build()
```

## Debugging Tools

### Enable Verbose Logging

**Native**:
```kotlin
private val TAG = "Media3PlayerView"
Log.d(TAG, "Message")
```

**Flutter**:
```dart
debugPrint('[Controller] Message');
```

### View Logcat
```bash
adb logcat | grep -E "Media3PlayerView|Media3PlayerController"
```

### Check Player State
```dart
print('Playing: ${await controller.getIsPlaying()}');
print('Position: ${await controller.getCurrentPosition()}');
print('Duration: ${await controller.getDuration()}');
```

## Performance Optimization

### Reduce Position Update Frequency
Edit `Media3PlayerView.kt`:
```kotlin
positionUpdateHandler.postDelayed(this, 1000)  // 1 second instead of 500ms
```

### Disable Unused Features
```kotlin
// In setupPlayerView()
playerView.setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER)
playerView.useController = false
```

## Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "No audio tracks available" | Tracks not loaded | Wait and call refreshTracks() |
| "Invalid track index" | Index out of bounds | Check track count first |
| "Player not ready" | Player not initialized | Wait for onInitialized event |
| "PiP not supported" | Device < Android 8 | Check API level |
| "Failed to load video" | File issue | Check path and permissions |
