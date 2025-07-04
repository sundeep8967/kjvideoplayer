package com.sundeep.kjvideoplayer.player

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.common.MediaItem
import androidx.media3.ui.PlayerView
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.VideoSize
import android.os.Handler
import android.os.Looper

class NextPlayerPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any>?
) : PlatformView {
    private val frameLayout: FrameLayout = FrameLayout(context)
    private val playerView: PlayerView = PlayerView(context)
    private val exoPlayer: ExoPlayer = ExoPlayer.Builder(context).build()
    private val channel: MethodChannel = MethodChannel(messenger, "nextplayer_view_$id")
    private val globalChannel: MethodChannel = MethodChannel(messenger, "exoplayer_video_player")
    private val handler = Handler(Looper.getMainLooper())
    private var positionUpdateRunnable: Runnable? = null

    init {
        frameLayout.addView(playerView)
        playerView.player = exoPlayer

        val videoPath = creationParams?.get("videoPath") as? String
        if (videoPath != null) {
            val mediaItem = MediaItem.fromUri(videoPath)
            exoPlayer.setMediaItem(mediaItem)
            exoPlayer.prepare()
        }

        // Handle both local and global method calls
        channel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        
        globalChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                val isBuffering = playbackState == Player.STATE_BUFFERING
                val isPlaying = exoPlayer.isPlaying
                
                globalChannel.invokeMethod("onPlayerStateChanged", mapOf(
                    "isPlaying" to isPlaying,
                    "isBuffering" to isBuffering
                ))
                
                when (playbackState) {
                    Player.STATE_READY -> {
                        globalChannel.invokeMethod("onPlayerReady", null)
                        globalChannel.invokeMethod("onDurationChanged", mapOf(
                            "duration" to exoPlayer.duration
                        ))
                        startPositionUpdates()
                    }
                    Player.STATE_ENDED -> {
                        channel.invokeMethod("onCompleted", null)
                        stopPositionUpdates()
                    }
                }
            }
            
            override fun onPlayerError(error: PlaybackException) {
                globalChannel.invokeMethod("onError", mapOf(
                    "error" to error.message
                ))
            }
            
            override fun onVideoSizeChanged(videoSize: VideoSize) {
                globalChannel.invokeMethod("onVideoSizeChanged", mapOf(
                    "width" to videoSize.width.toDouble(),
                    "height" to videoSize.height.toDouble()
                ))
            }
        })
    }

    override fun getView(): View = frameLayout
    private fun handleMethodCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val videoPath = call.argument<String>("videoPath")
                if (videoPath != null) {
                    val mediaItem = MediaItem.fromUri(videoPath)
                    exoPlayer.setMediaItem(mediaItem)
                    exoPlayer.prepare()
                }
                result.success(null)
            }
            "play" -> {
                exoPlayer.play()
                result.success(null)
                startPositionUpdates()
            }
            "pause" -> {
                exoPlayer.pause()
                result.success(null)
                stopPositionUpdates()
            }
            "seekTo" -> {
                val position = call.argument<Int>("position") ?: 0
                exoPlayer.seekTo(position.toLong())
                result.success(null)
            }
            "setPlaybackSpeed" -> {
                val speed = call.argument<Double>("speed") ?: 1.0
                exoPlayer.setPlaybackSpeed(speed.toFloat())
                result.success(null)
            }
            "dispose" -> {
                stopPositionUpdates()
                exoPlayer.release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
    
    private fun startPositionUpdates() {
        stopPositionUpdates()
        positionUpdateRunnable = object : Runnable {
            override fun run() {
                if (exoPlayer.isPlaying) {
                    globalChannel.invokeMethod("onPositionChanged", mapOf(
                        "position" to exoPlayer.currentPosition
                    ))
                    handler.postDelayed(this, 1000) // Update every second
                }
            }
        }
        handler.post(positionUpdateRunnable!!)
    }
    
    private fun stopPositionUpdates() {
        positionUpdateRunnable?.let { handler.removeCallbacks(it) }
        positionUpdateRunnable = null
    }

    override fun dispose() {
        stopPositionUpdates()
        exoPlayer.release()
    }
}

class NextPlayerPlatformViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        return NextPlayerPlatformView(context, messenger, id, creationParams)
    }
}
