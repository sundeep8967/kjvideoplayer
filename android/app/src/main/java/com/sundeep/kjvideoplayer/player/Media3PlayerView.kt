package com.sundeep.kjvideoplayer.player

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.*
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.*
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Clean Media3 Player View - No NextPlayer dependencies
 * Uses latest AndroidX Media3 APIs with proper lifecycle management
 */
@OptIn(UnstableApi::class)
class Media3PlayerView(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any>?
) : PlatformView {
    
    private val frameLayout: FrameLayout = FrameLayout(context)
    private val playerView: PlayerView = PlayerView(context)
    private val channel: MethodChannel = MethodChannel(messenger, "media3_player_$id")
    
    // Media3 ExoPlayer instance
    private val exoPlayer: ExoPlayer by lazy {
        createMedia3Player(context)
    }
    
    // Player state
    private var isInitialized = false
    private var playWhenReady = true
    private var currentPosition = 0L
    private var mediaItemIndex = 0
    
    init {
        setupPlayerView()
        setupMethodChannel()
        setupPlayerListener()
        
        val videoPath = creationParams?.get("videoPath") as? String
        val autoPlay = creationParams?.get("autoPlay") as? Boolean ?: true
        val startPosition = creationParams?.get("startPosition") as? Long
        
        if (videoPath != null) {
            loadVideo(videoPath, autoPlay, startPosition)
        }
    }
    
    private fun createMedia3Player(context: Context): ExoPlayer {
        // Conservative LoadControl to prevent pipeline overflow
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                1000,      // Min buffer - 1 second
                5000,      // Max buffer - 5 seconds  
                500,       // Buffer for playback
                1000       // Buffer for rebuffer
            )
            .setTargetBufferBytes(2_000_000) // 2MB buffer limit
            .setPrioritizeTimeOverSizeThresholds(true)
            .setBackBuffer(2000, false)
            .build()
        
        // Track selector with reasonable limits
        val trackSelector = DefaultTrackSelector(context).apply {
            setParameters(
                buildUponParameters()
                    .setMaxVideoSize(1920, 1080) // Max 1080p
                    .setMaxVideoBitrate(5_000_000) // Max 5Mbps
                    .setPreferredAudioLanguage("en")
                    .setForceLowestBitrate(false)
            )
        }
        
        return ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setTrackSelector(trackSelector)
            .setSeekBackIncrementMs(10_000)
            .setSeekForwardIncrementMs(10_000)
            .build()
    }
    
    private fun setupPlayerView() {
        playerView.apply {
            player = exoPlayer
            useController = true // Enable Media3's excellent built-in controls
            setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING)
            
            // Configure Media3's advanced control features
            controllerAutoShow = true
            controllerHideOnTouch = true
            controllerShowTimeoutMs = 3000
            
            // Enable Media3's gesture controls
            setControllerVisibilityListener(PlayerView.ControllerVisibilityListener { visibility ->
                channel.invokeMethod("onControlsVisibilityChanged", mapOf(
                    "visible" to (visibility == View.VISIBLE)
                ))
            })
            
            // Enable Media3's fullscreen support
            setFullscreenButtonClickListener { isFullScreen ->
                channel.invokeMethod("onFullscreenToggle", mapOf(
                    "isFullscreen" to isFullScreen
                ))
            }
        }
        
        frameLayout.addView(playerView)
    }
    
    private fun setupPlayerListener() {
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                val stateString = when (playbackState) {
                    Player.STATE_IDLE -> "IDLE"
                    Player.STATE_BUFFERING -> "BUFFERING"
                    Player.STATE_READY -> "READY"
                    Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN"
                }
                
                channel.invokeMethod("onPlaybackStateChanged", mapOf(
                    "state" to stateString,
                    "isPlaying" to exoPlayer.isPlaying,
                    "isBuffering" to (playbackState == Player.STATE_BUFFERING)
                ))
                
                if (playbackState == Player.STATE_READY && !isInitialized) {
                    isInitialized = true
                    channel.invokeMethod("onInitialized", null)
                }
            }
            
            override fun onPlayerError(error: PlaybackException) {
                channel.invokeMethod("onError", mapOf(
                    "error" to error.message,
                    "errorCode" to error.errorCode
                ))
            }
            
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                channel.invokeMethod("onPositionChanged", mapOf(
                    "position" to exoPlayer.currentPosition,
                    "duration" to exoPlayer.duration
                ))
            }
            
            override fun onVideoSizeChanged(videoSize: VideoSize) {
                channel.invokeMethod("onVideoSizeChanged", mapOf(
                    "width" to videoSize.width,
                    "height" to videoSize.height
                ))
            }
        })
    }
    
    private fun setupMethodChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    exoPlayer.play()
                    result.success(null)
                }
                
                "pause" -> {
                    exoPlayer.pause()
                    result.success(null)
                }
                
                "seekTo" -> {
                    val position = call.argument<Long>("position") ?: 0L
                    exoPlayer.seekTo(position)
                    result.success(null)
                }
                
                "setPlaybackSpeed" -> {
                    val speed = call.argument<Double>("speed") ?: 1.0
                    exoPlayer.setPlaybackSpeed(speed.toFloat())
                    result.success(null)
                }
                
                "setVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 1.0
                    exoPlayer.volume = volume.toFloat()
                    result.success(null)
                }
                
                "getCurrentPosition" -> {
                    result.success(exoPlayer.currentPosition)
                }
                
                "getDuration" -> {
                    result.success(exoPlayer.duration)
                }
                
                "isPlaying" -> {
                    result.success(exoPlayer.isPlaying)
                }
                
                "showControls" -> {
                    playerView.showController()
                    result.success(null)
                }
                
                "hideControls" -> {
                    playerView.hideController()
                    result.success(null)
                }
                
                "setControllerTimeout" -> {
                    val timeout = call.argument<Int>("timeout") ?: 3000
                    playerView.controllerShowTimeoutMs = timeout
                    result.success(null)
                }
                
                "enterFullscreen" -> {
                    // Media3 handles fullscreen automatically with proper UI
                    result.success(null)
                }
                
                "dispose" -> {
                    dispose()
                    result.success(null)
                }
                
                else -> result.notImplemented()
            }
        }
    }
    
    private fun loadVideo(videoPath: String, autoPlay: Boolean = true, startPosition: Long? = null) {
        try {
            val mediaItem = MediaItem.Builder()
                .setUri(videoPath)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle("Video")
                        .build()
                )
                .build()
            
            exoPlayer.setMediaItem(mediaItem)
            exoPlayer.playWhenReady = autoPlay
            
            startPosition?.let { position ->
                if (position > 0) {
                    exoPlayer.seekTo(position)
                }
            }
            
            exoPlayer.prepare()
            
        } catch (e: Exception) {
            channel.invokeMethod("onError", mapOf(
                "error" to "Failed to load video: ${e.message}",
                "errorCode" to -1
            ))
        }
    }
    
    // Lifecycle management
    fun onStart() {
        if (android.os.Build.VERSION.SDK_INT > 23) {
            if (!isInitialized) {
                // Player is already initialized in init
            }
        }
    }
    
    fun onResume() {
        if (android.os.Build.VERSION.SDK_INT <= 23) {
            if (!isInitialized) {
                // Player is already initialized in init
            }
        }
    }
    
    fun onPause() {
        if (android.os.Build.VERSION.SDK_INT <= 23) {
            savePlayerState()
        }
    }
    
    fun onStop() {
        if (android.os.Build.VERSION.SDK_INT > 23) {
            savePlayerState()
        }
    }
    
    private fun savePlayerState() {
        currentPosition = exoPlayer.currentPosition
        mediaItemIndex = exoPlayer.currentMediaItemIndex
        playWhenReady = exoPlayer.playWhenReady
    }
    
    override fun getView(): View = frameLayout
    
    override fun dispose() {
        exoPlayer.release()
    }
}

/**
 * Factory for creating Media3 Player Views
 */
class Media3PlayerViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        return Media3PlayerView(context, messenger, id, creationParams)
    }
}