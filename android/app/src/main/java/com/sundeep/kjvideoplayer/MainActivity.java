package com.sundeep.kjvideoplayer;

import io.flutter.embedding.android.FlutterActivity;

import android.os.Bundle;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import androidx.annotation.NonNull;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.sundeep.kjvideoplayer/nextplayer";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("launchNextPlayer")) {
                        String videoPath = call.argument("videoPath");
                        NextPlayerLauncher.launchNextPlayer(this, videoPath);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }
}