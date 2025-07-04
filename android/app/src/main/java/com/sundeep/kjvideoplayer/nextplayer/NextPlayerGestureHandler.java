package com.sundeep.kjvideoplayer.nextplayer;

import android.content.Context;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

/**
 * NextPlayer Gesture Handler
 * Handles all gesture interactions for video playback
 */
public class NextPlayerGestureHandler implements View.OnTouchListener {
    private static final String TAG = "NextPlayerGestureHandler";
    
    private final Context context;
    private final MethodChannel methodChannel;
    private final BrightnessManager brightnessManager;
    private final VolumeManager volumeManager;
    private View playerView;
    
    // Gesture detectors
    private final GestureDetector gestureDetector;
    private final ScaleGestureDetector scaleGestureDetector;
    
    // Gesture settings
    private boolean useSwipeControls = true;
    private boolean useSeekControls = true;
    private boolean useZoomControls = true;
    private boolean useLongPressControls = false;
    private double longPressSpeed = 2.0;
    private String doubleTapGesture = "both"; // "disabled", "playPause", "seek", "both"
    
    // Gesture state
    private boolean isGestureActive = false;
    private String currentGestureType = "none";
    private float gestureStartX = 0f;
    private float gestureStartY = 0f;
    private long gestureStartTime = 0L;
    
    // Seek settings
    private int seekIncrement = 10; // seconds
    private long minDurationForFastSeek = 120000; // 2 minutes in milliseconds
    
    public NextPlayerGestureHandler(Context context, MethodChannel methodChannel, View playerView) {
        this.context = context;
        this.methodChannel = methodChannel;
        this.playerView = playerView;
        this.brightnessManager = new BrightnessManager(context);
        this.volumeManager = new VolumeManager(context);
        
        this.gestureDetector = new GestureDetector(context, new GestureListener());
        this.scaleGestureDetector = new ScaleGestureDetector(context, new ScaleGestureListener());
    }
    
    @Override
    public boolean onTouch(View v, MotionEvent event) {
        boolean handled = false;
        
        // Handle scale gestures (zoom)
        if (useZoomControls && event.getPointerCount() == 2) {
            handled = scaleGestureDetector.onTouchEvent(event);
        }
        
        // Handle single touch gestures
        if (event.getPointerCount() == 1) {
            handled = gestureDetector.onTouchEvent(event) || handled;
        }
        
        // Handle gesture end
        if (event.getAction() == MotionEvent.ACTION_UP || event.getAction() == MotionEvent.ACTION_CANCEL) {
            endGesture();
        }
        
        return handled;
    }
    
    private class GestureListener extends GestureDetector.SimpleOnGestureListener {
        
        @Override
        public boolean onDown(MotionEvent e) {
            gestureStartX = e.getX();
            gestureStartY = e.getY();
            gestureStartTime = System.currentTimeMillis();
            return true;
        }
        
        @Override
        public boolean onSingleTapConfirmed(MotionEvent e) {
            // Handle single tap (show/hide controls)
            sendGestureEvent("singleTap", 0.0, "");
            return true;
        }
        
        @Override
        public boolean onDoubleTap(MotionEvent e) {
            if (!doubleTapGesture.equals("disabled")) {
                handleDoubleTap(e);
            }
            return true;
        }
        
        @Override
        public void onLongPress(MotionEvent e) {
            if (useLongPressControls) {
                handleLongPress();
            }
        }
        
        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            if (e1 == null || e2 == null) return false;
            
            float deltaX = e2.getX() - e1.getX();
            float deltaY = e2.getY() - e1.getY();
            
            // Determine gesture type based on movement
            if (Math.abs(deltaX) > Math.abs(deltaY)) {
                // Horizontal swipe - seeking
                if (useSeekControls) {
                    handleHorizontalSwipe(deltaX, e2.getX());
                }
            } else {
                // Vertical swipe - volume or brightness
                if (useSwipeControls) {
                    handleVerticalSwipe(deltaY, e2.getX(), e2.getY());
                }
            }
            
