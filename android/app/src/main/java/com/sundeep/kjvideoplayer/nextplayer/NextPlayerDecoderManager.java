package com.sundeep.kjvideoplayer.nextplayer;

import android.content.Context;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import android.os.Build;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * NextPlayer Decoder Manager
 * Manages hardware and software video/audio decoders
 */
public class NextPlayerDecoderManager {
    private static final String TAG = "NextPlayerDecoderManager";
    
    private final Context context;
    private final MethodChannel methodChannel;
    
    // Decoder settings
    private String decoderPriority = "preferDevice"; // "preferDevice", "preferSoftware", "deviceOnly", "softwareOnly"
    private boolean useHardwareAcceleration = true;
    private boolean allowFallback = true;
    
    // Supported formats
    private List<String> supportedVideoFormats = new ArrayList<>();
    private List<String> supportedAudioFormats = new ArrayList<>();
    private List<String> supportedSubtitleFormats = new ArrayList<>();
    
    public NextPlayerDecoderManager(Context context, MethodChannel methodChannel) {
        this.context = context;
        this.methodChannel = methodChannel;
        initializeSupportedFormats();
    }
    
    private void initializeSupportedFormats() {
        // Initialize supported video formats
        supportedVideoFormats.add("video/avc"); // H.264
        supportedVideoFormats.add("video/hevc"); // H.265
        supportedVideoFormats.add("video/mp4v-es"); // MPEG-4
        supportedVideoFormats.add("video/3gpp"); // 3GPP
        supportedVideoFormats.add("video/x-vnd.on2.vp8"); // VP8
        supportedVideoFormats.add("video/x-vnd.on2.vp9"); // VP9
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            supportedVideoFormats.add("video/av01"); // AV1
        }
        
        // Initialize supported audio formats
        supportedAudioFormats.add("audio/mp4a-latm"); // AAC
        supportedAudioFormats.add("audio/mpeg"); // MP3
        supportedAudioFormats.add("audio/vorbis"); // Vorbis
        supportedAudioFormats.add("audio/opus"); // Opus
        supportedAudioFormats.add("audio/flac"); // FLAC
        supportedAudioFormats.add("audio/ac3"); // AC-3
        supportedAudioFormats.add("audio/eac3"); // E-AC-3
        
