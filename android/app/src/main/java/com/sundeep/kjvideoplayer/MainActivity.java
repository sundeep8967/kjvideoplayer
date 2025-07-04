package com.sundeep.kjvideoplayer;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import com.sundeep.kjvideoplayer.nextplayer.EnhancedNextPlayerPlugin;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Register the enhanced NextPlayer plugin
        flutterEngine.getPlugins().add(new EnhancedNextPlayerPlugin());
    }
}