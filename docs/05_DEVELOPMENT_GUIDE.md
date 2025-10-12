# Development Guide

## Setup

### Prerequisites
- Flutter 3.6.1+
- Android Studio
- Android SDK 24+
- JDK 11

### Installation

1. Clone repository
2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Build Android:
```bash
flutter build apk --release
```

## Project Structure

```
kjvideoplayer/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/sundeep/kjvideoplayer/
│       │   ├── MainActivity.java
│       │   ├── Media3PlayerPlugin.kt
│       │   └── player/
│       │       ├── Media3PlayerView.kt (★ CORE)
│       │       └── PlayerPoolManager.kt
│       └── res/
├── lib/
│   ├── main.dart
│   ├── core/platform/
│   │   └── media3_player_controller.dart (★)
│   └── presentation/widgets/
│       └── media3_player_widget.dart (★)
└── pubspec.yaml
```

## Adding New Features

### Add Native Method

1. **Native (Media3PlayerView.kt)**:
```kotlin
private fun setupMethodChannel() {
    channel.setMethodCallHandler { call, result ->
        when (call.method) {
            "myNewMethod" -> {
                val param = call.argument<String>("param")
                // Your logic here
                result.success("result")
            }
        }
    }
}
```

2. **Flutter (Media3PlayerController)**:
```dart
Future<String> myNewMethod(String param) async {
  final result = await _channel.invokeMethod('myNewMethod', {
    'param': param,
  });
  return result as String;
}
```

### Send Event from Native

1. **Native**:
```kotlin
channel.invokeMethod("onMyEvent", mapOf(
    "data" to "value"
))
```

2. **Flutter**:
```dart
void _setupMethodCallHandler() {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'onMyEvent') {
      _myEventController.add(call.arguments);
    }
  });
}
```

## Building & Testing

### Debug Build
```bash
flutter run
```

### Release Build
```bash
flutter build apk --release
flutter build appbundle --release
```

### Testing Native Code
```bash
cd android
./gradlew test
```

## Common Development Tasks

### Update Media3 Version
Edit `android/app/build.gradle`:
```gradle
implementation 'androidx.media3:media3-exoplayer:1.5.0'
```

### Add New Video Format Support
Already supported via Media3. No changes needed.

### Modify Player Configuration
Edit `PlayerPoolManager.kt`:
```kotlin
private fun createPlayer(context: Context): ExoPlayer {
    val loadControl = DefaultLoadControl.Builder()
        .setBufferDurationsMs(
            20_000,  // Min buffer (increased)
            40_000,  // Max buffer (increased)
            2_000,   // Playback buffer
            4_000    // Rebuffer
        )
        .build()
    // ...
}
```
