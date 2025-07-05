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
    }
}