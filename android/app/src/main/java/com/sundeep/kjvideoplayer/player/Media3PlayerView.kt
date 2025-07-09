package com.sundeep.kjvideoplayer.player

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
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
    private var volumeBroadcastReceiver: BroadcastReceiver? = null

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
    
    // Track selector for advanced track detection
    private val trackSelector: DefaultTrackSelector = DefaultTrackSelector(context)
    
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

        // Start periodic position updates
        positionUpdateHandler.post(positionUpdateRunnable)

        // Initialize volume observer
        initializeVolumeObserver()
        // Initialize volume broadcast receiver
        initializeVolumeBroadcastReceiver()
    }

    private fun initializeVolumeBroadcastReceiver() {
        if (volumeBroadcastReceiver != null) return
        volumeBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val volumeRatio = if (maxVolume > 0) currentVolume.toDouble() / maxVolume.toDouble() else 0.0
                    channel.invokeMethod("onSystemVolumeChanged", mapOf("volume" to volumeRatio))
                    Log.d(TAG, "BroadcastReceiver: System volume changed to: $volumeRatio")
                }
            }
        }
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        context.registerReceiver(volumeBroadcastReceiver, filter)
        Log.d(TAG, "Volume broadcast receiver initialized")
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
                .setRendererDisabled(C.TRACK_TYPE_AUDIO, false) // Ensure audio renderer is enabled
                .setPreferredTextLanguage("en")
                .setSelectUndeterminedTextLanguage(true)
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

    // Add this method to get tracks using TrackSelector directly
    private fun getTracksFromTrackSelector(): Map<String, Any> {
        val videoTracks = mutableListOf<Map<String, Any>>()
        val audioTracks = mutableListOf<Map<String, Any>>()
        val subtitleTracks = mutableListOf<Map<String, Any>>()
        
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo
        if (mappedTrackInfo == null) {
            Log.w(TAG, "MappedTrackInfo is null, tracks not ready yet")
            return mapOf(
                "videoTracks" to videoTracks,
                "audioTracks" to audioTracks,
                "subtitleTracks" to subtitleTracks
            )
        }
        
        Log.d(TAG, "Processing ${mappedTrackInfo.rendererCount} renderers")
        Log.d(TAG, "TrackSelector parameters: ${trackSelector.parameters}")
        Log.d(TAG, "Renderer capabilities:")
        for (i in 0 until mappedTrackInfo.rendererCount) {
            Log.d(TAG, "Renderer $i (${mappedTrackInfo.getRendererType(i)}): " +
                "supported=${mappedTrackInfo.getRendererSupport(i)}")
        }
        
        for (rendererIndex in 0 until mappedTrackInfo.rendererCount) {
            val rendererType = mappedTrackInfo.getRendererType(rendererIndex)
            val trackGroups = mappedTrackInfo.getTrackGroups(rendererIndex)
            
            Log.d(TAG, "Renderer $rendererIndex: type=$rendererType, groups=${trackGroups.length}")
            
            when (rendererType) {
                C.TRACK_TYPE_AUDIO -> {
                    for (groupIndex in 0 until trackGroups.length) {
                        val trackGroup = trackGroups[groupIndex]
                        Log.d(TAG, "Audio group $groupIndex has ${trackGroup.length} tracks")
                        
                        for (trackIndex in 0 until trackGroup.length) {
                            val format = trackGroup.getFormat(trackIndex)
                            val isSupported = mappedTrackInfo.getTrackSupport(rendererIndex, groupIndex, trackIndex) == C.FORMAT_HANDLED
                            
                            val audioTrack = mapOf(
                                "index" to trackIndex,
                                "groupIndex" to groupIndex,
                                "rendererIndex" to rendererIndex,
                                "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                                "sampleRate" to (format.sampleRate.takeIf { it != Format.NO_VALUE } ?: 0),
                                "channelCount" to (format.channelCount.takeIf { it != Format.NO_VALUE } ?: 0),
                                "codec" to (format.codecs ?: "unknown"),
                                "mimeType" to (format.sampleMimeType ?: "unknown"),
                                "name" to (format.label ?: "Audio Track ${audioTracks.size + 1}"),
                                "language" to (format.language ?: "Unknown"),
                                "isSelected" to false, // Will be updated below
                                "isSupported" to isSupported
                            )
                            
                            audioTracks.add(audioTrack)
                            Log.d(TAG, "Added audio track: $audioTrack")
                        }
                    }
                }
                
                C.TRACK_TYPE_VIDEO -> {
                    for (groupIndex in 0 until trackGroups.length) {
                        val trackGroup = trackGroups[groupIndex]
                        
                        for (trackIndex in 0 until trackGroup.length) {
                            val format = trackGroup.getFormat(trackIndex)
                            val isSupported = mappedTrackInfo.getTrackSupport(rendererIndex, groupIndex, trackIndex) == C.FORMAT_HANDLED
                            
                            val videoTrack = mapOf(
                                "index" to trackIndex,
                                "groupIndex" to groupIndex,
                                "rendererIndex" to rendererIndex,
                                "width" to (format.width.takeIf { it != Format.NO_VALUE } ?: 0),
                                "height" to (format.height.takeIf { it != Format.NO_VALUE } ?: 0),
                                "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                                "frameRate" to (format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() } ?: 0f),
                                "codec" to (format.codecs ?: "unknown"),
                                "mimeType" to (format.sampleMimeType ?: "unknown"),
                                "name" to (format.label ?: "Video Track ${videoTracks.size + 1}"),
                                "isSelected" to false, // Will be updated below
                                "isSupported" to isSupported
                            )
                            
                            videoTracks.add(videoTrack)
                            Log.d(TAG, "Added video track: $videoTrack")
                        }
                    }
                }
                
                C.TRACK_TYPE_TEXT -> {
                    for (groupIndex in 0 until trackGroups.length) {
                        val trackGroup = trackGroups[groupIndex]
                        
                        for (trackIndex in 0 until trackGroup.length) {
                            val format = trackGroup.getFormat(trackIndex)
                            val isSupported = mappedTrackInfo.getTrackSupport(rendererIndex, groupIndex, trackIndex) == C.FORMAT_HANDLED
                            
                            val subtitleTrack = mapOf(
                                "index" to trackIndex,
                                "groupIndex" to groupIndex,
                                "rendererIndex" to rendererIndex,
                                "name" to (format.label ?: "Subtitle Track ${subtitleTracks.size + 1}"),
                                "language" to (format.language ?: "Unknown"),
                                "mimeType" to (format.sampleMimeType ?: "unknown"),
                                "isSelected" to false, // Will be updated below
                                "isSupported" to isSupported
                            )
                            
                            subtitleTracks.add(subtitleTrack)
                            Log.d(TAG, "Added subtitle track: $subtitleTrack")
                        }
                    }
                }
            }
        }
        
        // Determine current audio track index from track selector
        val currentAudioIndex = try {
            val audioRendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
                mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
            }
            
            if (audioRendererIndex != null) {
                val audioTrackGroups = mappedTrackInfo.getTrackGroups(audioRendererIndex)
                val selection = trackSelector.parameters.getSelectionOverride(
                    audioRendererIndex,
                    audioTrackGroups
                )
                
                if (selection != null) {
                    // Calculate global index from selection
                    var globalIndex = 0
                    for (groupIndex in 0 until selection.groupIndex) {
                        globalIndex += audioTrackGroups[groupIndex].length
                    }
                    globalIndex += selection.tracks[0]
                    
                    // Mark the selected track
                    if (globalIndex < audioTracks.size) {
                        val selectedTrack = audioTracks[globalIndex].toMutableMap()
                        selectedTrack["isSelected"] = true
                        audioTracks[globalIndex] = selectedTrack
                    }
                    
                    globalIndex
                } else if (audioTracks.isNotEmpty()) {
                    // No selection override, mark first track as selected by default
                    val firstTrack = audioTracks[0].toMutableMap()
                    firstTrack["isSelected"] = true
                    audioTracks[0] = firstTrack
                    0
                } else {
                    null
                }
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error determining current audio track index: $e")
            null
        }

        Log.d(TAG, "Current audio track index: $currentAudioIndex")
        
        return mapOf<String, Any>(
            "videoTracks" to videoTracks,
            "audioTracks" to audioTracks,
            "subtitleTracks" to subtitleTracks,
            "currentAudioTrackIndex" to (currentAudioIndex ?: -1)
        )
    }

    // Add this method to check tracks directly from the player
    private fun getTracksFromPlayer(): Map<String, List<Map<String, Any>>> {
        val videoTracks = mutableListOf<Map<String, Any>>()
        val audioTracks = mutableListOf<Map<String, Any>>()
        val subtitleTracks = mutableListOf<Map<String, Any>>()
        
        val currentTracks = exoPlayer.currentTracks
        Log.d(TAG, "Getting tracks directly from player: ${currentTracks.groups.size} groups")
        
        if (currentTracks.groups.isEmpty()) {
            Log.w(TAG, "No track groups found in player")
            return mapOf(
                "videoTracks" to videoTracks,
                "audioTracks" to audioTracks,
                "subtitleTracks" to subtitleTracks
            )
        }
        
        for (groupIndex in 0 until currentTracks.groups.size) {
            val trackGroup = currentTracks.groups[groupIndex]
            Log.d(TAG, "Player track group $groupIndex has ${trackGroup.mediaTrackGroup.length} tracks")
            
            if (trackGroup.mediaTrackGroup.length == 0) continue
            
            val firstFormat = trackGroup.mediaTrackGroup.getFormat(0)
            val mimeType = firstFormat.sampleMimeType
            
            Log.d(TAG, "Player group $groupIndex MIME type: $mimeType")
            
            when {
                mimeType?.startsWith("video/") == true -> {
                    for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                        val format = trackGroup.mediaTrackGroup.getFormat(trackIndex)
                        val isSupported = trackGroup.isTrackSupported(trackIndex)
                        val isSelected = trackGroup.isTrackSelected(trackIndex)
                        
                        videoTracks.add(mapOf(
                            "index" to trackIndex,
                            "groupIndex" to groupIndex,
                            "width" to (format.width.takeIf { it != Format.NO_VALUE } ?: 0),
                            "height" to (format.height.takeIf { it != Format.NO_VALUE } ?: 0),
                            "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                            "frameRate" to (format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() } ?: 0f),
                            "codec" to (format.codecs ?: "unknown"),
                            "mimeType" to (format.sampleMimeType ?: "unknown"),
                            "name" to (format.label ?: "Video Track $trackIndex"),
                            "isSelected" to isSelected,
                            "isSupported" to isSupported
                        ))
                    }
                }
                
                mimeType?.startsWith("audio/") == true -> {
                    for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                        val format = trackGroup.mediaTrackGroup.getFormat(trackIndex)
                        val isSupported = trackGroup.isTrackSupported(trackIndex)
                        val isSelected = trackGroup.isTrackSelected(trackIndex)
                        
                        audioTracks.add(mapOf(
                            "index" to trackIndex,
                            "groupIndex" to groupIndex,
                            "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                            "sampleRate" to (format.sampleRate.takeIf { it != Format.NO_VALUE } ?: 0),
                            "channelCount" to (format.channelCount.takeIf { it != Format.NO_VALUE } ?: 0),
                            "codec" to (format.codecs ?: "unknown"),
                            "mimeType" to (format.sampleMimeType ?: "unknown"),
                            "name" to (format.label ?: "Audio Track $trackIndex"),
                            "language" to (format.language ?: "Unknown"),
                            "isSelected" to isSelected,
                            "isSupported" to isSupported
                        ))
                    }
                }
                
                mimeType?.startsWith("text/") == true || 
                mimeType?.contains("subtitle") == true ||
                mimeType?.contains("vtt") == true ||
                mimeType?.contains("ttml") == true -> {
                    for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                        val format = trackGroup.mediaTrackGroup.getFormat(trackIndex)
                        val isSupported = trackGroup.isTrackSupported(trackIndex)
                        val isSelected = trackGroup.isTrackSelected(trackIndex)
                        
                        subtitleTracks.add(mapOf(
                            "index" to trackIndex,
                            "groupIndex" to groupIndex,
                            "name" to (format.label ?: "Subtitle $trackIndex"),
                            "language" to (format.language ?: "Unknown"),
                            "mimeType" to (format.sampleMimeType ?: "unknown"),
                            "isSelected" to isSelected,
                            "isSupported" to isSupported
                        ))
                    }
                }
            }
        }
        
        return mapOf(
            "videoTracks" to videoTracks,
            "audioTracks" to audioTracks,
            "subtitleTracks" to subtitleTracks
        )
    }

    // Add a method to manually trigger track detection with multiple approaches
    private fun manuallyDetectTracks() {
        Log.d(TAG, "Manually detecting tracks...")
        
        // Wait a bit for tracks to be ready
        Handler(Looper.getMainLooper()).postDelayed({
            // Try multiple approaches
            val tracksFromSelector = getTracksFromTrackSelector()
            val tracksFromPlayer = getTracksFromPlayer()
            
            var videoTracks = tracksFromSelector["videoTracks"] as? List<Map<String, Any>> ?: emptyList()
            var audioTracks = tracksFromSelector["audioTracks"] as? List<Map<String, Any>> ?: emptyList()
            var subtitleTracks = tracksFromSelector["subtitleTracks"] as? List<Map<String, Any>> ?: emptyList()
            
            // Use player tracks if selector didn't find any
            if (videoTracks.isEmpty()) {
                videoTracks = tracksFromPlayer["videoTracks"] as List<Map<String, Any>>
            }
            if (audioTracks.isEmpty()) {
                audioTracks = tracksFromPlayer["audioTracks"] as List<Map<String, Any>>
            }
            if (subtitleTracks.isEmpty()) {
                subtitleTracks = tracksFromPlayer["subtitleTracks"] as List<Map<String, Any>>
            }
            
            Log.d(TAG, "Manual detection - Video: ${videoTracks.size}, Audio: ${audioTracks.size}, Subtitle: ${subtitleTracks.size}")
            
            // Handle empty audio tracks case - check if audio is actually playing
            val finalAudioTracks = if (audioTracks.isEmpty()) {
                Log.w(TAG, "No audio tracks detected, checking if audio is actually playing")
                val hasAudio = exoPlayer.audioFormat != null
                Log.d(TAG, "Player audio format: ${exoPlayer.audioFormat}")
                
                if (hasAudio) {
                    Log.w(TAG, "Player has audio but no tracks detected - creating default track")
                    listOf(mapOf(
                        "index" to 0,
                        "groupIndex" to 0,
                        "name" to "Default Audio",
                        "language" to "Unknown",
                        "codec" to (exoPlayer.audioFormat?.codecs ?: "unknown"),
                        "mimeType" to (exoPlayer.audioFormat?.sampleMimeType ?: "unknown"),
                        "bitrate" to (exoPlayer.audioFormat?.bitrate?.takeIf { it != Format.NO_VALUE } ?: 0),
                        "sampleRate" to (exoPlayer.audioFormat?.sampleRate?.takeIf { it != Format.NO_VALUE } ?: 0),
                        "channelCount" to (exoPlayer.audioFormat?.channelCount?.takeIf { it != Format.NO_VALUE } ?: 0),
                        "isSelected" to true,
                        "isSupported" to true
                    ))
                } else {
                    audioTracks
                }
            } else {
                audioTracks
            }
            
            if (finalAudioTracks.isNotEmpty() || videoTracks.isNotEmpty() || subtitleTracks.isNotEmpty()) {
                val payload = mapOf(
                    "videoTracks" to videoTracks,
                    "audioTracks" to finalAudioTracks,
                    "subtitleTracks" to subtitleTracks
                )
                
                Log.d(TAG, "Sending manual onTracksChanged with payload: $payload")
                channel.invokeMethod("onTracksChanged", payload)
            } else {
                Log.w(TAG, "No tracks detected from any method - will retry in 2 seconds")
                // Retry once more after additional delay
                Handler(Looper.getMainLooper()).postDelayed({
                    manuallyDetectTracks()
                }, 2000)
            }
        }, 1000) // Wait 1 second
    }

    // Track selection helpers
    private fun setAudioTrack(index: Int) {
        try {
            Log.d(TAG, "setAudioTrack called with index: $index")
            
            val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: run {
                Log.e(TAG, "setAudioTrack: MappedTrackInfo is null")
                return
            }
            
            // Find audio renderer
            val audioRendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
                mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
            } ?: run {
                Log.e(TAG, "setAudioTrack: No audio renderer found")
                return
            }
            
            val trackGroups = mappedTrackInfo.getTrackGroups(audioRendererIndex)
            if (trackGroups.length == 0) {
                Log.e(TAG, "setAudioTrack: No audio track groups available")
                return
            }
            
            // Find the correct group and track index
            var currentTrackCount = 0
            var targetGroupIndex = -1
            var targetTrackIndex = -1
            
            for (groupIndex in 0 until trackGroups.length) {
                val trackGroup = trackGroups[groupIndex]
                if (index < currentTrackCount + trackGroup.length) {
                    targetGroupIndex = groupIndex
                    targetTrackIndex = index - currentTrackCount
                    break
                }
                currentTrackCount += trackGroup.length
            }
            
            if (targetGroupIndex == -1 || targetTrackIndex == -1) {
                Log.e(TAG, "setAudioTrack: Invalid track index $index (total tracks: $currentTrackCount)")
                return
            }
            
            Log.d(TAG, "setAudioTrack: Selecting group $targetGroupIndex, track $targetTrackIndex")
            
            // Save current playback state
            val wasPlaying = exoPlayer.isPlaying
            val currentPosition = exoPlayer.currentPosition
            
            // Build new parameters
            val parameters = trackSelector.buildUponParameters()
                .setRendererDisabled(audioRendererIndex, false)
                .setSelectionOverride(
                    audioRendererIndex,
                    trackGroups,
                    DefaultTrackSelector.SelectionOverride(targetGroupIndex, targetTrackIndex)
                )
                .build()
            
            // Apply the new parameters
            trackSelector.setParameters(parameters)
            Log.d(TAG, "setAudioTrack: Parameters applied successfully")
            
            // Wait a moment for parameters to take effect before rebuilding
            Handler(Looper.getMainLooper()).postDelayed({
                // Completely rebuild the player to ensure track change takes effect
                exoPlayer.stop()
                exoPlayer.prepare()
                
                // Wait for player to be ready before restoring state
                Handler(Looper.getMainLooper()).postDelayed({
                    // Restore playback state
                    if (wasPlaying) {
                        exoPlayer.play()
                    }
                    exoPlayer.seekTo(currentPosition)
                    
                    // Force immediate track update after everything is ready
                    Handler(Looper.getMainLooper()).postDelayed({
                        val tracks = getTracksFromTrackSelector().toMutableMap().apply {
                            put("currentAudioTrackIndex", index)
                        }
                        channel.invokeMethod("onTracksChanged", tracks)
                        Log.d(TAG, "setAudioTrack: Track change completed for index $index")
                    }, 200)
                }, 300)
            }, 100)
            
        } catch (e: Exception) {
            Log.e(TAG, "setAudioTrack: Error setting audio track $index", e)
        }
    }

    private fun forceAudioTrackRefresh(index: Int) {
        Log.d(TAG, "forceAudioTrackRefresh: $index")
        
        // Save current state
        val wasPlaying = exoPlayer.isPlaying
        val currentPosition = exoPlayer.currentPosition
        
        // Create new media item with same URI but forcing reinitialization
        val currentMediaItem = exoPlayer.currentMediaItem ?: return
        val newMediaItem = currentMediaItem.buildUpon()
            .setUri(currentMediaItem.localConfiguration?.uri)
            .build()
        
        // Rebuild player
        exoPlayer.setMediaItem(newMediaItem)
        exoPlayer.prepare()
        
        // Restore state
        if (wasPlaying) {
            exoPlayer.play()
        }
        exoPlayer.seekTo(currentPosition)
        
        // Reselect the audio track
        Handler(Looper.getMainLooper()).postDelayed({
            setAudioTrack(index)
        }, 300) // Small delay to ensure player is ready
    }

    private fun verifyAudioTrackSelection(index: Int): Boolean {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return false
        val audioRendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
            mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
        } ?: return false
        
        val trackGroups = mappedTrackInfo.getTrackGroups(audioRendererIndex)
        val selection = trackSelector.parameters.getSelectionOverride(
            audioRendererIndex,
            trackGroups
        )
        
        if (selection == null) {
            Log.d(TAG, "verifyAudioTrackSelection: No selection override exists")
            return false
        }
        
        // Calculate global index from selection
        var globalIndex = 0
        for (groupIndex in 0 until selection.groupIndex) {
            globalIndex += trackGroups[groupIndex].length
        }
        globalIndex += selection.tracks[0]
        
        val verified = globalIndex == index
        Log.d(TAG, "verifyAudioTrackSelection: Expected $index, actual $globalIndex -> $verified")
        
        return verified
    }

    private fun debugAudioTracks() {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return
        val audioRendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
            mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
        } ?: return
        
        val trackGroups = mappedTrackInfo.getTrackGroups(audioRendererIndex)
        Log.d(TAG, "===== AUDIO TRACK DEBUG =====")
        Log.d(TAG, "Renderer index: $audioRendererIndex")
        Log.d(TAG, "Track groups: ${trackGroups.length}")
        
        for (groupIndex in 0 until trackGroups.length) {
            val group = trackGroups[groupIndex]
            Log.d(TAG, "Group $groupIndex (${group.length} tracks):")
            
            for (trackIndex in 0 until group.length) {
                val format = group.getFormat(trackIndex)
                Log.d(TAG, "  Track $trackIndex: ${format.label} (${format.language})")
            }
        }
        
        val selection = trackSelector.parameters.getSelectionOverride(
            audioRendererIndex,
            trackGroups
        )
        Log.d(TAG, "Current selection: $selection")
        Log.d(TAG, "=============================")
    }

    private fun debugCurrentAudioTrack() {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return
        val audioRendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
            mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
        } ?: return
        
        val trackGroups = mappedTrackInfo.getTrackGroups(audioRendererIndex)
        val selection = trackSelector.parameters.getSelectionOverride(
            audioRendererIndex,
            trackGroups
        )
        
        Log.d(TAG, "===== CURRENT AUDIO TRACK =====")
        Log.d(TAG, "Renderer index: $audioRendererIndex")
        Log.d(TAG, "Track groups count: ${trackGroups.length}")
        
        if (selection != null) {
            Log.d(TAG, "Selection override: group=${selection.groupIndex}, track=${selection.tracks[0]}")
            
            val selectedGroup = trackGroups[selection.groupIndex]
            val selectedTrack = selection.tracks[0]
            val format = selectedGroup.getFormat(selectedTrack)
            
            Log.d(TAG, "Selected track details:")
            Log.d(TAG, "  Language: ${format.language}")
            Log.d(TAG, "  Label: ${format.label}")
            Log.d(TAG, "  Codec: ${format.codecs}")
            Log.d(TAG, "  Sample rate: ${format.sampleRate}")
            Log.d(TAG, "  Channel count: ${format.channelCount}")
        } else {
            Log.d(TAG, "No selection override - using default track")
        }
        Log.d(TAG, "==============================")
    }

    private fun getSelectedAudioTrackIndex(): Int? {
        try {
            val mappedTrackInfo = trackSelector.currentMappedTrackInfo ?: return null
            val rendererIndex = (0 until mappedTrackInfo.rendererCount).firstOrNull {
                mappedTrackInfo.getRendererType(it) == C.TRACK_TYPE_AUDIO
            } ?: return null
            
            val trackGroups = mappedTrackInfo.getTrackGroups(rendererIndex)
            val selection = trackSelector.parameters.getSelectionOverride(rendererIndex, trackGroups)
            
            if (selection != null) {
                // Calculate the global track index from group and track indices
                var globalIndex = 0
                for (groupIndex in 0 until selection.groupIndex) {
                    globalIndex += trackGroups[groupIndex].length
                }
                globalIndex += selection.tracks[0] // First track in the selection
                return globalIndex
            }
            
            // If no override is set, check current tracks for selected audio
            val currentTracks = exoPlayer.currentTracks
            var globalIndex = 0
            
            for (groupIndex in 0 until currentTracks.groups.size) {
                val trackGroup = currentTracks.groups[groupIndex]
                val firstFormat = trackGroup.mediaTrackGroup.getFormat(0)
                
                if (firstFormat.sampleMimeType?.startsWith("audio/") == true) {
                    for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                        if (trackGroup.isTrackSelected(trackIndex)) {
                            return globalIndex + trackIndex
                        }
                    }
                    globalIndex += trackGroup.mediaTrackGroup.length
                }
            }
            
            return null
        } catch (e: Exception) {
            Log.e(TAG, "getSelectedAudioTrackIndex: Error getting selected audio track", e)
            return null
        }
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
                    
                    // Add delay before track detection to ensure tracks are loaded
                    Handler(Looper.getMainLooper()).postDelayed({
                        manuallyDetectTracks()
                    }, 500) // 500ms delay
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
                Log.d(TAG, "onTracksChanged called with ${tracks.groups.size} track groups")
                debugAudioTracks()
                
                // Use both approaches to ensure we get tracks
                val tracksFromSelector = getTracksFromTrackSelector()
                val videoTracks = tracksFromSelector["videoTracks"] as? List<Map<String, Any>> ?: emptyList()
                val audioTracks = tracksFromSelector["audioTracks"] as? List<Map<String, Any>> ?: emptyList()
                val subtitleTracks = tracksFromSelector["subtitleTracks"] as? List<Map<String, Any>> ?: emptyList()
                
                // Also try the original approach as backup
                val videoTracksFromGroups = mutableListOf<Map<String, Any>>()
                val audioTracksFromGroups = mutableListOf<Map<String, Any>>()
                val subtitleTracksFromGroups = mutableListOf<Map<String, Any>>()
                
                for (groupIndex in 0 until tracks.groups.size) {
                    val trackGroup = tracks.groups[groupIndex]
                    Log.d(TAG, "Processing track group $groupIndex with ${trackGroup.mediaTrackGroup.length} tracks")
                    
                    if (trackGroup.mediaTrackGroup.length == 0) continue
                    
                    val firstFormat = trackGroup.mediaTrackGroup.getFormat(0)
                    val mimeType = firstFormat.sampleMimeType
                    
                    Log.d(TAG, "Group $groupIndex MIME type: $mimeType")
                    
                    when {
                        mimeType?.startsWith("video/") == true -> {
                            for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                                val format = trackGroup.mediaTrackGroup.getFormat(trackIndex)
                                val isSupported = trackGroup.isTrackSupported(trackIndex)
                                val isSelected = trackGroup.isTrackSelected(trackIndex)
                                
                                videoTracksFromGroups.add(mapOf(
                                    "index" to trackIndex,
                                    "groupIndex" to groupIndex,
                                    "width" to (format.width.takeIf { it != Format.NO_VALUE } ?: 0),
                                    "height" to (format.height.takeIf { it != Format.NO_VALUE } ?: 0),
                                    "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                                    "frameRate" to (format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() } ?: 0f),
                                    "codec" to (format.codecs ?: "unknown"),
                                    "mimeType" to (format.sampleMimeType ?: "unknown"),
                                    "name" to (format.label ?: "Video Track $trackIndex"),
                                    "isSelected" to isSelected,
                                    "isSupported" to isSupported
                                ))
                            }
                        }
                        
                        mimeType?.startsWith("audio/") == true -> {
                            for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                                val format = trackGroup.mediaTrackGroup.getFormat(trackIndex)
                                val isSupported = trackGroup.isTrackSupported(trackIndex)
                                val isSelected = trackGroup.isTrackSelected(trackIndex)
                                
                                val audioTrack = mapOf(
                                    "index" to trackIndex,
                                    "groupIndex" to groupIndex,
                                    "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                                    "sampleRate" to (format.sampleRate.takeIf { it != Format.NO_VALUE } ?: 0),
                                    "channelCount" to (format.channelCount.takeIf { it != Format.NO_VALUE } ?: 0),
                                    "codec" to (format.codecs ?: "unknown"),
                                    "mimeType" to (format.sampleMimeType ?: "unknown"),
                                    "name" to (format.label ?: "Audio Track $trackIndex"),
                                    "language" to (format.language ?: "Unknown"),
                                    "isSelected" to isSelected,
                                    "isSupported" to isSupported
                                )
                                
                                audioTracksFromGroups.add(audioTrack)
                                Log.d(TAG, "Found audio track from groups: $audioTrack")
                            }
                        }
                        
                        mimeType?.startsWith("text/") == true || 
                        mimeType?.contains("subtitle") == true ||
                        mimeType?.contains("vtt") == true ||
                        mimeType?.contains("ttml") == true -> {
                            for (trackIndex in 0 until trackGroup.mediaTrackGroup.length) {
                                val format = trackGroup.mediaTrackGroup.getFormat(trackIndex)
                                val isSupported = trackGroup.isTrackSupported(trackIndex)
                                val isSelected = trackGroup.isTrackSelected(trackIndex)
                                
                                subtitleTracksFromGroups.add(mapOf(
                                    "index" to trackIndex,
                                    "groupIndex" to groupIndex,
                                    "name" to (format.label ?: "Subtitle $trackIndex"),
                                    "language" to (format.language ?: "Unknown"),
                                    "mimeType" to (format.sampleMimeType ?: "unknown"),
                                    "isSelected" to isSelected,
                                    "isSupported" to isSupported
                                ))
                            }
                        }
                    }
                }
                
                // Use the approach that found more tracks
                val finalVideoTracks = if (videoTracks.isNotEmpty()) videoTracks else videoTracksFromGroups
                val finalAudioTracks = if (audioTracks.isNotEmpty()) audioTracks else audioTracksFromGroups
                val finalSubtitleTracks = if (subtitleTracks.isNotEmpty()) subtitleTracks else subtitleTracksFromGroups
                
                Log.d(TAG, "Final track counts - Video: ${finalVideoTracks.size}, Audio: ${finalAudioTracks.size}, Subtitle: ${finalSubtitleTracks.size}")
                
                // Enhanced handling for empty audio tracks
                val enhancedAudioTracks = if (finalAudioTracks.isEmpty()) {
                    Log.w(TAG, "No audio tracks found! This might indicate:")
                    Log.w(TAG, "1. Audio tracks not yet loaded")
                    Log.w(TAG, "2. Audio codec not supported")
                    Log.w(TAG, "3. File has no audio")
                    Log.w(TAG, "4. Track detection timing issue")
                    
                    // Check if audio is actually playing
                    val hasAudio = exoPlayer.audioFormat != null
                    Log.d(TAG, "Player audio format in onTracksChanged: ${exoPlayer.audioFormat}")
                    
                    if (hasAudio) {
                        Log.w(TAG, "Player has audio but no tracks detected - creating default track")
                        listOf(mapOf(
                            "index" to 0,
                            "groupIndex" to 0,
                            "name" to "Default Audio",
                            "language" to "Unknown",
                            "codec" to (exoPlayer.audioFormat?.codecs ?: "unknown"),
                            "mimeType" to (exoPlayer.audioFormat?.sampleMimeType ?: "unknown"),
                            "bitrate" to (exoPlayer.audioFormat?.bitrate?.takeIf { it != Format.NO_VALUE } ?: 0),
                            "sampleRate" to (exoPlayer.audioFormat?.sampleRate?.takeIf { it != Format.NO_VALUE } ?: 0),
                            "channelCount" to (exoPlayer.audioFormat?.channelCount?.takeIf { it != Format.NO_VALUE } ?: 0),
                            "isSelected" to true,
                            "isSupported" to true
                        ))
                    } else {
                        finalAudioTracks
                    }
                } else {
                    finalAudioTracks
                }
                
                val payload = mapOf(
                    "videoTracks" to finalVideoTracks,
                    "audioTracks" to enhancedAudioTracks,
                    "subtitleTracks" to finalSubtitleTracks
                )
                
                Log.d(TAG, "Sending onTracksChanged with payload: $payload")
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
                    
                    // Use FLAG_SHOW_UI to show system volume UI and properly handle mute state
                    val flags = if (targetVolume > 0) {
                        AudioManager.FLAG_SHOW_UI or AudioManager.FLAG_PLAY_SOUND
                    } else {
                        AudioManager.FLAG_SHOW_UI
                    }
                    
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, flags)
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
                
                "getTracks" -> {
                    val tracks = getTracksFromTrackSelector()
                    result.success(tracks)
                }
                
                "getTracksFromPlayer" -> {
                    val tracks = getTracksFromPlayer()
                    result.success(tracks)
                }
                
                "testAllTrackMethods" -> {
                    val selectorTracks = getTracksFromTrackSelector()
                    val playerTracks = getTracksFromPlayer()
                    val testResult = mapOf(
                        "selectorTracks" to selectorTracks,
                        "playerTracks" to playerTracks,
                        "hasAudioFormat" to (exoPlayer.audioFormat != null),
                        "audioFormat" to (exoPlayer.audioFormat?.toString() ?: "null"),
                        "playerState" to exoPlayer.playbackState,
                        "isPlaying" to exoPlayer.isPlaying
                    )
                    result.success(testResult)
                }
                
                "refreshTracks" -> {
                    Log.d(TAG, "Manually refreshing tracks...")
                    manuallyDetectTracks()
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
                            // First try normal selection
                            setAudioTrack(index)
                            
                            // Then force refresh if needed - wait longer for the delayed execution
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (!verifyAudioTrackSelection(index)) {
                                    Log.w(TAG, "Initial selection failed, forcing refresh")
                                    forceAudioTrackRefresh(index)
                                } else {
                                    Log.d(TAG, "Audio track selection verified successfully for index $index")
                                }
                            }, 1000) // Increased delay to account for the staged execution
                            
                            result.success(null)
                        }
                        "getSelectedAudioTrackIndex" -> {
                            val selectedIndex = getSelectedAudioTrackIndex()
                            result.success(selectedIndex)
                        }
                        "debugAudioTracks" -> {
                            debugAudioTracks()
                            result.success(null)
                        }
                        "debugCurrentAudioTrack" -> {
                            debugCurrentAudioTrack()
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
        
        // Unregister volume observer
        volumeContentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
        // Unregister volume broadcast receiver
        volumeBroadcastReceiver?.let {
            try {
                context.unregisterReceiver(it)
                Log.d(TAG, "Volume broadcast receiver unregistered")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to unregister volume broadcast receiver: ${e.message}")
            }
        }
        volumeBroadcastReceiver = null
        
        exoPlayer.release()
    }
    
    private fun initializeVolumeObserver() {
        volumeContentObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                super.onChange(selfChange)
                // Notify Flutter about volume change
                val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val volumeRatio = if (maxVolume > 0) currentVolume.toDouble() / maxVolume.toDouble() else 0.0
                
                channel.invokeMethod("onSystemVolumeChanged", mapOf("volume" to volumeRatio))
                Log.d(TAG, "System volume changed to: $volumeRatio")
            }
        }
        
        // Register observer for system volume changes
        context.contentResolver.registerContentObserver(
            Settings.System.getUriFor("volume_music"),
            false,
            volumeContentObserver!!
        )
        
        Log.d(TAG, "Volume observer initialized")
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