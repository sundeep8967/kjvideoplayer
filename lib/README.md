# KJ Video Player - Clean Architecture

This Flutter video player app follows clean architecture principles with proper separation of concerns.

## 📁 Project Structure

```
lib/
├── app.dart                          # Main app configuration
├── main.dart                         # App entry point
│
├── core/                            # Core utilities and constants
│   ├── constants/
│   │   └── app_constants.dart       # App-wide constants
│   ├── theme/
│   │   └── app_theme.dart          # App theming
│   └── utils/
│       └── system_ui_helper.dart   # System UI utilities
│
├── data/                           # Data layer
│   ├── models/
│   │   ├── video_model.dart        # Video data model
│   │   └── folder_model.dart       # Folder data model
│   └── services/
│       ├── video_scanner_service.dart  # Video scanning logic
│       └── storage_service.dart        # Local storage operations
│
└── presentation/                   # Presentation layer
    ├── animations/
    │   └── slide_transition.dart   # Custom page transitions
    ├── screens/
    │   ├── home/
    │   │   └── home_screen.dart     # Main home screen
    │   └── video_player/
    │       └── video_player_screen.dart  # Video player screen
    └── widgets/
        ├── video_grid.dart         # Video grid display
        ├── video_card.dart         # Individual video card
        ├── folder_grid.dart        # Folder grid display
        ├── folder_card.dart        # Individual folder card
        ├── loading_widget.dart     # Loading indicator
        ├── permission_request_widget.dart  # Permission request UI
        └── video_player/
            └── video_player_widget.dart    # Video player widget
```

## 🏗️ Architecture Principles

### 1. **Separation of Concerns**
- **Data Layer**: Handles data operations, models, and services
- **Presentation Layer**: Handles UI components and user interactions
- **Core Layer**: Contains shared utilities, constants, and configurations

### 2. **Clean Code Practices**
- Meaningful file and class names
- Single responsibility principle
- Dependency injection ready
- Immutable data models
- Proper error handling

### 3. **Scalability**
- Modular structure for easy feature additions
- Reusable widgets and components
- Centralized theme and constants
- Service-based architecture

## 🚀 Key Features

### Data Management
- **VideoModel**: Comprehensive video file representation
- **FolderModel**: Folder organization with nested support
- **StorageService**: Persistent storage for favorites, recent files, bookmarks
- **VideoScannerService**: Efficient video file discovery

### UI Components
- **Responsive Design**: Adapts to different screen sizes
- **Material 3**: Modern Material Design implementation
- **Custom Animations**: Smooth transitions and interactions
- **Permission Handling**: User-friendly permission requests

### Video Player Integration
- **NextPlayer Integration**: Uses proven NextPlayer engine
- **System UI Management**: Proper fullscreen and navigation handling
- **Playback State**: Remembers position and user preferences

## 🔧 Usage

### Adding New Features
1. Create models in `data/models/`
2. Add services in `data/services/`
3. Create screens in `presentation/screens/`
4. Add reusable widgets in `presentation/widgets/`

### Customizing Theme
- Modify `core/theme/app_theme.dart`
- Update constants in `core/constants/app_constants.dart`

### Adding New Video Sources
- Extend `VideoScannerService` for new scanning logic
- Update `VideoModel` if new properties are needed

## 📱 System Requirements
- Flutter 3.0+
- Android API 21+ / iOS 12+
- Storage permissions for video scanning
- Hardware acceleration for smooth playback

## 🎯 Benefits of This Architecture

1. **Maintainable**: Easy to understand and modify
2. **Testable**: Clear separation allows for unit testing
3. **Scalable**: Can grow with new features
4. **Reusable**: Components can be reused across the app
5. **Professional**: Follows industry best practices