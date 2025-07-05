import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/video_player/video_player_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({
    super.key,
    required this.video,
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
    
    // Set landscape orientation for video playback
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide system UI for immersive video experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Load saved position
    _savedPosition = await _storageService.getPlaybackPosition(widget.video.path);
  }

  @override
  void dispose() {
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemUIHelper.restoreNormalUI();
    super.dispose();
  }

  void _onBackPressed() {
    Navigator.pop(context);
  }

  void _onPositionChanged(Duration position) {
    if (position.inSeconds % 5 == 0) {
      _storageService.savePlaybackPosition(widget.video.path, position);
    }
  }

  void _onBookmarkAdded(Duration position) {
    _storageService.addBookmark(widget.video.path, position);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark added'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VideoPlayerWidget(
        video: widget.video,
        autoPlay: true,
        startPosition: _savedPosition,
        onBack: _onBackPressed,
        onPositionChanged: _onPositionChanged,
        onBookmarkAdded: _onBookmarkAdded,
      ),
    );
  }
}