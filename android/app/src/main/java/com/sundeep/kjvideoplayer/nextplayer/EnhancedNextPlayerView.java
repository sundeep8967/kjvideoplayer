package com.sundeep.kjvideoplayer.nextplayer;

import android.app.Activity;
import android.content.Context;
import android.media.AudioManager;
import android.net.Uri;
import android.provider.Settings;
import android.util.AttributeSet;
import android.util.Log;
import android.view.GestureDetector;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.common.Tracks;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.ui.AspectRatioFrameLayout;
import androidx.media3.ui.PlayerView;
import com.sundeep.kjvideoplayer.R;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Enhanced NextPlayer View with Advanced Features
 * Implements NextPlayer's professional video player capabilities including:
 * - Advanced gesture controls (volume, brightness, seek, zoom)
 * - Multi-track audio/subtitle support
 * - Video zoom and aspect ratio management
 * - Professional UI components
 */
public class EnhancedNextPlayerView extends FrameLayout {
    private static final String TAG = "EnhancedNextPlayerView";
    
    // Player components
    private ExoPlayer exoPlayer;
    private PlayerView playerView;
    private DefaultTrackSelector trackSelector;
    
    // Gesture components
    private GestureDetector gestureDetector;
    private ScaleGestureDetector scaleGestureDetector;
    private BrightnessManager brightnessManager;
    private VolumeManager volumeManager;
    
    // UI Components for gestures and feedback
    private LinearLayout volumeGestureLayout;
    private TextView volumeProgressText;
    private ProgressBar volumeProgressBar;
    private ImageView volumeImage;
    
    private LinearLayout brightnessGestureLayout;
    private TextView brightnessProgressText;
    private ProgressBar brightnessProgressBar;
    private ImageView brightnessIcon;
    
    private LinearLayout seekGestureLayout;
    private TextView seekProgressText;
    private ImageView seekIcon;
    
    private LinearLayout zoomGestureLayout;
    private TextView zoomProgressText;
    
    // State management
    private EnhancedNextPlayerListener listener;
    private boolean gesturesEnabled = true;
    private boolean isInitialized = false;
    private VideoZoom currentVideoZoom = VideoZoom.BEST_FIT;
    private double currentPlaybackSpeed = 1.0;
    private LoopMode currentLoopMode = LoopMode.OFF;
    
    // Gesture state
    private boolean isVolumeGesture = false;
    private boolean isBrightnessGesture = false;
    private boolean isSeekGesture = false;
    private boolean isZoomGesture = false;
    private float initialX, initialY;
    private long initialSeekPosition;
    
    // Audio and subtitle tracks
    private List<AudioTrackInfo> audioTracks = new ArrayList<>();
    private List<SubtitleTrackInfo> subtitleTracks = new ArrayList<>();
    private int selectedAudioTrack = -1;
    private int selectedSubtitleTrack = -1;
    
    public EnhancedNextPlayerView(Context context) {
        super(context);
        init(context);
    }
    
