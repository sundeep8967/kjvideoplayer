import 'package:flutter/material.dart';
import '../../../data/models/video_model.dart';
import '../media3_player_widget.dart';

class VideoPlayerWidget extends StatelessWidget {
  final VideoModel video;
  final bool autoPlay;
  final Duration? startPosition;
  final VoidCallback? onBack;
  final Function(Duration)? onPositionChanged;
  final Function(Duration)? onBookmarkAdded;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.startPosition,
    this.onBack,
    this.onPositionChanged,
    this.onBookmarkAdded,
  });

  @override
  Widget build(BuildContext context) {
    print('VIDEO PLAYER: Using Media3PlayerWidget (Clean AndroidX Media3 Implementation)');
    return Media3PlayerWidget(
      videoPath: video.path,
      videoTitle: video.displayName,
      autoPlay: autoPlay,
      startPosition: startPosition,
      onBack: onBack,
      onPositionChanged: onPositionChanged,
      onBookmarkAdded: onBookmarkAdded,
      showControls: true,
    );
  }
}