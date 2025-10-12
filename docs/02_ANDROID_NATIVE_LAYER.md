# Android Native Layer Documentation

## Overview

The Android native layer handles all video playback using AndroidX Media3 (ExoPlayer). This layer is responsible for:
- Video decoding and rendering
- Audio track management
- Subtitle handling
- Picture-in-Picture mode
- MediaSession integration
- Communication with Flutter layer

## Core Files

### 1. MainActivity.java

**Purpose**: Application entry point

**Code**:
```java
public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Register Media3 Player Plugin
        flutterEngine.getPlugins().add(new Media3PlayerPlugin());
    }
}
```

**Responsibilities**:
- Initialize Flutter engine
- Register custom plugins
- Handle system callbacks

### 2. Media3PlayerPlugin.kt

**Purpose**: Flutter plugin implementation

**Code**:
```kotlin
class Media3PlayerPlugin: FlutterPlugin, ActivityAware {
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory(
                "media3_player_view",
                Media3PlayerViewFactory(flutterPluginBinding.binaryMessenger)
            )
    }
    
    // Activity lifecycle methods
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { }
    override fun onDetachedFromActivity() { }
}
```

**Responsibilities**:
- Register platform view factory
- Handle activity lifecycle
- Manage plugin resources

### 3. Media3PlayerView.kt (★ CORE ENGINE)

**Size**: 1,753 lines  
**Purpose**: Complete video playback engine

#### Initialization

```kotlin
init {
    // 1. Acquire player from pool
    exoPlayer = PlayerPoolManager.acquirePlayer(context, videoPath)
    
    // 2. Setup UI
    setupPlayerView()
    
    // 3. Setup communication
    setupMethodChannel()
    
    // 4. Setup listeners
    setupPlayerListener()
    
    // 5. Additional features
    setupMediaSession()
    setupPictureInPicture()
    
    // 6. Load video
    loadVideo(videoPath, autoPlay, startPosition)
    
    // 7. Start monitoring
    positionUpdateHandler.post(positionUpdateRunnable)
    initializeVolumeObserver()
}
```

#### Available Methods from Flutter

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| play | - | void | Start playback |
| pause | - | void | Pause playback |
| seekTo | position (ms) | void | Seek to position |
| setPlaybackSpeed | speed (0.25-4.0) | void | Change playback speed |
| setVolume | volume (0.0-1.0) | void | Set player volume |
| getSystemVolume | - | double | Get system volume |
| setSystemVolume | volume (0.0-1.0) | void | Set system volume |
| setResizeMode | mode (fit/stretch/zoomToFill) | void | Set video resize mode |
| getCurrentPosition | - | long | Get current position in ms |
| getDuration | - | long | Get video duration in ms |
| isPlaying | - | boolean | Check if playing |
| getTracks | - | Map | Get all available tracks |
| setAudioTrack | index | void | Select audio track |
| setSubtitleTrack | index | void | Select subtitle track |
| disableSubtitle | - | void | Disable subtitles |
| enterPictureInPicture | - | boolean | Enter PiP mode |
| getThumbnail | position (ms) | ByteArray | Generate thumbnail |
| preload | videoPath | void | Preload video |
| dispose | - | void | Release player |

#### Events Sent to Flutter

| Event | Data | Frequency |
|-------|------|-----------|
| onPlayingChanged | isPlaying: Boolean | On change |
| onPlaybackStateChanged | state, isPlaying, isBuffering, bufferedPercentage | On change |
| onPositionChanged | position, duration (ms) | Every 500ms |
| onError | error: String | On error |
| onVideoSizeChanged | width, height, pixelRatio | On change |
| onTracksChanged | videoTracks, audioTracks, subtitleTracks | On tracks available |
| onSystemVolumeChanged | volume: Double | On volume change |

#### Track Management

**Track Detection**:
```kotlin
private fun getTracksFromTrackSelector(): Map<String, Any> {
    val mappedTrackInfo = trackSelector.currentMappedTrackInfo
    
    for (rendererIndex in 0 until mappedTrackInfo.rendererCount) {
        when (mappedTrackInfo.getRendererType(rendererIndex)) {
            C.TRACK_TYPE_AUDIO -> processAudioTracks()
            C.TRACK_TYPE_VIDEO -> processVideoTracks()
            C.TRACK_TYPE_TEXT -> processSubtitleTracks()
        }
    }
}
```

**Audio Track Selection**:
```kotlin
private fun setAudioTrack(index: Int) {
    // Save state
    val wasPlaying = exoPlayer.isPlaying
    val currentPosition = exoPlayer.currentPosition
    
    // Apply selection
    val parameters = trackSelector.buildUponParameters()
        .setSelectionOverride(audioRendererIndex, trackGroups, 
            DefaultTrackSelector.SelectionOverride(groupIndex, trackIndex))
        .build()
    trackSelector.setParameters(parameters)
    
    // Rebuild player
    exoPlayer.stop()
    exoPlayer.prepare()
    
    // Restore state
    if (wasPlaying) exoPlayer.play()
    exoPlayer.seekTo(currentPosition)
}
```

### 4. PlayerPoolManager.kt

**Purpose**: Manage player instances for performance

**Why Pooling?**
- ExoPlayer initialization takes 200-500ms
- Reusing players improves performance
- Reduces memory allocation

**Code**:
```kotlin
object PlayerPoolManager {
    private const val MAX_POOL_SIZE = 3
    private val playerPool = LinkedList<ExoPlayer>()
    private val activePlayers = mutableMapMap<String, ExoPlayer>()
    
    fun acquirePlayer(context: Context, videoPath: String): ExoPlayer {
        return if (playerPool.isNotEmpty()) {
            playerPool.removeFirst()  // Reuse
        } else {
            createPlayer(context)  // Create new
        }
    }
    
    fun releasePlayer(videoPath: String) {
        val player = activePlayers.remove(videoPath)
        player?.let {
            it.stop()
            it.clearMediaItems()
            if (playerPool.size < MAX_POOL_SIZE) {
                playerPool.add(it)  // Return to pool
            } else {
                it.release()  // Pool full
            }
        }
    }
}
```

## Build Configuration

### android/app/build.gradle

```gradle
android {
    compileSdk = 35
    minSdk = 24
    targetSdk = 35
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    // Media3 Libraries (version 1.4.1)
    implementation 'androidx.media3:media3-exoplayer:1.4.1'
    implementation 'androidx.media3:media3-ui:1.4.1'
    implementation 'androidx.media3:media3-session:1.4.1'
    implementation 'androidx.media3:media3-common:1.4.1'
    implementation 'androidx.media3:media3-datasource:1.4.1'
    implementation 'androidx.media3:media3-database:1.4.1'
    implementation 'androidx.media3:media3-decoder:1.4.1'
    
    // Streaming protocols
    implementation 'androidx.media3:media3-exoplayer-dash:1.4.1'
    implementation 'androidx.media3:media3-exoplayer-hls:1.4.1'
    implementation 'androidx.media3:media3-exoplayer-smoothstreaming:1.4.1'
    implementation 'androidx.media3:media3-exoplayer-rtsp:1.4.1'
}
```

### AndroidManifest.xml

```xml
<manifest>
    <!-- Permissions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    
    <application
        android:hardwareAccelerated="true"
        android:largeHeap="true">
        
        <activity
            android:name=".MainActivity"
            android:supportsPictureInPicture="true"
            android:configChanges="orientation|screenSize|...">
        </activity>
    </application>
</manifest>
```