            return true;
        }
    }
    
    private class ScaleGestureListener extends ScaleGestureDetector.SimpleOnScaleGestureListener {
        
        @Override
        public boolean onScale(ScaleGestureDetector detector) {
            if (useZoomControls) {
                float scaleFactor = detector.getScaleFactor();
                handleZoomGesture(scaleFactor);
                return true;
            }
            return false;
        }
        
        @Override
        public boolean onScaleBegin(ScaleGestureDetector detector) {
            if (useZoomControls) {
                startGesture("zoom");
                return true;
            }
            return false;
        }
        
        @Override
        public void onScaleEnd(ScaleGestureDetector detector) {
            endGesture();
        }
    }
    
    private void handleHorizontalSwipe(float deltaX, float currentX) {
        startGesture("seek");
        
        // Calculate seek amount based on swipe distance
        float screenWidth = playerView.getWidth();
        float swipeRatio = deltaX / screenWidth;
        int seekAmount = (int) (swipeRatio * seekIncrement);
        
        String seekText = formatSeekText(seekAmount);
        sendGestureEvent("seek", seekAmount, seekText);
    }
    
    private void handleVerticalSwipe(float deltaY, float currentX, float currentY) {
        float screenWidth = playerView.getWidth();
        float screenHeight = playerView.getHeight();
        
        if (currentX < screenWidth / 2) {
            // Left side - brightness
            startGesture("brightness");
            float brightnessChange = -deltaY / screenHeight;
            float newBrightness = brightnessManager.adjustBrightness(brightnessChange);
            String brightnessText = Math.round(newBrightness * 100) + "%";
            sendGestureEvent("brightness", newBrightness, brightnessText);
        } else {
            // Right side - volume
            startGesture("volume");
            float volumeChange = -deltaY / screenHeight;
            float newVolume = volumeManager.adjustVolume(volumeChange);
            String volumeText = Math.round(newVolume * 100) + "%";
            sendGestureEvent("volume", newVolume, volumeText);
        }
    }
    
    private void handleZoomGesture(float scaleFactor) {
        // Send zoom gesture event
        sendGestureEvent("zoom", scaleFactor, Math.round(scaleFactor * 100) + "%");
    }
    
    private void handleDoubleTap(MotionEvent e) {
        float screenWidth = playerView.getWidth();
        boolean isLeftSide = e.getX() < screenWidth / 2;
        
        switch (doubleTapGesture) {
            case "playPause":
                sendGestureEvent("doubleTapPlayPause", 0.0, "Play/Pause");
                break;
            case "seek":
                if (isLeftSide) {
                    sendGestureEvent("doubleTapSeekBack", -seekIncrement, "Seek -" + seekIncrement + "s");
                } else {
                    sendGestureEvent("doubleTapSeekForward", seekIncrement, "Seek +" + seekIncrement + "s");
                }
                break;
            case "both":
                // Center tap for play/pause, sides for seek
                if (e.getX() > screenWidth * 0.3 && e.getX() < screenWidth * 0.7) {
                    sendGestureEvent("doubleTapPlayPause", 0.0, "Play/Pause");
                } else if (isLeftSide) {
                    sendGestureEvent("doubleTapSeekBack", -seekIncrement, "Seek -" + seekIncrement + "s");
                } else {
                    sendGestureEvent("doubleTapSeekForward", seekIncrement, "Seek +" + seekIncrement + "s");
                }
                break;
        }
    }
    
    private void handleLongPress() {
        startGesture("longPress");
        sendGestureEvent("longPressStart", longPressSpeed, longPressSpeed + "x Speed");
    }
    
    private void startGesture(String gestureType) {
        if (!isGestureActive) {
            isGestureActive = true;
            currentGestureType = gestureType;
        }
    }
    
    private void endGesture() {
        if (isGestureActive) {
            sendGestureEvent("gestureEnd", 0.0, "");
            isGestureActive = false;
            currentGestureType = "none";
        }
    }
    
    private void sendGestureEvent(String type, double value, String text) {
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("type", type);
        arguments.put("value", value);
        arguments.put("text", text);
        
        methodChannel.invokeMethod("onGestureEvent", arguments);
    }
    
    private String formatSeekText(int seekAmount) {
        if (seekAmount > 0) {
            return "+" + seekAmount + "s";
        } else {
            return seekAmount + "s";
        }
    }
    
    // Configuration methods
    public void setGestureControls(boolean useSwipe, boolean useSeek, boolean useZoom, boolean useLongPress) {
        this.useSwipeControls = useSwipe;
        this.useSeekControls = useSeek;
        this.useZoomControls = useZoom;
        this.useLongPressControls = useLongPress;
    }
    
    public void setDoubleTapGesture(String gesture) {
        this.doubleTapGesture = gesture;
    }
    
    public void setSeekIncrement(int increment) {
        this.seekIncrement = increment;
    }
    
    public void setLongPressSpeed(double speed) {
        this.longPressSpeed = speed;
    }
}