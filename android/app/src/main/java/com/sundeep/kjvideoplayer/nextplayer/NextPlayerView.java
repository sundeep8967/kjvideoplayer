package com.sundeep.kjvideoplayer.nextplayer;

import android.content.Context;
import android.net.Uri;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.AspectRatioFrameLayout;
import androidx.media3.ui.PlayerView;

/**
 * NextPlayer-inspired Video Player View for Flutter
 * Based on ExoPlayer (Media3) for maximum stability and performance
 */
public class NextPlayerView extends FrameLayout {
    private static final String TAG = "NextPlayerView";
    
    private ExoPlayer exoPlayer;
    private PlayerView playerView;
    
    // UI Components (based on NextPlayer layout)
    private LinearLayout topInfoLayout;
    private TextView topInfoText;
    private ImageView fastSpeedImage;
    private LinearLayout infoLayout;
    private TextView infoText;
    private TextView infoSubtext;
    private LinearLayout volumeGestureLayout;
    private TextView volumeProgressText;
    private ProgressBar volumeProgressBar;
    private ImageView volumeImage;
    private LinearLayout brightnessGestureLayout;
    private TextView brightnessProgressText;
    private ProgressBar brightnessProgressBar;
    private ImageView brightnessIcon;
    
    private NextPlayerListener listener;
    
    // Player state
    private boolean isInitialized = false;
    private boolean isPlaying = false;
    private long duration = 0;
    private long currentPosition = 0;
    private float playbackSpeed = 1.0f;
    private int volume = 100;
    private int brightness = 50;
    
    public interface NextPlayerListener {
        void onInitialized();
        void onPlaying();
        void onPaused();
        void onStopped();
        void onTimeChanged(long time);
        void onDurationChanged(long duration);
        void onError(String error);
        void onVideoSizeChanged(int width, int height);
        void onPlaybackSpeedChanged(float speed);
    }
    
    public NextPlayerView(Context context) {
        super(context);
        init(context);
    }
    