        // Initialize supported subtitle formats
        supportedSubtitleFormats.add("text/vtt"); // WebVTT
        supportedSubtitleFormats.add("application/x-subrip"); // SRT
        supportedSubtitleFormats.add("text/x-ssa"); // SSA/ASS
        supportedSubtitleFormats.add("application/ttml+xml"); // TTML
    }
    
    public Map<String, Object> initialize() {
        Map<String, Object> result = new HashMap<>();
        
        // Scan available decoders
        scanAvailableDecoders();
        
        result.put("videoFormats", supportedVideoFormats);
        result.put("audioFormats", supportedAudioFormats);
        result.put("subtitleFormats", supportedSubtitleFormats);
        result.put("hardwareDecodersAvailable", hasHardwareDecoders());
        
        return result;
    }
    
    private void scanAvailableDecoders() {
        MediaCodecList codecList = new MediaCodecList(MediaCodecList.ALL_CODECS);
        MediaCodecInfo[] codecInfos = codecList.getCodecInfos();
        
        for (MediaCodecInfo codecInfo : codecInfos) {
            if (!codecInfo.isEncoder()) {
                String[] supportedTypes = codecInfo.getSupportedTypes();
                for (String type : supportedTypes) {
                    if (type.startsWith("video/") && !supportedVideoFormats.contains(type)) {
                        supportedVideoFormats.add(type);
                    } else if (type.startsWith("audio/") && !supportedAudioFormats.contains(type)) {
                        supportedAudioFormats.add(type);
                    }
                }
            }
        }
    }
    
    private boolean hasHardwareDecoders() {
        MediaCodecList codecList = new MediaCodecList(MediaCodecList.ALL_CODECS);
        MediaCodecInfo[] codecInfos = codecList.getCodecInfos();
        
        for (MediaCodecInfo codecInfo : codecInfos) {
            if (!codecInfo.isEncoder()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    if (codecInfo.isHardwareAccelerated()) {
                        return true;
                    }
                } else {
                    // For older versions, check if it's not a software decoder
                    if (!codecInfo.getName().toLowerCase().contains("sw")) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    public void setDecoderPriority(String priority) {
        this.decoderPriority = priority;
        
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("type", "priorityChanged");
        arguments.put("message", "Decoder priority changed to " + priority);
        arguments.put("data", Map.of("priority", priority));
        
        methodChannel.invokeMethod("onDecoderChanged", arguments);
    }
    
    public void setHardwareAcceleration(boolean enabled) {
        this.useHardwareAcceleration = enabled;
        
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("type", "hardwareAccelerationChanged");
        arguments.put("message", "Hardware acceleration " + (enabled ? "enabled" : "disabled"));
        arguments.put("data", Map.of("enabled", enabled));
        
        methodChannel.invokeMethod("onDecoderChanged", arguments);
    }
    
    public void setAllowFallback(boolean allow) {
        this.allowFallback = allow;
    }
    
    public Map<String, Object> getDecoderInfo(String videoPath) {
        Map<String, Object> decoderInfo = new HashMap<>();
        
        // This would typically involve analyzing the video file
        // For now, return default decoder info based on current settings
        
        String videoDecoder = getRecommendedVideoDecoder();
        String audioDecoder = getRecommendedAudioDecoder();
        
        decoderInfo.put("videoDecoder", videoDecoder);
        decoderInfo.put("audioDecoder", audioDecoder);
        decoderInfo.put("hardwareAccelerated", useHardwareAcceleration && hasHardwareDecoders());
        decoderInfo.put("videoFormat", "video/avc"); // Default, would be detected from file
        decoderInfo.put("audioFormat", "audio/mp4a-latm"); // Default, would be detected from file
        
        Map<String, Object> capabilities = new HashMap<>();
        capabilities.put("maxWidth", 1920);
        capabilities.put("maxHeight", 1080);
        capabilities.put("maxFrameRate", 60);
        decoderInfo.put("capabilities", capabilities);
        
        return decoderInfo;
    }
    
    private String getRecommendedVideoDecoder() {
        switch (decoderPriority) {
            case "preferDevice":
                return useHardwareAcceleration && hasHardwareDecoders() ? "hardware" : "software";
            case "preferSoftware":
                return "software";
            case "deviceOnly":
                return "hardware";
            case "softwareOnly":
                return "software";
            default:
                return "auto";
        }
    }
    
    private String getRecommendedAudioDecoder() {
        // Audio decoders are typically software-based
        return "software";
    }
    
    public String getRecommendedDecoder(String videoPath) {
        // Analyze video file and return recommended decoder
        // This would involve reading the video file metadata
        return getRecommendedVideoDecoder();
    }
    
    public boolean isVideoFormatSupported(String format) {
        return supportedVideoFormats.contains(format.toLowerCase());
    }
    
    public boolean isAudioFormatSupported(String format) {
        return supportedAudioFormats.contains(format.toLowerCase());
    }
    
    public boolean isSubtitleFormatSupported(String format) {
        return supportedSubtitleFormats.contains(format.toLowerCase());
    }
    
    public List<MediaCodecInfo> getAvailableDecoders(String mimeType) {
        List<MediaCodecInfo> decoders = new ArrayList<>();
        MediaCodecList codecList = new MediaCodecList(MediaCodecList.ALL_CODECS);
        MediaCodecInfo[] codecInfos = codecList.getCodecInfos();
        
        for (MediaCodecInfo codecInfo : codecInfos) {
            if (!codecInfo.isEncoder()) {
                String[] supportedTypes = codecInfo.getSupportedTypes();
                for (String type : supportedTypes) {
                    if (type.equalsIgnoreCase(mimeType)) {
                        decoders.add(codecInfo);
                        break;
                    }
                }
            }
        }
        
        return decoders;
    }
    
    public MediaCodecInfo getBestDecoder(String mimeType) {
        List<MediaCodecInfo> decoders = getAvailableDecoders(mimeType);
        
        if (decoders.isEmpty()) {
            return null;
        }
        
        // Sort decoders based on priority
        switch (decoderPriority) {
            case "preferDevice":
            case "deviceOnly":
                // Prefer hardware decoders
                for (MediaCodecInfo decoder : decoders) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        if (decoder.isHardwareAccelerated()) {
                            return decoder;
                        }
                    } else {
                        if (!decoder.getName().toLowerCase().contains("sw")) {
                            return decoder;
                        }
                    }
                }
                if (decoderPriority.equals("deviceOnly")) {
                    return null; // No hardware decoder available
                }
                break;
                
            case "preferSoftware":
            case "softwareOnly":
                // Prefer software decoders
                for (MediaCodecInfo decoder : decoders) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        if (!decoder.isHardwareAccelerated()) {
                            return decoder;
                        }
                    } else {
                        if (decoder.getName().toLowerCase().contains("sw")) {
                            return decoder;
                        }
                    }
                }
                if (decoderPriority.equals("softwareOnly")) {
                    return null; // No software decoder available
                }
                break;
        }
        
        // Return first available decoder as fallback
        return allowFallback ? decoders.get(0) : null;
    }
}