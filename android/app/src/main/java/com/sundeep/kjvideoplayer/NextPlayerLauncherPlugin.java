package com.sundeep.kjvideoplayer;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * Plugin to launch the actual NextPlayer app for video playback
 */
public class NextPlayerLauncherPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String CHANNEL = "nextplayer_launcher";
    private static final String NEXTPLAYER_PACKAGE = "dev.anilbeesetti.nextplayer";
    private static final String NEXTPLAYER_PLAYER_ACTIVITY = "dev.anilbeesetti.nextplayer.feature.player.PlayerActivity";
    
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "launchVideo":
                String videoPath = call.argument("videoPath");
                if (videoPath != null) {
                    launchVideoWithNextPlayer(videoPath, result);
                } else {
                    result.error("INVALID_ARGUMENT", "Video path is required", null);
                }
                break;
            case "isNextPlayerInstalled":
                result.success(isNextPlayerInstalled());
                break;
            case "launchNextPlayerApp":
                launchNextPlayerApp(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void launchVideoWithNextPlayer(String videoPath, Result result) {
        try {
            if (!isNextPlayerInstalled()) {
                result.error("APP_NOT_INSTALLED", "NextPlayer app is not installed", null);
                return;
            }

            Intent intent = new Intent();
            intent.setClassName(NEXTPLAYER_PACKAGE, NEXTPLAYER_PLAYER_ACTIVITY);
            intent.setAction(Intent.ACTION_VIEW);
            intent.setDataAndType(Uri.parse(videoPath), "video/*");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            
            context.startActivity(intent);
            result.success(true);
        } catch (Exception e) {
            result.error("LAUNCH_ERROR", "Failed to launch NextPlayer", e.getMessage());
        }
    }

    private void launchNextPlayerApp(Result result) {
        try {
            if (!isNextPlayerInstalled()) {
                result.error("APP_NOT_INSTALLED", "NextPlayer app is not installed", null);
                return;
            }

            Intent intent = context.getPackageManager().getLaunchIntentForPackage(NEXTPLAYER_PACKAGE);
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                result.success(true);
            } else {
                result.error("LAUNCH_ERROR", "Cannot create launch intent for NextPlayer", null);
            }
        } catch (Exception e) {
            result.error("LAUNCH_ERROR", "Failed to launch NextPlayer app", e.getMessage());
        }
    }

    private boolean isNextPlayerInstalled() {
        try {
            context.getPackageManager().getPackageInfo(NEXTPLAYER_PACKAGE, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}