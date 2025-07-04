package com.sundeep.kjvideoplayer.nextplayer;

import android.app.Activity;
import android.content.Context;
import android.provider.Settings;
import android.view.WindowManager;

/**
 * Brightness Manager for NextPlayer
 * Handles screen brightness adjustments during video playback
 */
public class BrightnessManager {
    private static final String TAG = "BrightnessManager";
    
    private final Context context;
    private final WindowManager.LayoutParams layoutParams;
    private float currentBrightness;
    private float systemBrightness;
    
    public BrightnessManager(Context context) {
        this.context = context;
        
        if (context instanceof Activity) {
            Activity activity = (Activity) context;
            layoutParams = activity.getWindow().getAttributes();
            systemBrightness = getSystemBrightness();
            currentBrightness = layoutParams.screenBrightness >= 0 ? layoutParams.screenBrightness : systemBrightness;
        } else {
            layoutParams = null;
            systemBrightness = 0.5f;
            currentBrightness = 0.5f;
        }
    }
    
    /**
     * Adjust brightness by a relative amount
     * @param delta The change in brightness (-1.0 to 1.0)
     * @return The new brightness level (0.0 to 1.0)
     */
    public float adjustBrightness(float delta) {
        currentBrightness = Math.max(0.01f, Math.min(1.0f, currentBrightness + delta));
        setBrightness(currentBrightness);
        return currentBrightness;
    }
    
    /**
     * Set absolute brightness level
     * @param brightness The brightness level (0.0 to 1.0)
     */
    public void setBrightness(float brightness) {
        currentBrightness = Math.max(0.01f, Math.min(1.0f, brightness));
        
        if (layoutParams != null && context instanceof Activity) {
            layoutParams.screenBrightness = currentBrightness;
            ((Activity) context).getWindow().setAttributes(layoutParams);
        }
    }
    
    /**
     * Get current brightness level
     * @return Current brightness (0.0 to 1.0)
     */
    public float getCurrentBrightness() {
        return currentBrightness;
    }
    
    /**
     * Reset brightness to system default
     */
    public void resetBrightness() {
        if (layoutParams != null && context instanceof Activity) {
            layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE;
            ((Activity) context).getWindow().setAttributes(layoutParams);
            currentBrightness = systemBrightness;
        }
    }
    
    /**
     * Get system brightness setting
     * @return System brightness (0.0 to 1.0)
     */
    private float getSystemBrightness() {
        try {
            int brightness = Settings.System.getInt(
                context.getContentResolver(),
                Settings.System.SCREEN_BRIGHTNESS
            );
            return brightness / 255.0f;
        } catch (Settings.SettingNotFoundException e) {
            return 0.5f; // Default brightness
        }
    }
}