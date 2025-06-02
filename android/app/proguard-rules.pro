# Flutter specific rules.
#-keep class io.flutter.app.** { *; }
#-keep class io.flutter.plugin.**  { *; }
#-keep class io.flutter.util.**  { *; }
#-keep class io.flutter.view.**  { *; }
#-keep class io.flutter.<em>connectivity.** { </em>; }
#-keep class io.flutter.<em>facade.** { </em>; }
#-keep class io.flutter.<em>embedding.** { </em>; }
# -keepattributes <em>Annotation</em>
# -keepattributes Signature
# -keepattributes InnerClasses
# -keepattributes EnclosingMethod

# Add this line for flutter_vlc_player
-keep class org.videolan.libvlc.** { *; }
