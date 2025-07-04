package com.sundeep.kjvideoplayer.nextplayer;

import android.app.Activity;
import android.content.Context;
import android.view.View;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

/**
 * Platform View implementation for Enhanced NextPlayer
 * Bridges Android native player with Flutter
 */
public class EnhancedNextPlayerPlatformView implements PlatformView, MethodChannel.MethodCallHandler {
    private final EnhancedNextPlayerView playerView;
    private final MethodChannel methodChannel;
    private final Context context;
    private final Activity activity;
    
    public EnhancedNextPlayerPlatformView(Context context, int id, Map<String, Object> creationParams, 
                                        BinaryMessenger messenger, Activity activity) {
        this.context = context;
        this.activity = activity;
        
        // Create method channel for communication with Flutter
        methodChannel = new MethodChannel(messenger, "enhanced_nextplayer_" + id);
        methodChannel.setMethodCallHandler(this);
        
        // Create the enhanced player view
        playerView = new EnhancedNextPlayerView(context);
        
        // Set up listener to send events to Flutter
        playerView.setListener(new EnhancedNextPlayerView.EnhancedNextPlayerListener() {
            @Override
            public void onInitialized() {
                methodChannel.invokeMethod("onInitialized", null);
            }
            
            @Override
            public void onPlaybackStateChanged(int state) {
                Map<String, Object> args = new HashMap<>();
                args.put("state", state);
                methodChannel.invokeMethod("onPlaybackStateChanged", args);
            }
            
            @Override
            public void onIsPlayingChanged(boolean isPlaying) {
                Map<String, Object> args = new HashMap<>();
                args.put("isPlaying", isPlaying);
                methodChannel.invokeMethod("onIsPlayingChanged", args);
            }
            
            @Override
            public void onVideoSizeChanged(int width, int height) {
                Map<String, Object> args = new HashMap<>();
                args.put("width", width);
                args.put("height", height);
                methodChannel.invokeMethod("onVideoSizeChanged", args);
            }
            
            @Override
            public void onPlaybackSpeedChanged(double speed) {
                Map<String, Object> args = new HashMap<>();
                args.put("speed", speed);
                methodChannel.invokeMethod("onPlaybackSpeedChanged", args);
            }
            
            @Override
            public void onVideoZoomChanged(EnhancedNextPlayerView.VideoZoom zoom) {
                Map<String, Object> args = new HashMap<>();
                args.put("zoom", zoom.name());
                methodChannel.invokeMethod("onVideoZoomChanged", args);
            }
            
            @Override
            public void onLoopModeChanged(EnhancedNextPlayerView.LoopMode mode) {
                Map<String, Object> args = new HashMap<>();
                args.put("mode", mode.name());
                methodChannel.invokeMethod("onLoopModeChanged", args);
            }
            
            @Override
            public void onTracksChanged(List<EnhancedNextPlayerView.AudioTrackInfo> audioTracks, 
                                      List<EnhancedNextPlayerView.SubtitleTrackInfo> subtitleTracks) {
                Map<String, Object> args = new HashMap<>();
                args.put("audioTracks", convertAudioTracks(audioTracks));
                args.put("subtitleTracks", convertSubtitleTracks(subtitleTracks));
                methodChannel.invokeMethod("onTracksChanged", args);
            }
            
            @Override
            public void onAudioTrackChanged(int trackIndex) {
                Map<String, Object> args = new HashMap<>();
                args.put("trackIndex", trackIndex);
                methodChannel.invokeMethod("onAudioTrackChanged", args);
            }
            
            @Override
            public void onSubtitleTrackChanged(int trackIndex) {
                Map<String, Object> args = new HashMap<>();
                args.put("trackIndex", trackIndex);
                methodChannel.invokeMethod("onSubtitleTrackChanged", args);
            }
            
            @Override
            public void onError(String error) {
                Map<String, Object> args = new HashMap<>();
                args.put("error", error);
                methodChannel.invokeMethod("onError", args);
            }
        });
        
        // Initialize with creation parameters
        if (creationParams != null) {
            String videoPath = (String) creationParams.get("videoPath");
            Boolean autoPlay = (Boolean) creationParams.get("autoPlay");
            Boolean enableGestures = (Boolean) creationParams.get("enableGestures");
            
            if (videoPath != null) {
                playerView.loadVideo(videoPath);
            }
            
            if (enableGestures != null) {
                playerView.setGesturesEnabled(enableGestures);
            }
            
            if (autoPlay != null && autoPlay) {
                playerView.play();
            }
        }
    }
    
