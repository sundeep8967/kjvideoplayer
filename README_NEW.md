# KJ Video Player

A comprehensive Flutter video player application with advanced features including gesture controls, audio track selection, subtitle support, and smooth UI animations. Built with AndroidX Media3 for optimal video playback performance.

## Features

### Core Video Player Features
- **High-Performance Playback**: AndroidX Media3 ExoPlayer integration
- **Multiple Format Support**: MP4, MKV, AVI, MOV, and more
- **Adaptive Streaming**: Automatic quality adjustment based on network
- **Hardware Acceleration**: GPU-accelerated video decoding
- **Background Playback**: Continue playback when app is backgrounded

### Advanced Controls
- **Gesture Controls**:
  - Left side swipe: Brightness control
  - Right side swipe: Volume control  
  - Pinch to zoom: Zoom in/out with smooth animations
  - Double tap: Play/pause toggle
  - Single tap: Show/hide controls

- **Audio & Subtitle Management**:
  - Multiple audio track selection
  - Subtitle track switching
  - Audio language preferences
  - Real-time track detection

- **Playback Controls**:
  - Variable speed playback (0.5x to 2.0x)
  - 10-second seek forward/backward
  - Progress bar with buffer indication
  - Auto-hide controls with smooth animations

### UI/UX Features
- **iOS-Style Interface**: Native iOS design patterns
- **Smooth Animations**: 60fps UI transitions
- **Haptic Feedback**: Tactile response for interactions
- **Dark Theme**: Optimized for video viewing
- **Landscape Optimization**: Full-screen video experience

## Project Architecture

### Flutter Layer (Dart)
```
lib/
├── main.dart                           # App entry point
├── app.dart                           # App configuration
├── core/                              # Core utilities and platform interfaces
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   ├── platform/
│   │   └── media3_player_controller.dart  # Media3 platform controller
│   ├── theme/
│   │   └── app_theme.dart             # App theming
│   └── utils/
│       ├── haptic_feedback_helper.dart # Haptic feedback utilities
│       └── system_ui_helper.dart      # System UI management
├── data/                              # Data layer
│   ├── models/
│   │   ├── folder_model.dart          # Folder data model
│   │   └── video_model.dart           # Video data model
│   └── services/
│       ├── storage_service.dart       # Local storage management
│       ├── thumbnail_service.dart     # Video thumbnail generation
│       └── video_scanner_service.dart # Video file discovery
├── presentation/                      # UI layer
│   ├── animations/
│   │   └── ios_page_transitions.dart  # iOS-style page transitions
│   ├── screens/
│   │   ├── home/
│   │   │   ├── ios_folder_screen.dart # Folder browsing screen
│   │   │   └── ios_video_home_screen.dart # Main video library
│   │   └── video_player/
│   │       └── video_player_screen.dart # Video player screen
│   └── widgets/
│       ├── video_player/
│       │   └── video_player_widget.dart # Main video player widget
│       ├── audio_tracks_dialog.dart   # Audio track selection
│       ├── subtitle_tracks_dialog.dart # Subtitle track selection
│       ├── video_settings_dialog.dart # Player settings
│       ├── media3_player_widget.dart  # Core Media3 player widget
│       ├── ios_*.dart                 # iOS-style UI components
│       └── tinder_*.dart              # Card-based UI components
```

### Android Native Layer (Kotlin/Java)
```
android/app/src/main/java/com/sundeep/kjvideoplayer/
├── MainActivity.java                  # Main Android activity
├── Media3PlayerPlugin.kt              # Flutter plugin registration
├── NextPlayerLauncher.java            # Legacy player launcher
└── player/
    ├── Media3PlayerView.kt            # Core Media3 player implementation
    └── NextPlayerPlatformView.kt      # Legacy platform view
```

### iOS Native Layer (Swift)
```
ios/
├── Runner/
│   ├── AppDelegate.swift              # iOS app delegate
│   ├── Info.plist                     # iOS app configuration
│   └── Assets.xcassets/               # iOS app assets
└── Runner.xcodeproj/                  # Xcode project files
```

