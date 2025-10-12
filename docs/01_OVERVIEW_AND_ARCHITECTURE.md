# Video Player App - Overview & Architecture

## Project Overview

**App Name**: i Player  
**Package**: `com.sundeep.kjvideoplayer`  
**Platform**: Flutter + Android Native (Media3)  
**Architecture**: Hybrid (Flutter UI + Native Video Playback)

### Purpose
A professional video player application that leverages AndroidX Media3 (ExoPlayer) for high-performance video playback with custom Flutter UI controls.

### Technology Stack
- **Frontend**: Flutter 3.6.1+
- **Native Android**: Kotlin + Java
- **Video Engine**: AndroidX Media3 1.4.1 (ExoPlayer)
- **Build System**: Gradle
- **Platform Communication**: MethodChannel

## High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│           Flutter Application Layer              │
│  ┌───────────────────────────────────────────┐  │
│  │    UI Widgets & Screens                   │  │
│  │  - Video Player Screen                    │  │
│  │  - Home Screen                            │  │
│  │  - Settings Dialog                        │  │
│  └───────────────┬───────────────────────────┘  │
│                  │                               │
│  ┌───────────────▼───────────────────────────┐  │
│  │   Media3PlayerController (Dart)          │  │
│  │   - State Management                      │  │
│  │   - Event Handling                        │  │
│  │   - Method Channel Communication          │  │
│  └───────────────┬───────────────────────────┘  │
└──────────────────┼───────────────────────────────┘
                   │ MethodChannel
                   │ (media3_player_X)
┌──────────────────▼───────────────────────────────┐
│         Android Native Layer                     │
│  ┌───────────────────────────────────────────┐  │
│  │   MainActivity.java                       │  │
│  │   - Plugin Registration                   │  │
│  └───────────────┬───────────────────────────┘  │
│                  │                               │
│  ┌───────────────▼───────────────────────────┐  │
│  │   Media3PlayerPlugin.kt                   │  │
│  │   - Platform View Factory Registration    │  │
│  └───────────────┬───────────────────────────┘  │
│                  │                               │
│  ┌───────────────▼───────────────────────────┐  │
│  │   Media3PlayerView.kt (Main Engine)       │  │
│  │   - ExoPlayer Instance                    │  │
│  │   - Track Management                      │  │
│  │   - MediaSession Integration              │  │
│  │   - PiP Support                           │  │
│  │   - Method Channel Handler                │  │
│  └───────────────┬───────────────────────────┘  │
│                  │                               │
│  ┌───────────────▼───────────────────────────┐  │
│  │   PlayerPoolManager.kt                    │  │
│  │   - Player Instance Pooling               │  │
│  │   - Resource Management                   │  │
│  └───────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

## Design Patterns Used

1. **Platform View Pattern**: Native Android views embedded in Flutter
2. **Object Pool Pattern**: Player instance reuse for performance
3. **Observer Pattern**: Event streams for state updates
4. **Factory Pattern**: Platform view creation
5. **Singleton Pattern**: PlayerPoolManager

## File Structure

### Android Native
```
android/app/src/main/java/com/sundeep/kjvideoplayer/
├── MainActivity.java (Entry point)
├── Media3PlayerPlugin.kt (Plugin registration)
└── player/
    ├── Media3PlayerView.kt (Core engine - 1753 lines)
    ├── NextPlayerPlatformView.kt (Alternative)
    └── PlayerPoolManager.kt (Resource management)
```

### Flutter
```
lib/
├── main.dart (Entry point)
├── core/
│   └── platform/
│       └── media3_player_controller.dart (Primary controller - 846 lines)
└── presentation/
    └── widgets/
        └── media3_player_widget.dart (UI widget - 2852 lines)
```

## Communication Flow

1. **Flutter → Native**: User interacts with UI → Controller calls MethodChannel → Native executes
2. **Native → Flutter**: Player events → MethodChannel callback → Controller updates state → UI rebuilds
3. **Data Flow**: Bidirectional through MethodChannel with unique IDs per player instance