    public NextPlayerView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }
    
    public NextPlayerView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }
    
    private void init(Context context) {
        try {
            // Inflate the layout (similar to NextPlayer's activity_player.xml)
            setupLayout(context);
            
            // Initialize ExoPlayer
            initializeExoPlayer(context);
            
            Log.d(TAG, "NextPlayer initialized successfully");
            
        } catch (Exception e) {
            Log.e(TAG, "Error initializing NextPlayer", e);
            if (listener != null) {
                listener.onError("Failed to initialize NextPlayer: " + e.getMessage());
            }
        }
    }
    
    private void setupLayout(Context context) {
        // Create main PlayerView
        playerView = new PlayerView(context);
        playerView.setLayoutParams(new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));
        playerView.setBackgroundColor(0xFF000000); // Black background
        playerView.setUseController(true);
        playerView.setControllerAutoShow(true);
        addView(playerView);
        
        // Create top info layout
        topInfoLayout = new LinearLayout(context);
        topInfoLayout.setOrientation(LinearLayout.HORIZONTAL);
        topInfoLayout.setGravity(android.view.Gravity.CENTER);
        topInfoLayout.setVisibility(View.GONE);
        FrameLayout.LayoutParams topParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        topParams.gravity = android.view.Gravity.CENTER_HORIZONTAL | android.view.Gravity.TOP;
        topParams.topMargin = dpToPx(16);
        topInfoLayout.setLayoutParams(topParams);
        
        // Add top info text
        topInfoText = new TextView(context);
        topInfoText.setTextColor(0xFFFFFFFF);
        topInfoText.setTextSize(16);
        topInfoLayout.addView(topInfoText);
        addView(topInfoLayout);
        
        // Create center info layout
        infoLayout = new LinearLayout(context);
        infoLayout.setOrientation(LinearLayout.VERTICAL);
        infoLayout.setGravity(android.view.Gravity.CENTER_HORIZONTAL);
        infoLayout.setVisibility(View.GONE);
        FrameLayout.LayoutParams centerParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        centerParams.gravity = android.view.Gravity.CENTER;
        infoLayout.setLayoutParams(centerParams);
        
        infoText = new TextView(context);
        infoText.setTextColor(0xFFFFFFFF);
        infoText.setTextSize(24);
        infoText.setTypeface(null, android.graphics.Typeface.BOLD);
        infoLayout.addView(infoText);
        
        infoSubtext = new TextView(context);
        infoSubtext.setTextColor(0xFFFFFFFF);
        infoSubtext.setTextSize(18);
        infoLayout.addView(infoSubtext);
        addView(infoLayout);
        
        // Create volume gesture layout
        setupVolumeGestureLayout(context);
        
        // Create brightness gesture layout
        setupBrightnessGestureLayout(context);
    }
    
    private void setupVolumeGestureLayout(Context context) {
        volumeGestureLayout = new LinearLayout(context);
        volumeGestureLayout.setOrientation(LinearLayout.VERTICAL);
        volumeGestureLayout.setGravity(android.view.Gravity.CENTER_HORIZONTAL);
        volumeGestureLayout.setVisibility(View.GONE);
        FrameLayout.LayoutParams volumeParams = new FrameLayout.LayoutParams(
            dpToPx(54),
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        volumeParams.gravity = android.view.Gravity.CENTER_VERTICAL | android.view.Gravity.START;
        volumeParams.leftMargin = dpToPx(16);
        volumeGestureLayout.setLayoutParams(volumeParams);
        
        volumeProgressText = new TextView(context);
        volumeProgressText.setTextColor(0xFFFFFFFF);
        volumeProgressText.setGravity(android.view.Gravity.CENTER);
        volumeGestureLayout.addView(volumeProgressText);
        
        volumeProgressBar = new ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal);
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(dpToPx(6), dpToPx(125));
        volumeProgressBar.setLayoutParams(progressParams);
        volumeGestureLayout.addView(volumeProgressBar);
        
        addView(volumeGestureLayout);
    }
    
    private void setupBrightnessGestureLayout(Context context) {
        brightnessGestureLayout = new LinearLayout(context);
        brightnessGestureLayout.setOrientation(LinearLayout.VERTICAL);
        brightnessGestureLayout.setGravity(android.view.Gravity.CENTER_HORIZONTAL);
        brightnessGestureLayout.setVisibility(View.GONE);
        FrameLayout.LayoutParams brightnessParams = new FrameLayout.LayoutParams(
            dpToPx(54),
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        brightnessParams.gravity = android.view.Gravity.CENTER_VERTICAL | android.view.Gravity.END;
        brightnessParams.rightMargin = dpToPx(16);
        brightnessGestureLayout.setLayoutParams(brightnessParams);
        
        brightnessProgressText = new TextView(context);
        brightnessProgressText.setTextColor(0xFFFFFFFF);
        brightnessProgressText.setGravity(android.view.Gravity.CENTER);
        brightnessGestureLayout.addView(brightnessProgressText);
        
        brightnessProgressBar = new ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal);
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(dpToPx(6), dpToPx(125));
        brightnessProgressBar.setLayoutParams(progressParams);
        brightnessGestureLayout.addView(brightnessProgressBar);
        
        addView(brightnessGestureLayout);
    }
    
    private void initializeExoPlayer(Context context) {
        // Create ExoPlayer instance
        exoPlayer = new ExoPlayer.Builder(context).build();
        
        // Attach player to PlayerView
        playerView.setPlayer(exoPlayer);
        
        // Setup player listeners
        exoPlayer.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int playbackState) {
                switch (playbackState) {
                    case Player.STATE_READY:
                        if (!isInitialized) {
                            isInitialized = true;
                            duration = exoPlayer.getDuration();
                            if (listener != null) {
                                listener.onInitialized();
                                listener.onDurationChanged(duration);
                            }
                        }
                        break;
                    case Player.STATE_ENDED:
                        if (listener != null) {
                            listener.onStopped();
                        }
                        break;
                }
            }
            
            @Override
            public void onIsPlayingChanged(boolean playing) {
                isPlaying = playing;
                if (listener != null) {
                    if (playing) {
                        listener.onPlaying();
                    } else {
                        listener.onPaused();
                    }
                }
            }
            
            @Override
            public void onVideoSizeChanged(VideoSize videoSize) {
                if (listener != null) {
                    listener.onVideoSizeChanged(videoSize.width, videoSize.height);
                }
            }
            
            @Override
            public void onPlayerError(androidx.media3.common.PlaybackException error) {
                Log.e(TAG, "ExoPlayer error: " + error.getMessage());
                if (listener != null) {
                    listener.onError("Playback error: " + error.getMessage());
                }
            }
        });
        
        // Start position updates
        startPositionUpdates();
    }
    
    private void startPositionUpdates() {
        post(new Runnable() {
            @Override
            public void run() {
                if (exoPlayer != null && isInitialized) {
                    currentPosition = exoPlayer.getCurrentPosition();
                    if (listener != null) {
                        listener.onTimeChanged(currentPosition);
                    }
                }
                postDelayed(this, 1000); // Update every second
            }
        });
    }
    
    // Public API methods
    public void setListener(NextPlayerListener listener) {
        this.listener = listener;
    }
    
    public void setMedia(String path) {
        try {
            MediaItem mediaItem = MediaItem.fromUri(Uri.parse(path));
            exoPlayer.setMediaItem(mediaItem);
            exoPlayer.prepare();
            Log.d(TAG, "Media set: " + path);
        } catch (Exception e) {
            Log.e(TAG, "Error setting media", e);
            if (listener != null) {
                listener.onError("Failed to set media: " + e.getMessage());
            }
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
    
    public void stop() {
        if (exoPlayer != null) {
            exoPlayer.stop();
        }
    }
    
    public void seekTo(long position) {
        if (exoPlayer != null) {
            exoPlayer.seekTo(position);
        }
    }
    
    public void setPlaybackSpeed(float speed) {
        if (exoPlayer != null) {
            exoPlayer.setPlaybackSpeed(speed);
            this.playbackSpeed = speed;
            if (listener != null) {
                listener.onPlaybackSpeedChanged(speed);
            }
        }
    }
    
    public void setVolume(float volume) {
        if (exoPlayer != null) {
            exoPlayer.setVolume(volume);
            this.volume = (int) (volume * 100);
            updateVolumeDisplay();
        }
    }
    
    public void setBrightness(int brightness) {
        this.brightness = brightness;
        updateBrightnessDisplay();
    }
    
    public void showVolumeGesture(boolean show) {
        volumeGestureLayout.setVisibility(show ? View.VISIBLE : View.GONE);
    }
    
    public void showBrightnessGesture(boolean show) {
        brightnessGestureLayout.setVisibility(show ? View.VISIBLE : View.GONE);
    }
    
    public void showInfo(String text, String subtext) {
        infoText.setText(text);
        infoSubtext.setText(subtext);
        infoLayout.setVisibility(View.VISIBLE);
        
        // Auto-hide after 2 seconds
        postDelayed(() -> infoLayout.setVisibility(View.GONE), 2000);
    }
    
    public void showTopInfo(String text) {
        topInfoText.setText(text);
        topInfoLayout.setVisibility(View.VISIBLE);
        
        // Auto-hide after 2 seconds
        postDelayed(() -> topInfoLayout.setVisibility(View.GONE), 2000);
    }
    
    private void updateVolumeDisplay() {
        volumeProgressText.setText(volume + "%");
        volumeProgressBar.setProgress(volume);
    }
    
    private void updateBrightnessDisplay() {
        brightnessProgressText.setText(brightness + "%");
        brightnessProgressBar.setProgress(brightness);
    }
    
    // Getters
    public boolean isPlaying() {
        return isPlaying;
    }
    
    public long getDuration() {
        return duration;
    }
    
    public long getCurrentPosition() {
        return currentPosition;
    }
    
    public float getPlaybackSpeed() {
        return playbackSpeed;
    }
    
    public int getVolume() {
        return volume;
    }
    
    public int getBrightness() {
        return brightness;
    }
    
    public boolean isInitialized() {
        return isInitialized;
    }
    
    // Utility methods
    private int dpToPx(int dp) {
        float density = getContext().getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }
    
    public void release() {
        try {
            if (exoPlayer != null) {
                exoPlayer.release();
                exoPlayer = null;
            }
            Log.d(TAG, "NextPlayer released");
        } catch (Exception e) {
            Log.e(TAG, "Error releasing NextPlayer", e);
        }
    }
    
    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        release();
    }
}