### Android Resources
```
android/app/src/main/res/
├── drawable/                          # Vector drawables
│   ├── ic_brightness_high.xml         # Brightness icons
│   ├── ic_volume_*.xml                # Volume control icons
│   ├── ic_fast_forward.xml            # Playback control icons
│   └── gesture_background.xml         # Gesture overlay background
├── values/
│   └── styles.xml                     # Android app styles
└── values-night/
    └── styles.xml                     # Dark theme styles
```

### Configuration Files
```
├── pubspec.yaml                       # Flutter dependencies
├── analysis_options.yaml             # Dart analysis rules
├── devtools_options.yaml             # Flutter DevTools config
├── android/
│   ├── build.gradle                   # Android build configuration
│   ├── settings.gradle                # Android project settings
│   └── app/build.gradle               # App-specific build config
└── ios/
    └── Podfile                        # iOS dependencies
```

## Key Components

### Media3PlayerController
The core controller that bridges Flutter and native Android Media3 player:
- **Method Channels**: Bidirectional communication with native layer
- **Stream Controllers**: Reactive state management
- **Track Management**: Audio/subtitle track detection and switching
- **Volume Control**: System and player volume management
- **Performance Monitoring**: Real-time playback metrics

### Media3PlayerView (Kotlin)
Native Android implementation using AndroidX Media3:
- **ExoPlayer Integration**: Latest Media3 ExoPlayer APIs
- **Track Selector**: Advanced track detection and selection
- **Audio Manager**: System volume control and monitoring
- **Lifecycle Management**: Proper resource cleanup
- **Performance Optimization**: Hardware acceleration and buffering

### Gesture System
Advanced gesture recognition for video controls:
- **Multi-finger Detection**: Distinguishes between zoom and swipe gestures
- **Gesture Priority**: Smart handling of conflicting gestures
- **Smooth Animations**: 60fps gesture feedback
- **Haptic Integration**: Tactile feedback for user actions

## Platform Support

### Android
- **Minimum SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)
- **Architecture**: ARM64, ARMv7, x86_64
- **Media3 Version**: Latest stable release

### iOS
- **Minimum Version**: iOS 12.0
- **Architecture**: ARM64, x86_64 (simulator)
- **Swift Version**: 5.0+

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / Xcode
- Android SDK 21+
- iOS 12.0+

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd kjvideoplayer

# Install dependencies
flutter pub get

# Run on Android
flutter run

# Run on iOS
flutter run -d ios
```

### Building
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Usage

### Basic Video Playback
1. Launch the app
2. Browse video folders or select from library
3. Tap a video to start playback
4. Use gestures for volume, brightness, and zoom control

### Gesture Controls
- **Volume**: Swipe up/down on right side of screen
- **Brightness**: Swipe up/down on left side of screen
- **Zoom**: Pinch with two fingers to zoom in/out
- **Seek**: Tap forward/backward buttons or drag progress bar
- **Play/Pause**: Double-tap screen or use control buttons

### Audio Tracks
1. Tap the music note icon in top controls
2. Select from available audio tracks
3. Tracks switch seamlessly during playback

### Subtitles
1. Tap the subtitle icon in top controls
2. Choose from available subtitle tracks
3. Toggle subtitles on/off as needed

## Technical Details

### Performance Optimizations
- **Hardware Acceleration**: GPU-accelerated video decoding
- **Adaptive Buffering**: Dynamic buffer sizing based on network
- **Memory Management**: Efficient texture and bitmap handling
- **UI Optimization**: Minimal widget rebuilds and smooth animations

### Audio/Video Codec Support
- **Video**: H.264, H.265/HEVC, VP8, VP9, AV1
- **Audio**: AAC, MP3, Opus, Vorbis, FLAC
- **Containers**: MP4, MKV, WebM, AVI, MOV

### Gesture Recognition
- **Multi-touch Support**: Up to 10 simultaneous touch points
- **Gesture Disambiguation**: Smart detection of zoom vs swipe
- **Smooth Interpolation**: 60fps gesture tracking
- **Haptic Feedback**: Tactile response for all interactions

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues and feature requests, please use the GitHub issue tracker.