    @Override
    public View getView() {
        return playerView;
    }
    
    @Override
    public void dispose() {
        playerView.release();
        methodChannel.setMethodCallHandler(null);
    }
    
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "initialize":
                // Initialize the player
                Map<String, Object> initResult = new HashMap<>();
                initResult.put("success", true);
                initResult.put("message", "Enhanced NextPlayer initialized successfully");
                result.success(initResult);
                break;
                
            case "loadVideo":
                String videoPath = call.argument("videoPath");
                if (videoPath != null) {
                    playerView.loadVideo(videoPath);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGUMENT", "Video path is required", null);
                }
                break;
                
            case "play":
                playerView.play();
                result.success(null);
                break;
                
            case "pause":
                playerView.pause();
                result.success(null);
                break;
                
            case "seekTo":
                Long position = call.argument("position");
                if (position != null) {
                    playerView.seekTo(position);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGUMENT", "Position is required", null);
                }
                break;
                
            case "setPlaybackSpeed":
                Double speed = call.argument("speed");
                if (speed != null) {
                    playerView.setPlaybackSpeed(speed);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGUMENT", "Speed is required", null);
                }
                break;
                
            case "setVideoZoom":
                String zoomStr = call.argument("zoom");
                if (zoomStr != null) {
                    try {
                        EnhancedNextPlayerView.VideoZoom zoom = EnhancedNextPlayerView.VideoZoom.valueOf(zoomStr);
                        playerView.setVideoZoom(zoom);
                        result.success(null);
                    } catch (IllegalArgumentException e) {
                        result.error("INVALID_ARGUMENT", "Invalid zoom mode", null);
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Zoom mode is required", null);
                }
                break;
                
            case "setLoopMode":
                String modeStr = call.argument("mode");
                if (modeStr != null) {
                    try {
                        EnhancedNextPlayerView.LoopMode mode = EnhancedNextPlayerView.LoopMode.valueOf(modeStr);
                        playerView.setLoopMode(mode);
                        result.success(null);
                    } catch (IllegalArgumentException e) {
                        result.error("INVALID_ARGUMENT", "Invalid loop mode", null);
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Loop mode is required", null);
                }
                break;
                
            case "switchAudioTrack":
                Integer audioTrackIndex = call.argument("trackIndex");
                if (audioTrackIndex != null) {
                    playerView.switchAudioTrack(audioTrackIndex);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGUMENT", "Track index is required", null);
                }
                break;
                
            case "switchSubtitleTrack":
                Integer subtitleTrackIndex = call.argument("trackIndex");
                if (subtitleTrackIndex != null) {
                    playerView.switchSubtitleTrack(subtitleTrackIndex);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGUMENT", "Track index is required", null);
                }
                break;
                
            case "setGesturesEnabled":
                Boolean enabled = call.argument("enabled");
                if (enabled != null) {
                    playerView.setGesturesEnabled(enabled);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGUMENT", "Enabled flag is required", null);
                }
                break;
                
            case "getCurrentState":
                Map<String, Object> state = new HashMap<>();
                state.put("isInitialized", playerView.isInitialized());
                state.put("videoZoom", playerView.getCurrentVideoZoom().name());
                state.put("playbackSpeed", playerView.getCurrentPlaybackSpeed());
                state.put("loopMode", playerView.getCurrentLoopMode().name());
                state.put("selectedAudioTrack", playerView.getSelectedAudioTrack());
                state.put("selectedSubtitleTrack", playerView.getSelectedSubtitleTrack());
                result.success(state);
                break;
                
            default:
                result.notImplemented();
                break;
        }
    }
    
    private List<Map<String, Object>> convertAudioTracks(List<EnhancedNextPlayerView.AudioTrackInfo> tracks) {
        return tracks.stream().map(track -> {
            Map<String, Object> map = new HashMap<>();
            map.put("index", track.index);
            map.put("language", track.language);
            map.put("label", track.label);
            return map;
        }).collect(java.util.stream.Collectors.toList());
    }
    
    private List<Map<String, Object>> convertSubtitleTracks(List<EnhancedNextPlayerView.SubtitleTrackInfo> tracks) {
        return tracks.stream().map(track -> {
            Map<String, Object> map = new HashMap<>();
            map.put("index", track.index);
            map.put("language", track.language);
            map.put("label", track.label);
            return map;
        }).collect(java.util.stream.Collectors.toList());
    }
}