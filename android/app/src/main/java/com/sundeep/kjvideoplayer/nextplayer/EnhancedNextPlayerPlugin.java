package com.sundeep.kjvideoplayer.nextplayer;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import android.util.Rational;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * Enhanced NextPlayer Plugin with Advanced Features
 * Implements NextPlayer's professional video player capabilities
 */
public class EnhancedNextPlayerPlugin extends PlatformViewFactory implements FlutterPlugin, ActivityAware {
    private static final String TAG = "EnhancedNextPlayerPlugin";
    private static final String VIEW_TYPE_ID = "enhanced_nextplayer";
    private static final String CHANNEL_NAME = "enhanced_nextplayer";
    
    private BinaryMessenger messenger;
    private Activity activity;
    private MethodChannel methodChannel;
    
    public EnhancedNextPlayerPlugin() {
        super(StandardMessageCodec.INSTANCE);
    }
    
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        messenger = binding.getBinaryMessenger();
        methodChannel = new MethodChannel(messenger, CHANNEL_NAME);
        binding.getPlatformViewRegistry().registerViewFactory(VIEW_TYPE_ID, this);
    }
    
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel.setMethodCallHandler(null);
        methodChannel = null;
        messenger = null;
    }
    
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        methodChannel.setMethodCallHandler(new GlobalMethodCallHandler());
    }
    
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }
    
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }
    
    @Override
    public void onDetachedFromActivity() {
        methodChannel.setMethodCallHandler(null);
        activity = null;
    }
    
    @NonNull
    @Override
    public PlatformView create(Context context, int viewId, @Nullable Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        return new EnhancedNextPlayerPlatformView(context, viewId, creationParams, messenger, activity);
    }
    
    /**
     * Global method call handler for app-level features like PiP
     */
    private class GlobalMethodCallHandler implements MethodChannel.MethodCallHandler {
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            switch (call.method) {
                case "initialize":
                    handleInitialize(call, result);
                    break;
                case "enterPictureInPicture":
                    enterPictureInPicture(result);
                    break;
                case "isPictureInPictureSupported":
                    result.success(isPictureInPictureSupported());
                    break;
                case "play":
                case "pause":
                case "stop":
                case "seekTo":
                case "setPlaybackSpeed":
                case "setVideoZoom":
                case "switchAudioTrack":
                case "switchSubtitleTrack":
                    // These methods should be handled by individual platform views
                    result.error("NO_PLAYER", "No active player instance. Use EnhancedNextPlayerWidget first.", null);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        }
        
        private void handleInitialize(MethodCall call, MethodChannel.Result result) {
            try {
                Map<String, Object> initResult = new HashMap<>();
                initResult.put("success", true);
                initResult.put("message", "Enhanced NextPlayer plugin initialized successfully");
                initResult.put("version", "1.0.0");
                
                // Use List instead of String array for Flutter compatibility
                java.util.List<String> features = new java.util.ArrayList<>();
                features.add("gestures");
                features.add("pip");
                features.add("hardware_acceleration");
                features.add("multi_track");
                features.add("state_persistence");
                initResult.put("features", features);
                
                result.success(initResult);
            } catch (Exception e) {
                Log.e(TAG, "Error initializing Enhanced NextPlayer", e);
                result.error("INIT_ERROR", "Failed to initialize Enhanced NextPlayer", e.getMessage());
            }
        }
        
        private void enterPictureInPicture(MethodChannel.Result result) {
            if (activity == null) {
                result.error("NO_ACTIVITY", "Activity not available", null);
                return;
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder();
                    builder.setAspectRatio(new Rational(16, 9));
                    
                    boolean success = activity.enterPictureInPictureMode(builder.build());
                    result.success(success);
                } catch (Exception e) {
                    Log.e(TAG, "Error entering PiP mode", e);
                    result.error("PIP_ERROR", "Failed to enter Picture-in-Picture mode", e.getMessage());
                }
            } else {
                result.error("PIP_NOT_SUPPORTED", "Picture-in-Picture not supported on this Android version", null);
            }
        }
        
        private boolean isPictureInPictureSupported() {
            if (activity == null) return false;
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PackageManager packageManager = activity.getPackageManager();
                return packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE);
            }
            return false;
        }
    }
}