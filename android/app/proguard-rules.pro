# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# Keep annotations
-keepattributes Annotation, InnerClasses, EnclosingMethod, Signature

# Keep source file names for debugging
-keepattributes SourceFile,LineNumberTable

# Optimize for performance
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# Media3 specific optimizations
-keep class androidx.media3.exoplayer.** {
    public *;
}
-keep class androidx.media3.common.** {
    public *;
}

# Add this line for flutter_vlc_player
-keep class org.videolan.libvlc.** { *; }
