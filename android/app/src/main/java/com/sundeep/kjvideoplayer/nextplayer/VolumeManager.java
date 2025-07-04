package com.sundeep.kjvideoplayer.nextplayer;

import android.content.Context;
import android.media.AudioManager;

/**
 * Volume Manager for NextPlayer
 * Handles audio volume adjustments during video playback
 */
public class VolumeManager {
    private static final String TAG = "VolumeManager";
    
    private final AudioManager audioManager;
    private final int maxVolume;
    private int currentVolume;
    
    public VolumeManager(Context context) {
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
        currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
    }
    
    /**
     * Adjust volume by a relative amount
     * @param delta The change in volume (-1.0 to 1.0)
     * @return The new volume level (0.0 to 1.0)
     */
    public float adjustVolume(float delta) {
        int volumeChange = (int) (delta * maxVolume);
        int newVolume = Math.max(0, Math.min(maxVolume, currentVolume + volumeChange));
        
        setVolume(newVolume);
        return (float) newVolume / maxVolume;
    }
    
    /**
     * Set absolute volume level
     * @param volume The volume level (0.0 to 1.0)
     */
    public void setVolumeLevel(float volume) {
        int volumeLevel = (int) (volume * maxVolume);
        setVolume(volumeLevel);
    }
    
    /**
     * Set volume by absolute value
     * @param volume Volume level (0 to maxVolume)
     */
    private void setVolume(int volume) {
        currentVolume = Math.max(0, Math.min(maxVolume, volume));
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, currentVolume, 0);
    }
    
    /**
     * Get current volume level
     * @return Current volume (0.0 to 1.0)
     */
    public float getCurrentVolume() {
        currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        return (float) currentVolume / maxVolume;
    }
    
    /**
     * Increase volume by one step
     */
    public void volumeUp() {
        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0);
        currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
    }
    
    /**
     * Decrease volume by one step
     */
    public void volumeDown() {
        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0);
        currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
    }
    
    /**
     * Mute/unmute volume
     */
    public void toggleMute() {
        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_TOGGLE_MUTE, 0);
        currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
    }
    
    /**
     * Check if volume is muted
     * @return true if muted
     */
    public boolean isMuted() {
        return currentVolume == 0;
    }
}