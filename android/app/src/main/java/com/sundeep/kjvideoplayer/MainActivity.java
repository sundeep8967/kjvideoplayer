package com.sundeep.kjvideoplayer;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformViewRegistry;


public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.sundeep.kjvideoplayer/nextplayer";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Register NextPlayerPlatformView
        PlatformViewRegistry registry = flutterEngine.getPlatformViewsController().getRegistry();
        registry.registerViewFactory(
            "nextplayer_view",
            new com.sundeep.kjvideoplayer.player.NextPlayerPlatformViewFactory(flutterEngine.getDartExecutor().getBinaryMessenger())
        );


    }
}