import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/video_player/video_player_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  final bool autoPlay;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.autoPlay = true,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final StorageService _storageService = StorageService();
  Duration? _savedPosition;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Set video playback UI
    SystemUIHelper.setVideoPlaybackUI();
    
    // Load saved playback position
    _savedPosition = await _storageService.getPlaybackPosition(widget.video.path);
  }

  @override
  void dispose() {
    // Restore normal UI
    SystemUIHelper.restoreNormalUI();
    super.dispose();
  }

  void _onBackPressed() {
    SystemUIHelper.restoreNormalUI();
    Navigator.pop(context);
  }

  void _onPositionChanged(Duration position) {
    // Save playback position every 10 seconds
    if (position.inSeconds % 10 == 0) {
      _storageService.savePlaybackPosition(widget.video.path, position);
    }
  }

  void _onBookmarkAdded(Duration position) {
    _storageService.addBookmark(widget.video.path, position);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark added'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VideoPlayerWidget(
        video: widget.video,
        autoPlay: widget.autoPlay,
        startPosition: _savedPosition,
        onBack: _onBackPressed,
        onPositionChanged: _onPositionChanged,
        onBookmarkAdded: _onBookmarkAdded,
      ),
    );
  }
}