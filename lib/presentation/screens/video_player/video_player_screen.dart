import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/video_player/video_player_widget.dart';
import 'enhanced_video_player_screen.dart';
import '../../../core/nextplayer_launcher.dart';

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
  bool _useBuiltInPlayer = false;

  @override
  void initState() {
    super.initState();
    _tryLaunchNextPlayer();
  }

  Future<void> _tryLaunchNextPlayer() async {
    try {
      // Check if NextPlayer is installed immediately
      final isInstalled = await NextPlayerLauncher.isNextPlayerInstalled();
      
      if (isInstalled) {
        // Launch NextPlayer with the video
        final success = await NextPlayerLauncher.launchVideo(widget.video.path);
        
        if (success) {
          // NextPlayer launched successfully, immediately close this screen
          if (mounted) {
            Navigator.of(context).pop();
          }
          
          // Save to recent videos in background
          final recentVideos = await _storageService.getRecentVideos();
          final updatedVideos = [widget.video, ...recentVideos.where((v) => v.path != widget.video.path)];
          await _storageService.saveRecentVideos(updatedVideos.take(10).toList());
          return;
        }
      }
      
      // If NextPlayer is not available or failed, silently use built-in player
      _fallbackToBuiltInPlayer();
    } catch (e) {
      // If NextPlayer launch fails, silently use built-in player
      _fallbackToBuiltInPlayer();
    }
  }

  void _fallbackToBuiltInPlayer() {
    setState(() {
      _useBuiltInPlayer = true;
    });
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
    // If using built-in player, show the video player interface
    if (_useBuiltInPlayer) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // Custom App Bar
            Container(
              height: MediaQuery.of(context).padding.top + 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _onBackPressed,
                    ),
                    Expanded(
                      child: Text(
                        widget.video.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.enhanced_encryption, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => EnhancedVideoPlayerScreen(video: widget.video),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Video Player
            Expanded(
              child: VideoPlayerWidget(
                video: widget.video,
                startPosition: _savedPosition,
                onPositionChanged: _onPositionChanged,
                onBookmarkAdded: _onBookmarkAdded,
              ),
            ),
          ],
        ),
      );
    }
    
    // If NextPlayer is launching or failed, show minimal screen
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/applogo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const Text(
              'Opening Video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}