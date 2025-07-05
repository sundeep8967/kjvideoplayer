package com.sundeep.kjvideoplayer

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import com.sundeep.kjvideoplayer.player.Media3PlayerViewFactory

/**
 * Media3 Player Plugin for Flutter
 * Registers the Media3 player platform view
 */
class Media3PlayerPlugin: FlutterPlugin, ActivityAware {
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory(
                "media3_player_view",
                Media3PlayerViewFactory(flutterPluginBinding.binaryMessenger)
            )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        // Cleanup if needed
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // Activity attached
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Activity detached for config changes
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // Activity reattached after config changes
    }

    override fun onDetachedFromActivity() {
        // Activity detached
    }
}