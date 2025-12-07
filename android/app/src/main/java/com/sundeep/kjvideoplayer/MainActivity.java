package com.sundeep.kjvideoplayer;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import androidx.annotation.NonNull;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Register Media3 Player Plugin (clean implementation)
        flutterEngine.getPlugins().add(new Media3PlayerPlugin());

        // Register Brightness Channel
        new io.flutter.plugin.common.MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "com.sundeep.kjvideoplayer/brightness")
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("setBrightness")) {
                                Double brightness = call.argument("brightness");
                                if (brightness != null) {
                                    android.view.WindowManager.LayoutParams layoutParams = getWindow().getAttributes();
                                    layoutParams.screenBrightness = brightness.floatValue();
                                    getWindow().setAttributes(layoutParams);
                                    result.success(null);
                                } else {
                                    result.error("INVALID_ARGUMENT", "Brightness value is null", null);
                                }
                            } else if (call.method.equals("getBrightness")) {
                                float brightness = getWindow().getAttributes().screenBrightness;
                                if (brightness < 0) {
                                    // Negative value means system default, usually around 0.5 or determined by
                                    // system settings
                                    // Since we can't easily get system brightness without permission, we return 0.5
                                    // as fallback
                                    brightness = 0.5f;
                                    try {
                                        int systemBrightness = android.provider.Settings.System.getInt(
                                                getContentResolver(),
                                                android.provider.Settings.System.SCREEN_BRIGHTNESS);
                                        brightness = systemBrightness / 255.0f;
                                    } catch (android.provider.Settings.SettingNotFoundException e) {
                                        e.printStackTrace();
                                    }
                                }
                                result.success((double) brightness);
                            } else {
                                result.notImplemented();
                            }
                        });
    }
}