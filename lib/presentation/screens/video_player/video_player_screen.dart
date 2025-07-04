import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/video_player/video_player_widget.dart';
import 'enhanced_video_player_screen.dart';

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
      body: Column(
        children: [
          // Player selection header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _onBackPressed,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.video.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Player options
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Enhanced NextPlayer (Recommended)
                  Card(
                    color: Colors.orange.withOpacity(0.1),
                    child: ListTile(
                      leading: const Icon(Icons.star, color: Colors.orange),
                      title: const Text(
                        'Enhanced NextPlayer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Professional video player with advanced gestures, PiP, and multi-track support',
                        style: TextStyle(color: Colors.grey),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RECOMMENDED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnhancedVideoPlayerScreen(video: widget.video),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Original Video Player
                  Card(
                    color: Colors.grey.withOpacity(0.1),
                    child: ListTile(
                      leading: const Icon(Icons.play_circle, color: Colors.white),
                      title: const Text(
                        'Standard Player',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Basic video player with standard controls',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _StandardPlayerScreen(
                              video: widget.video,
                              autoPlay: widget.autoPlay,
                              savedPosition: _savedPosition,
                              onPositionChanged: _onPositionChanged,
                              onBookmarkAdded: _onBookmarkAdded,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardPlayerScreen extends StatelessWidget {
  final VideoModel video;
  final bool autoPlay;
  final Duration? savedPosition;
  final Function(Duration) onPositionChanged;
  final Function(Duration) onBookmarkAdded;
  
  const _StandardPlayerScreen({
    required this.video,
    required this.autoPlay,
    required this.savedPosition,
    required this.onPositionChanged,
    required this.onBookmarkAdded,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VideoPlayerWidget(
        video: video,
        autoPlay: autoPlay,
        startPosition: savedPosition,
        onBack: () {
          SystemUIHelper.restoreNormalUI();
          Navigator.pop(context);
        },
        onPositionChanged: onPositionChanged,
        onBookmarkAdded: onBookmarkAdded,
      ),
    );
  }
}