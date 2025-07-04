import 'package:flutter/material.dart';
import 'enhanced_nextplayer/enhanced_nextplayer_controller.dart';
import 'enhanced_nextplayer/enhanced_nextplayer_widget.dart';

/// Simple test screen to verify NextPlayer functionality
class TestNextPlayerScreen extends StatefulWidget {
  const TestNextPlayerScreen({super.key});

  @override
  State<TestNextPlayerScreen> createState() => _TestNextPlayerScreenState();
}

class _TestNextPlayerScreenState extends State<TestNextPlayerScreen> {
  late EnhancedNextPlayerController _controller;
  bool _isInitialized = false;
  String _status = 'Initializing...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = EnhancedNextPlayerController();
      
      setState(() {
        _status = 'Initializing plugin...';
      });
      
      final result = await _controller.initializePlugin();
      
      setState(() {
        _isInitialized = true;
        _status = 'Plugin initialized successfully!';
      });
      
      print('NextPlayer initialization result: $result');
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = 'Failed to initialize';
      });
      print('NextPlayer initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NextPlayer Test'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plugin Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.pending,
                          color: _isInitialized ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(_status),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isInitialized) ...[
              const Text(
                'Test Video Player:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const EnhancedNextPlayerWidget(
                    videoPath: 'assets/video_for_test.mp4',
                    autoPlay: true,
                    showControls: true,
                    enableGestures: true,
                    enablePictureInPicture: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _controller.play();
                        } catch (e) {
                          print('Play error: $e');
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _controller.pause();
                        } catch (e) {
                          print('Pause error: $e');
                        }
                      },
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Test Instructions:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Using bundled test video: assets/video_for_test.mp4\n'
                '• AutoPlay is enabled - video should start automatically\n'
                '• Test gesture controls:\n'
                '  - Swipe left/right for seek\n'
                '  - Swipe up/down on left for brightness\n'
                '  - Swipe up/down on right for volume\n'
                '  - Pinch to zoom\n'
                '  - Double tap for play/pause\n'
                '• Use Play/Pause buttons above for manual control',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}