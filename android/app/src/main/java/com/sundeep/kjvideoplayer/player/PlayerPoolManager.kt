package com.sundeep.kjvideoplayer.player

import android.content.Context
import androidx.media3.common.C
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import java.util.LinkedList

object PlayerPoolManager {
    private const val MAX_POOL_SIZE = 3
    private val playerPool = LinkedList<ExoPlayer>()
    private val activePlayers = mutableMapOf<String, ExoPlayer>()

    fun acquirePlayer(context: Context, videoPath: String): ExoPlayer {
        val player = if (playerPool.isNotEmpty()) {
            playerPool.removeFirst()
        } else {
            createPlayer(context)
        }
        activePlayers[videoPath] = player
        return player
    }

    fun releasePlayer(videoPath: String) {
        val player = activePlayers.remove(videoPath)
        if (player != null) {
            player.stop()
            player.clearMediaItems()
            if (playerPool.size < MAX_POOL_SIZE) {
                playerPool.add(player)
            } else {
                player.release()
            }
        }
    }

    fun preload(context: Context, videoPath: String) {
        if (activePlayers.containsKey(videoPath)) {
            return
        }
        val player = acquirePlayer(context, videoPath)
        val mediaItem = androidx.media3.common.MediaItem.fromUri(videoPath)
        player.setMediaItem(mediaItem)
        player.prepare()
    }

    private fun createPlayer(context: Context): ExoPlayer {
        val trackSelector = DefaultTrackSelector(context).apply {
            setParameters(buildUponParameters().setAllowVideoMixedMimeTypeAdaptiveness(true))
        }
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                15_000, 30_000, 1_500, 3_000
            )
            .build()
        val renderersFactory = DefaultRenderersFactory(context).apply {
            setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
        }

        return ExoPlayer.Builder(context, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()
    }

    fun cleanUp() {
        playerPool.forEach { it.release() }
        playerPool.clear()
        activePlayers.values.forEach { it.release() }
        activePlayers.clear()
    }
}
