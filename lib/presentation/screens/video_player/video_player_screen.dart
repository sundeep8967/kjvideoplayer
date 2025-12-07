import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/system_ui_helper.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/video_player/video_player_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<VideoModel> playlist;
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.playlist,
    required this.initialIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final StorageService _storageService = StorageService();
  late int _currentIndex;
  late VideoModel _currentVideo;
  Duration? _savedPosition;
  bool _isLoadingPosition = true;
  Key _playerKey = UniqueKey(); // Key to force player rebuild on video change

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentVideo = widget.playlist[_currentIndex];
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
    _savedPosition = await _storageService.getPlaybackPosition(_currentVideo.path);
    if (mounted) {
      setState(() {
        _isLoadingPosition = false;
      });
    }
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
      _storageService.savePlaybackPosition(_currentVideo.path, position);
    }
  }

  void _onBookmarkAdded(Duration position) {
    _storageService.addBookmark(_currentVideo.path, position);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark added'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _playNext() {
    if (_currentIndex < widget.playlist.length - 1) {
      _switchVideo(_currentIndex + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more videos in playlist')),
      );
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _switchVideo(_currentIndex - 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is the first video')),
      );
    }
  }

  Future<void> _switchVideo(int index) async {
    setState(() {
      _isLoadingPosition = true;
      _currentIndex = index;
      _currentVideo = widget.playlist[_currentIndex];
      _savedPosition = Duration.zero; // Reset saved position for new video (or load it)
      _playerKey = UniqueKey(); // Force player rebuild
    });
    
    // Load saved position for the new video
    final pos = await _storageService.getPlaybackPosition(_currentVideo.path);
    if (mounted) {
      setState(() {
        _savedPosition = pos;
        _isLoadingPosition = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoadingPosition
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : VideoPlayerWidget(
              key: _playerKey,
              video: _currentVideo,
              autoPlay: true,
              startPosition: _savedPosition,
              onBack: _onBackPressed,
              onPositionChanged: _onPositionChanged,
              onBookmarkAdded: _onBookmarkAdded,
              onNext: _currentIndex < widget.playlist.length - 1 ? _playNext : null,
              onPrevious: _currentIndex > 0 ? _playPrevious : null,
              onVideoCompleted: () {
                debugPrint('Video completed, playing next...');
                if (_currentIndex < widget.playlist.length - 1) {
                  _playNext();
                }
              },
            ),
    );
  }
}