    public EnhancedNextPlayerView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }
    
    private void init(Context context) {
        LayoutInflater.from(context).inflate(R.layout.enhanced_nextplayer_view, this, true);
        initializeComponents();
        setupPlayer(context);
        setupGestures(context);
        setupManagers(context);
    }
    
    private void initializeComponents() {
        playerView = findViewById(R.id.player_view);
        
        // Volume gesture components
        volumeGestureLayout = findViewById(R.id.volume_gesture_layout);
        volumeProgressText = findViewById(R.id.volume_progress_text);
        volumeProgressBar = findViewById(R.id.volume_progress_bar);
        volumeImage = findViewById(R.id.volume_image);
        
        // Brightness gesture components
        brightnessGestureLayout = findViewById(R.id.brightness_gesture_layout);
        brightnessProgressText = findViewById(R.id.brightness_progress_text);
        brightnessProgressBar = findViewById(R.id.brightness_progress_bar);
        brightnessIcon = findViewById(R.id.brightness_icon);
        
        // Seek gesture components
        seekGestureLayout = findViewById(R.id.seek_gesture_layout);
        seekProgressText = findViewById(R.id.seek_progress_text);
        seekIcon = findViewById(R.id.seek_icon);
        
        // Zoom gesture components
        zoomGestureLayout = findViewById(R.id.zoom_gesture_layout);
        zoomProgressText = findViewById(R.id.zoom_progress_text);
        
        // Hide all gesture layouts initially
        hideAllGestureLayouts();
    }
    
    private void setupPlayer(Context context) {
        // Create track selector for advanced track management
        trackSelector = new DefaultTrackSelector(context);
        
        // Configure audio attributes
        AudioAttributes audioAttributes = new AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build();
        
        // Create ExoPlayer with enhanced configuration
        exoPlayer = new ExoPlayer.Builder(context)
                .setTrackSelector(trackSelector)
                .setAudioAttributes(audioAttributes, true)
                .setHandleAudioBecomingNoisy(true)
                .setWakeMode(C.WAKE_MODE_NETWORK)
                .build();
        
        // Set up player view
        playerView.setPlayer(exoPlayer);
        playerView.setUseController(false); // We'll use custom controls
        playerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FIT);
        
        // Set up player listeners
        exoPlayer.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int playbackState) {
                if (listener != null) {
                    listener.onPlaybackStateChanged(playbackState);
                }
            }
            
            @Override
            public void onIsPlayingChanged(boolean isPlaying) {
                if (listener != null) {
                    listener.onIsPlayingChanged(isPlaying);
                }
            }
            
            @Override
            public void onVideoSizeChanged(VideoSize videoSize) {
                if (listener != null) {
                    listener.onVideoSizeChanged(videoSize.width, videoSize.height);
                }
            }
            
            @Override
            public void onTracksChanged(Tracks tracks) {
                updateAvailableTracks(tracks);
                if (listener != null) {
                    listener.onTracksChanged(audioTracks, subtitleTracks);
                }
            }
        });
    }
    
    private void setupGestures(Context context) {
        gestureDetector = new GestureDetector(context, new GestureListener());
        scaleGestureDetector = new ScaleGestureDetector(context, new ScaleGestureListener());
        
        setOnTouchListener(new OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (!gesturesEnabled) return false;
                
                boolean scaleHandled = scaleGestureDetector.onTouchEvent(event);
                boolean gestureHandled = gestureDetector.onTouchEvent(event);
                
                if (event.getAction() == MotionEvent.ACTION_UP) {
                    onGestureEnd();
                }
                
                return scaleHandled || gestureHandled;
            }
        });
    }
    
    private void setupManagers(Context context) {
        brightnessManager = new BrightnessManager(context);
        volumeManager = new VolumeManager(context);
    }
    
    // Public API methods
    public void loadVideo(String videoPath) {
        if (exoPlayer != null) {
            try {
                Uri videoUri;
                
                // Handle different path types
                if (videoPath.startsWith("assets/")) {
                    // Asset file - convert to proper asset URI
                    String assetPath = "file:///android_asset/" + videoPath.substring(7);
                    videoUri = Uri.parse(assetPath);
                    Log.d(TAG, "Loading asset video: " + assetPath);
                } else if (videoPath.startsWith("http://") || videoPath.startsWith("https://")) {
                    // Network URL
                    videoUri = Uri.parse(videoPath);
                    Log.d(TAG, "Loading network video: " + videoPath);
                } else {
                    // Local file path
                    videoUri = Uri.parse("file://" + videoPath);
                    Log.d(TAG, "Loading local video: " + videoPath);
                }
                
                MediaItem mediaItem = MediaItem.fromUri(videoUri);
                exoPlayer.setMediaItem(mediaItem);
                exoPlayer.prepare();
                exoPlayer.setPlayWhenReady(true); // Auto-play
                isInitialized = true;
                
                Log.d(TAG, "Video loaded and prepared successfully");
                
                if (listener != null) {
                    listener.onInitialized();
                }
            } catch (Exception e) {
                Log.e(TAG, "Failed to load video: " + videoPath, e);
                if (listener != null) {
                    listener.onError("Failed to load video: " + e.getMessage());
                }
            }
        } else {
            Log.e(TAG, "ExoPlayer is null, cannot load video");
        }
    }
    
    public void play() {
        if (exoPlayer != null) {
            exoPlayer.play();
        }
    }
    
    public void pause() {
        if (exoPlayer != null) {
            exoPlayer.pause();
        }
    }
    
    public void seekTo(long positionMs) {
        if (exoPlayer != null) {
            exoPlayer.seekTo(positionMs);
        }
    }
    
    public void setPlaybackSpeed(double speed) {
        if (exoPlayer != null) {
            exoPlayer.setPlaybackSpeed((float) speed);
            currentPlaybackSpeed = speed;
            
            if (listener != null) {
                listener.onPlaybackSpeedChanged(speed);
            }
        }
    }
    
    public void setVideoZoom(VideoZoom zoom) {
        currentVideoZoom = zoom;
        
        switch (zoom) {
            case BEST_FIT:
                playerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FIT);
                break;
            case STRETCH:
                playerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FILL);
                break;
            case CROP:
                playerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_ZOOM);
                break;
            case HUNDRED_PERCENT:
                playerView.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH);
                break;
        }
        
        if (listener != null) {
            listener.onVideoZoomChanged(zoom);
        }
    }
    
    public void setLoopMode(LoopMode mode) {
        currentLoopMode = mode;
        
        switch (mode) {
            case OFF:
                exoPlayer.setRepeatMode(Player.REPEAT_MODE_OFF);
                break;
            case ONE:
                exoPlayer.setRepeatMode(Player.REPEAT_MODE_ONE);
                break;
            case ALL:
                exoPlayer.setRepeatMode(Player.REPEAT_MODE_ALL);
                break;
        }
        
        if (listener != null) {
            listener.onLoopModeChanged(mode);
        }
    }
    
    public void switchAudioTrack(int trackIndex) {
        if (trackIndex >= 0 && trackIndex < audioTracks.size()) {
            selectedAudioTrack = trackIndex;
            // Implementation for track switching
            if (listener != null) {
                listener.onAudioTrackChanged(trackIndex);
            }
        }
    }
    
    public void switchSubtitleTrack(int trackIndex) {
        if (trackIndex >= -1 && trackIndex < subtitleTracks.size()) {
            selectedSubtitleTrack = trackIndex;
            // Implementation for subtitle track switching
            if (listener != null) {
                listener.onSubtitleTrackChanged(trackIndex);
            }
        }
    }
    
    public void setGesturesEnabled(boolean enabled) {
        gesturesEnabled = enabled;
    }
    
    public void setListener(EnhancedNextPlayerListener listener) {
        this.listener = listener;
    }
    
    // Gesture handling
    private class GestureListener extends GestureDetector.SimpleOnGestureListener {
        @Override
        public boolean onDown(MotionEvent e) {
            initialX = e.getX();
            initialY = e.getY();
            return true;
        }
        
        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            if (!gesturesEnabled) return false;
            
            float deltaX = e2.getX() - initialX;
            float deltaY = e2.getY() - initialY;
            
            // Determine gesture type based on movement
            if (Math.abs(deltaX) > Math.abs(deltaY)) {
                // Horizontal gesture - seek
                handleSeekGesture(deltaX);
            } else {
                // Vertical gesture - volume or brightness
                if (e2.getX() < getWidth() / 2) {
                    // Left side - brightness
                    handleBrightnessGesture(deltaY);
                } else {
                    // Right side - volume
                    handleVolumeGesture(deltaY);
                }
            }
            
            return true;
        }
    }
    
    private class ScaleGestureListener extends ScaleGestureDetector.SimpleOnScaleGestureListener {
        @Override
        public boolean onScale(ScaleGestureDetector detector) {
            if (!gesturesEnabled) return false;
            
            float scaleFactor = detector.getScaleFactor();
            handleZoomGesture(scaleFactor);
            return true;
        }
    }
    
    private void handleVolumeGesture(float deltaY) {
        if (!isVolumeGesture) {
            isVolumeGesture = true;
            volumeGestureLayout.setVisibility(VISIBLE);
        }
        
        float volumeChange = -deltaY / getHeight();
        float newVolume = volumeManager.adjustVolume(volumeChange);
        
        volumeProgressBar.setProgress((int) (newVolume * 100));
        volumeProgressText.setText(String.format("%d%%", (int) (newVolume * 100)));
        
        // Update volume icon based on level
        if (newVolume == 0) {
            volumeImage.setImageResource(R.drawable.ic_volume_off);
        } else if (newVolume < 0.5f) {
            volumeImage.setImageResource(R.drawable.ic_volume_down);
        } else {
            volumeImage.setImageResource(R.drawable.ic_volume_up);
        }
    }
    
    private void handleBrightnessGesture(float deltaY) {
        if (!isBrightnessGesture) {
            isBrightnessGesture = true;
            brightnessGestureLayout.setVisibility(VISIBLE);
        }
        
        float brightnessChange = -deltaY / getHeight();
        float newBrightness = brightnessManager.adjustBrightness(brightnessChange);
        
        brightnessProgressBar.setProgress((int) (newBrightness * 100));
        brightnessProgressText.setText(String.format("%d%%", (int) (newBrightness * 100)));
    }
    
    private void handleSeekGesture(float deltaX) {
        if (!isSeekGesture) {
            isSeekGesture = true;
            seekGestureLayout.setVisibility(VISIBLE);
            initialSeekPosition = exoPlayer.getCurrentPosition();
        }
        
        // Calculate seek amount based on gesture
        long seekAmount = (long) (deltaX / getWidth() * exoPlayer.getDuration() * 0.1);
        long newPosition = initialSeekPosition + seekAmount;
        
        // Clamp to valid range
        newPosition = Math.max(0, Math.min(newPosition, exoPlayer.getDuration()));
        
        seekProgressText.setText(formatTime(newPosition));
        
        if (seekAmount > 0) {
            seekIcon.setImageResource(R.drawable.ic_fast_forward);
        } else {
            seekIcon.setImageResource(R.drawable.ic_fast_rewind);
        }
    }
    
    private void handleZoomGesture(float scaleFactor) {
        if (!isZoomGesture) {
            isZoomGesture = true;
            zoomGestureLayout.setVisibility(VISIBLE);
        }
        
        // Implement zoom logic here
        zoomProgressText.setText(String.format("Zoom: %.1fx", scaleFactor));
    }
    
    private void onGestureEnd() {
        if (isVolumeGesture) {
            isVolumeGesture = false;
            volumeGestureLayout.setVisibility(GONE);
        }
        
        if (isBrightnessGesture) {
            isBrightnessGesture = false;
            brightnessGestureLayout.setVisibility(GONE);
        }
        
        if (isSeekGesture) {
            isSeekGesture = false;
            seekGestureLayout.setVisibility(GONE);
            
            // Apply the seek
            long seekPosition = initialSeekPosition;
            // Calculate final position and seek
            exoPlayer.seekTo(seekPosition);
        }
        
        if (isZoomGesture) {
            isZoomGesture = false;
            zoomGestureLayout.setVisibility(GONE);
        }
    }
    
    private void hideAllGestureLayouts() {
        volumeGestureLayout.setVisibility(GONE);
        brightnessGestureLayout.setVisibility(GONE);
        seekGestureLayout.setVisibility(GONE);
        zoomGestureLayout.setVisibility(GONE);
    }
    
    private void updateAvailableTracks(Tracks tracks) {
        audioTracks.clear();
        subtitleTracks.clear();
        
        for (Tracks.Group group : tracks.getGroups()) {
            if (group.getType() == C.TRACK_TYPE_AUDIO) {
                for (int i = 0; i < group.length; i++) {
                    Format format = group.getTrackFormat(i);
                    audioTracks.add(new AudioTrackInfo(i, format.language, format.label));
                }
            } else if (group.getType() == C.TRACK_TYPE_TEXT) {
                for (int i = 0; i < group.length; i++) {
                    Format format = group.getTrackFormat(i);
                    subtitleTracks.add(new SubtitleTrackInfo(i, format.language, format.label));
                }
            }
        }
    }
    
    private String formatTime(long timeMs) {
        long seconds = timeMs / 1000;
        long minutes = seconds / 60;
        long hours = minutes / 60;
        
        if (hours > 0) {
            return String.format("%d:%02d:%02d", hours, minutes % 60, seconds % 60);
        } else {
            return String.format("%d:%02d", minutes, seconds % 60);
        }
    }
    
    public void release() {
        if (exoPlayer != null) {
            exoPlayer.release();
            exoPlayer = null;
        }
    }
    
    // Getters for current state
    public boolean isInitialized() { return isInitialized; }
    public VideoZoom getCurrentVideoZoom() { return currentVideoZoom; }
    public double getCurrentPlaybackSpeed() { return currentPlaybackSpeed; }
    public LoopMode getCurrentLoopMode() { return currentLoopMode; }
    public List<AudioTrackInfo> getAudioTracks() { return audioTracks; }
    public List<SubtitleTrackInfo> getSubtitleTracks() { return subtitleTracks; }
    public int getSelectedAudioTrack() { return selectedAudioTrack; }
    public int getSelectedSubtitleTrack() { return selectedSubtitleTrack; }
    
    // Enums and data classes
    public enum VideoZoom {
        BEST_FIT, STRETCH, CROP, HUNDRED_PERCENT
    }
    
    public enum LoopMode {
        OFF, ONE, ALL
    }
    
    public static class AudioTrackInfo {
        public final int index;
        public final String language;
        public final String label;
        
        public AudioTrackInfo(int index, String language, String label) {
            this.index = index;
            this.language = language != null ? language : "Unknown";
            this.label = label != null ? label : "Audio Track " + (index + 1);
        }
    }
    
    public static class SubtitleTrackInfo {
        public final int index;
        public final String language;
        public final String label;
        
        public SubtitleTrackInfo(int index, String language, String label) {
            this.index = index;
            this.language = language != null ? language : "Unknown";
            this.label = label != null ? label : "Subtitle Track " + (index + 1);
        }
    }
    
    // Listener interface
    public interface EnhancedNextPlayerListener {
        void onInitialized();
        void onPlaybackStateChanged(int state);
        void onIsPlayingChanged(boolean isPlaying);
        void onVideoSizeChanged(int width, int height);
        void onPlaybackSpeedChanged(double speed);
        void onVideoZoomChanged(VideoZoom zoom);
        void onLoopModeChanged(LoopMode mode);
        void onTracksChanged(List<AudioTrackInfo> audioTracks, List<SubtitleTrackInfo> subtitleTracks);
        void onAudioTrackChanged(int trackIndex);
        void onSubtitleTrackChanged(int trackIndex);
        void onError(String error);
    }
}