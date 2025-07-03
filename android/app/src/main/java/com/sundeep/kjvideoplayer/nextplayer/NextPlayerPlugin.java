package com.sundeep.kjvideoplayer.nextplayer;

import android.content.Context;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * Flutter Plugin for NextPlayer
 * ExoPlayer-based video player with professional UI
 */
public class NextPlayerPlugin extends PlatformViewFactory {
    private static final String TAG = "NextPlayerPlugin";
    private final BinaryMessenger messenger;
    
    public NextPlayerPlugin(BinaryMessenger messenger) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
    }
    
    @NonNull
    @Override
    public PlatformView create(Context context, int viewId, @Nullable Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        return new NextPlayerPlatformView(context, viewId, creationParams, messenger);
    }
    
    /**
     * Platform View implementation for NextPlayer
     */
    private static class NextPlayerPlatformView implements PlatformView, MethodChannel.MethodCallHandler {
        private final NextPlayerView nextPlayerView;
        private final MethodChannel methodChannel;
        private final Context context;
        
        NextPlayerPlatformView(Context context, int id, Map<String, Object> creationParams, BinaryMessenger messenger) {
            this.context = context;
            
            // Create NextPlayer view
            nextPlayerView = new NextPlayerView(context);
            
            // Create method channel for communication
            methodChannel = new MethodChannel(messenger, "nextplayer_" + id);
            methodChannel.setMethodCallHandler(this);
            
            // Setup NextPlayer listener
            nextPlayerView.setListener(new NextPlayerView.NextPlayerListener() {
                @Override
                public void onInitialized() {
                    Log.d(TAG, "NextPlayer initialized");
                    invokeMethod("onInitialized", null);
                }
                
                @Override
                public void onPlaying() {
                    Log.d(TAG, "NextPlayer playing");
                    invokeMethod("onPlaying", null);
                }
                
                @Override
                public void onPaused() {
                    Log.d(TAG, "NextPlayer paused");
                    invokeMethod("onPaused", null);
                }
                
                @Override
                public void onStopped() {
                    Log.d(TAG, "NextPlayer stopped");
                    invokeMethod("onStopped", null);
                }
                
                @Override
                public void onTimeChanged(long time) {
                    Map<String, Object> args = new HashMap<>();
                    args.put("time", time);
                    invokeMethod("onTimeChanged", args);
                }
                
                @Override
                public void onDurationChanged(long duration) {
                    Map<String, Object> args = new HashMap<>();
                    args.put("duration", duration);
                    invokeMethod("onDurationChanged", args);
                }
                
                @Override
                public void onError(String error) {
                    Log.e(TAG, "NextPlayer error: " + error);
                    Map<String, Object> args = new HashMap<>();
                    args.put("error", error);
                    invokeMethod("onError", args);
                }
                
                @Override
                public void onVideoSizeChanged(int width, int height) {
                    Map<String, Object> args = new HashMap<>();
                    args.put("width", width);
                    args.put("height", height);
                    invokeMethod("onVideoSizeChanged", args);
                }
                
                @Override
                public void onPlaybackSpeedChanged(float speed) {
                    Map<String, Object> args = new HashMap<>();
                    args.put("speed", speed);
                    invokeMethod("onPlaybackSpeedChanged", args);
                }
            });
            
            // Process creation parameters
            if (creationParams != null) {
                String videoPath = (String) creationParams.get("videoPath");
                Boolean autoPlay = (Boolean) creationParams.get("autoPlay");
                
                if (videoPath != null) {
                    nextPlayerView.setMedia(videoPath);
                    if (autoPlay != null && autoPlay) {
                        nextPlayerView.play();
                    }
                }
            }
        }
        
        @NonNull
        @Override
        public View getView() {
            return nextPlayerView;
        }
        
        @Override
        public void dispose() {
            nextPlayerView.release();
            methodChannel.setMethodCallHandler(null);
        }
        
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            try {
                switch (call.method) {
                    case "setMedia":
                        String path = call.argument("path");
                        if (path != null) {
                            nextPlayerView.setMedia(path);
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Path cannot be null", null);
                        }
                        break;
                        
                    case "play":
                        nextPlayerView.play();
                        result.success(null);
                        break;
                        
                    case "pause":
                        nextPlayerView.pause();
                        result.success(null);
                        break;
                        
                    case "stop":
                        nextPlayerView.stop();
                        result.success(null);
                        break;
                        
                    case "seekTo":
                        Long time = call.argument("time");
                        if (time != null) {
                            nextPlayerView.seekTo(time);
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Time cannot be null", null);
                        }
                        break;
                        
                    case "setPlaybackSpeed":
                        Double speed = call.argument("speed");
                        if (speed != null) {
                            nextPlayerView.setPlaybackSpeed(speed.floatValue());
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Speed cannot be null", null);
                        }
                        break;
                        
                    case "setVolume":
                        Double volume = call.argument("volume");
                        if (volume != null) {
                            nextPlayerView.setVolume(volume.floatValue());
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Volume cannot be null", null);
                        }
                        break;
                        
                    case "setBrightness":
                        Integer brightness = call.argument("brightness");
                        if (brightness != null) {
                            nextPlayerView.setBrightness(brightness);
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Brightness cannot be null", null);
                        }
                        break;
                        
                    case "showVolumeGesture":
                        Boolean showVolume = call.argument("show");
                        if (showVolume != null) {
                            nextPlayerView.showVolumeGesture(showVolume);
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Show cannot be null", null);
                        }
                        break;
                        
                    case "showBrightnessGesture":
                        Boolean showBrightness = call.argument("show");
                        if (showBrightness != null) {
                            nextPlayerView.showBrightnessGesture(showBrightness);
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Show cannot be null", null);
                        }
                        break;
                        
                    case "showInfo":
                        String text = call.argument("text");
                        String subtext = call.argument("subtext");
                        if (text != null) {
                            nextPlayerView.showInfo(text, subtext != null ? subtext : "");
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Text cannot be null", null);
                        }
                        break;
                        
                    case "showTopInfo":
                        String topText = call.argument("text");
                        if (topText != null) {
                            nextPlayerView.showTopInfo(topText);
                            result.success(null);
                        } else {
                            result.error("INVALID_ARGUMENT", "Text cannot be null", null);
                        }
                        break;
                        
                    // Getters
                    case "isPlaying":
                        result.success(nextPlayerView.isPlaying());
                        break;
                        
                    case "getDuration":
                        result.success(nextPlayerView.getDuration());
                        break;
                        
                    case "getCurrentPosition":
                        result.success(nextPlayerView.getCurrentPosition());
                        break;
                        
                    case "getPlaybackSpeed":
                        result.success(nextPlayerView.getPlaybackSpeed());
                        break;
                        
                    case "getVolume":
                        result.success(nextPlayerView.getVolume());
                        break;
                        
                    case "getBrightness":
                        result.success(nextPlayerView.getBrightness());
                        break;
                        
                    case "isInitialized":
                        result.success(nextPlayerView.isInitialized());
                        break;
                        
                    default:
                        result.notImplemented();
                        break;
                }
            } catch (Exception e) {
                Log.e(TAG, "Error handling method call: " + call.method, e);
                result.error("NATIVE_ERROR", e.getMessage(), null);
            }
        }
        
        private void invokeMethod(String method, Object arguments) {
            try {
                methodChannel.invokeMethod(method, arguments);
            } catch (Exception e) {
                Log.e(TAG, "Error invoking method: " + method, e);
            }
        }
    }
}