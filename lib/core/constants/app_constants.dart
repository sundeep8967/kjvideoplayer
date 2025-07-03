class AppConstants {
  // App Info
  static const String appName = 'KJ Video Player';
  static const String appVersion = '1.0.0';
  
  // Video Extensions
  static const List<String> supportedVideoExtensions = [
    '.mp4',
    '.mkv', 
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.3gp',
  ];
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 600);
  static const Duration longAnimation = Duration(milliseconds: 1000);
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  
  // Video Player
  static const Duration hideControlsDelay = Duration(seconds: 3);
  static const List<double> playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
}