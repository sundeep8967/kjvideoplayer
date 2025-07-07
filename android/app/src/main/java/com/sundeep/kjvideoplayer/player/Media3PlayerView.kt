package com.sundeep.kjvideoplayer.player

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.*
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.*
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.*
import androidx.media3.ui.AspectRatioFrameLayout // Required for RESIZE_MODE constants
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
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val id: Int,
    private val creationParams: Map<String, Any>?
) : PlatformView {
    private val TAG = "Media3PlayerView" // For Logcat
    
    // Audio management
    private val audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var volumeContentObserver: ContentObserver? = null

    // Handler for periodic position updates
    private val positionUpdateHandler = android.os.Handler(context.mainLooper)
    private val positionUpdateRunnable = object : Runnable {
        override fun run() {
            sendPositionUpdate()
            positionUpdateHandler.postDelayed(this, 250)
        }
    }
    
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

    // Track selector reference for switching tracks
    private val trackSelector: DefaultTrackSelector by lazy {
        DefaultTrackSelector(context)
    }
    
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

        // Start periodic position updates
        positionUpdateHandler.post(positionUpdateRunnable)
    }
    
    private fun createMedia3Player(context: Context): ExoPlayer {
        // Optimized LoadControl based on AndroidX Media3 best practices
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,           // 50s min buffer
                DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,           // 50s max buffer  
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,  // 2.5s for playback
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS // 5s after rebuffer
            )
            .setTargetBufferBytes(DefaultLoadControl.DEFAULT_TARGET_BUFFER_BYTES) // Dynamic buffer sizing
            .setPrioritizeTimeOverSizeThresholds(true)
            .setBackBuffer(DefaultLoadControl.DEFAULT_BACK_BUFFER_DURATION_MS, true) // Enable back buffer
            .build()

        // Use the class-level trackSelector so we can switch tracks later
        trackSelector.setParameters(
            trackSelector.buildUponParameters()
                .setMaxVideoSize(Int.MAX_VALUE, Int.MAX_VALUE)
                .setMaxVideoBitrate(Int.MAX_VALUE)
                .setPreferredAudioLanguage("en")
                .setForceLowestBitrate(false)
                .setAllowVideoMixedMimeTypeAdaptiveness(true)
                .setAllowAudioMixedMimeTypeAdaptiveness(true)
                .setAllowVideoNonSeamlessAdaptiveness(true)
                .setTunnelingEnabled(false)
        )

        // Enhanced ExoPlayer with performance optimizations
        return ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setTrackSelector(trackSelector)
            .setSeekBackIncrementMs(10_000)
            .setSeekForwardIncrementMs(30_000)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .setUseLazyPreparation(true)
            .build().apply {
                setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                        .build(),
                    true
                )
            }
    }

    // Track selection helpers
    private fun setAudioTrack(index: Int) {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return
        val rendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
            mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
        } ?: return
        val group = mappedTrackInfo.getTrackGroups(rendererIndex)
        if (index < 0 || index >= group.length) return
        val parameters = trackSelector.buildUponParameters()
            .setSelectionOverride(
                rendererIndex,
                group,
                DefaultTrackSelector.SelectionOverride(index, 0)
            )
        trackSelector.setParameters(parameters)
    }

    private fun setSubtitleTrack(index: Int) {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return
        val rendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
            mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_TEXT
        } ?: return
        val group = mappedTrackInfo.getTrackGroups(rendererIndex)
        if (index < 0 || index >= group.length) return
        val parameters = trackSelector.buildUponParameters()
            .setRendererDisabled(rendererIndex, false)
            .setSelectionOverride(
                rendererIndex,
                group,
                DefaultTrackSelector.SelectionOverride(index, 0)
            )
        trackSelector.setParameters(parameters)
    }

    private fun disableSubtitle() {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return
        val rendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
            mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_TEXT
        } ?: return
        val parameters = trackSelector.buildUponParameters()
            .setRendererDisabled(rendererIndex, true)
        trackSelector.setParameters(parameters)
    }
    
    private fun sendPositionUpdate() {
        if (!exoPlayer.isCommandAvailable(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)) {
            // Player might not be ready, or is released
            return
        }
        val currentPos = exoPlayer.currentPosition
        val currentDur = if (exoPlayer.duration != C.TIME_UNSET) exoPlayer.duration else 0L
        // Log.d(TAG, "Sending onPositionChanged: position=$currentPos, duration=$currentDur") // Can be too noisy
        try {
            channel.invokeMethod("onPositionChanged", mapOf(
                "position" to currentPos,
                "duration" to currentDur
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error sending onPositionChanged: ${e.message}")
        }
    }
    
    private fun startPositionUpdates() {
        positionUpdateHandler.post(positionUpdateRunnable)
    }
    
    private fun stopPositionUpdates() {
        positionUpdateHandler.removeCallbacks(positionUpdateRunnable)
    }
    
    private fun setupPlayerView() {
        playerView.apply {
            player = exoPlayer
            useController = false // Completely disable all native UI controls
            setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER) // Hide buffering indicator

            // Disable all controller features
            controllerAutoShow = false
            controllerHideOnTouch = false

            // Remove all listeners that might show UI elements
            setControllerVisibilityListener(null as PlayerView.ControllerVisibilityListener?)
            setFullscreenButtonClickListener(null)

            // Make PlayerView non-interactive to touch to pass events to Flutter
            isFocusable = false
            isClickable = false
            isLongClickable = false
        }

        frameLayout.apply {
            // Make FrameLayout non-interactive to touch
            isFocusable = false
            isClickable = false
            isLongClickable = false
            addView(playerView)
        }
        // Set initial resize mode
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        Log.d(TAG, "Initial resizeMode set to FIT")
    }
    
    private fun setupPlayerListener() {
        exoPlayer.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                Log.d(TAG, "Sending onPlayingChanged: $isPlaying")
                channel.invokeMethod("onPlayingChanged", isPlaying)
            }
            override fun onPlaybackStateChanged(playbackState: Int) {
                val stateString = when (playbackState) {
                    Player.STATE_IDLE -> "IDLE"
                    Player.STATE_BUFFERING -> "BUFFERING"
                    Player.STATE_READY -> "READY"
                    Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN"
                }
                val payload = mapOf(
                    "state" to stateString,
                    "isPlaying" to exoPlayer.isPlaying,
                    "isBuffering" to (playbackState == Player.STATE_BUFFERING),
                    "bufferedPercentage" to exoPlayer.bufferedPercentage,
                    "bufferedPosition" to exoPlayer.bufferedPosition
                )
                Log.d(TAG, "Sending onPlaybackStateChanged: $payload")
                channel.invokeMethod("onPlaybackStateChanged", payload)
                
                if (playbackState == Player.STATE_READY && !isInitialized) {
                    isInitialized = true
                    Log.d(TAG, "Sending onInitialized")
                    channel.invokeMethod("onInitialized", null)
                }
            }
            
            override fun onPlayerError(error: PlaybackException) {
                val errorPayload = mapOf(
                    "error" to error.message,
                    "errorCode" to error.errorCode,
                    "errorType" to when (error.errorCode) {
                        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED -> "NETWORK_ERROR"
                        PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND -> "FILE_NOT_FOUND"
                        PlaybackException.ERROR_CODE_DECODING_FAILED -> "DECODING_ERROR"
                        PlaybackException.ERROR_CODE_AUDIO_TRACK_INIT_FAILED -> "AUDIO_ERROR"
                        else -> "UNKNOWN_ERROR"
                    }
                )
                Log.e(TAG, "Sending onError: ${error.message}", error)
                channel.invokeMethod("onError", errorPayload)
            }
            
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                Log.d(TAG, "onPositionDiscontinuity, reason: $reason. New pos: ${newPosition.positionMs}. Old pos: ${oldPosition.positionMs}")
                sendPositionUpdate() // Ensure UI updates on seek or playlist transition
            }
            
            // The duplicate sendPositionUpdate was removed. The one outside the listener is used by the Handler.

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                val payload = mapOf(
                    "width" to videoSize.width,
                    "height" to videoSize.height,
                    "pixelWidthHeightRatio" to videoSize.pixelWidthHeightRatio
                )
                Log.d(TAG, "Sending onVideoSizeChanged: $payload")
                channel.invokeMethod("onVideoSizeChanged", payload)
            }
            
            override fun onRenderedFirstFrame() {
                Log.d(TAG, "Sending onRenderedFirstFrame")
                channel.invokeMethod("onRenderedFirstFrame", null)
            }
            
            override fun onLoadingChanged(isLoading: Boolean) {
                 Log.d(TAG, "Sending onLoadingChanged: $isLoading")
                channel.invokeMethod("onLoadingChanged", mapOf(
                    "isLoading" to isLoading
                ))
            }
            
            override fun onTracksChanged(tracks: Tracks) {
                Log.d(TAG, "Tracks changed. Processing and sending onTracksChanged.")
                val videoTracks = mutableListOf<Map<String, Any>>()
                val audioTracks = mutableListOf<Map<String, Any>>()
                val subtitleTracks = mutableListOf<Map<String, Any>>()
                
                for (trackGroup in tracks.groups) {
                    if (trackGroup.length > 0) {
                        val trackFormat = trackGroup.getTrackFormat(0)
                        when {
                            trackFormat.sampleMimeType?.startsWith("video/") == true -> {
                                videoTracks.add(mapOf(
                                    "width" to (trackFormat.width ?: 0),
                                    "height" to (trackFormat.height ?: 0),
                                    "bitrate" to (trackFormat.bitrate ?: 0),
                                    "frameRate" to (trackFormat.frameRate ?: 0f),
                                    "codec" to (trackFormat.codecs ?: "unknown"),
                                    "name" to (trackFormat.label ?: "Video Track")
                                ))
                            }
                            trackFormat.sampleMimeType?.startsWith("audio/") == true -> {
                                audioTracks.add(mapOf(
                                    "bitrate" to (trackFormat.bitrate ?: 0),
                                    "sampleRate" to (trackFormat.sampleRate ?: 0),
                                    "channelCount" to (trackFormat.channelCount ?: 0),
                                    "codec" to (trackFormat.codecs ?: "unknown"),
                                    "name" to (trackFormat.label ?: "Audio Track"),
                                    "language" to (trackFormat.language ?: "Unknown")
                                ))
                            }
                            trackFormat.sampleMimeType?.startsWith("text/") == true || trackFormat.sampleMimeType?.contains("subtitle") == true -> {
                                subtitleTracks.add(mapOf(
                                    "name" to (trackFormat.label ?: "Subtitle"),
                                    "language" to (trackFormat.language ?: "Unknown")
                                ))
                            }
                        }
                    }
                }
                
                val payload = mapOf(
                    "videoTracks" to videoTracks,
                    "audioTracks" to audioTracks,
                    "subtitleTracks" to subtitleTracks
                )
                Log.d(TAG, "Sending onTracksChanged with data: $payload")
                channel.invokeMethod("onTracksChanged", payload)
            }
        })
    }
    
    private fun setupMethodChannel() {
        channel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Method call from Flutter: ${call.method} with args: ${call.arguments}")
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
                    val positionArg = call.argument<Number>("position")
                    val position = positionArg?.toLong() ?: 0L
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
                
                "getSystemVolume" -> {
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val volumeRatio = if (maxVolume > 0) currentVolume.toDouble() / maxVolume.toDouble() else 0.0
                    result.success(volumeRatio)
                }
                
                "setSystemVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 0.7
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val targetVolume = (volume * maxVolume).toInt()
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
                    result.success(null)
                }

                "setResizeMode" -> {
                    val modeString = call.argument<String>("mode")
                    val resizeMode = when (modeString) {
                        "fit" -> AspectRatioFrameLayout.RESIZE_MODE_FIT
                        "stretch" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
                        "zoomToFill" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                        else -> {
                            Log.w(TAG, "Unknown resize mode: $modeString, defaulting to FIT")
                            AspectRatioFrameLayout.RESIZE_MODE_FIT
                        }
                    }
                    playerView.resizeMode = resizeMode
                    Log.d(TAG, "Set resizeMode to $modeString ($resizeMode)")
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
                
                else -> {
                    Log.w(TAG, "Received unhandled method: ${call.method}")
                    // Track selection methods
                    when (call.method) {
                        "setAudioTrack" -> {
                            val index = call.argument<Int>("index") ?: 0
                            setAudioTrack(index)
                            result.success(null)
                        }
                        "setSubtitleTrack" -> {
                            val index = call.argument<Int>("index") ?: 0
                            setSubtitleTrack(index)
                            result.success(null)
                        }
                        "disableSubtitle" -> {
                            disableSubtitle()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }
    }
    
    private fun loadVideo(videoPath: String, autoPlay: Boolean = true, startPosition: Long? = null) {
        Log.d(TAG, "loadVideo: path=$videoPath, autoPlay=$autoPlay, startPosition=$startPosition")
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
            Log.d(TAG, "ExoPlayer.prepare() called.")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error loading video: ${e.message}", e)
            channel.invokeMethod("onError", mapOf(
                "error" to "Failed to load video: ${e.message}",
                "errorCode" to -1 // Generic load error
            ))
        }
    }
    
    // Lifecycle management
    fun onStart() {
        Log.d(TAG, "onStart called")
        startPositionUpdates()
    }
    
    fun onStop() {
        Log.d(TAG, "onStop called")
        stopPositionUpdates()
        savePlayerState() // It's good practice to save state here too
        // Consider pausing the player if activity is fully stopped: exoPlayer.pause()
    }
    
    fun onResume() {
        Log.d(TAG, "onResume called")
        // For API 23 and below, player needs reinitialization if released.
        // For API 24+, if player is just paused, it might resume automatically or need a play() call.
        // Current setup doesn't release onPause for API 23-, so this might be okay.
        // If playWhenReady was true, it should resume.
        if (android.os.Build.VERSION.SDK_INT <= 23) {
            // If player was released onPause, it would need re-init here.
            // This app's onPause for API 23- only saves state, doesn't release.
        }
         startPositionUpdates() // Restart position updates if they were stopped
    }
    
    fun onPause() {
        Log.d(TAG, "onPause called")
        // For API 23 and below, onStop is not guaranteed. Release player here.
        // For API 24+, onStop will be called.
        // However, to be safe and handle interruptions like calls, always pause.
        exoPlayer.pause() // Ensure player is paused
        stopPositionUpdates() // Stop updates when paused
        savePlayerState()

        // Original code for API 23 and below only saved state.
        // Consider if releasing is better for older APIs if issues persist.
        // if (android.os.Build.VERSION.SDK_INT <= 23) {
        //     releasePlayer() // Example: if you decide to release on older APIs
        // }
        // Make sure playerView is also paused visually if needed, though ExoPlayer handles rendering.
    }
    
    private fun savePlayerState() {
        if (exoPlayer.isCommandAvailable(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)) {
            currentPosition = exoPlayer.currentPosition
            mediaItemIndex = exoPlayer.currentMediaItemIndex
            playWhenReady = exoPlayer.playWhenReady
            Log.d(TAG, "savePlayerState: pos=$currentPosition, itemIdx=$mediaItemIndex, playWhenReady=$playWhenReady")
        } else {
            Log.w(TAG, "savePlayerState: Player not ready to save state.")
        }
    }
    
    override fun getView(): View = frameLayout
    
    override fun dispose() {
        Log.d(TAG, "dispose called, releasing ExoPlayer.")
        stopPositionUpdates()
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