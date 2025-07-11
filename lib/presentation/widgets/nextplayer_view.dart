import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NextPlayerViewController {
  final MethodChannel _channel;
  NextPlayerViewController._(this._channel);

  Future<void> play() => _channel.invokeMethod('play');
  Future<void> pause() => _channel.invokeMethod('pause');
  Future<void> seekTo(Duration position) => _channel.invokeMethod('seekTo', {'position': position.inMilliseconds});
  Future<void> dispose() => _channel.invokeMethod('dispose');

  void setEventHandler({
    void Function()? onPlay,
    void Function()? onPause,
    void Function()? onCompleted,
    void Function(Duration)? onSeek,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlay':
          if (onPlay != null) onPlay();
          break;
        case 'onPause':
          if (onPause != null) onPause();
          break;
        case 'onCompleted':
          if (onCompleted != null) onCompleted();
          break;
        case 'onSeek':
          if (onSeek != null) onSeek(Duration(milliseconds: call.arguments['position'] ?? 0));
          break;
      }
    });
  }
}

class NextPlayerView extends StatefulWidget {
  final String videoPath;
  final double? aspectRatio;
  final void Function(NextPlayerViewController)? onViewCreated;

  const NextPlayerView({
    Key? key,
    required this.videoPath,
    this.aspectRatio,
    this.onViewCreated,
  }) : super(key: key);

  @override
  State<NextPlayerView> createState() => _NextPlayerViewState();
}

class _NextPlayerViewState extends State<NextPlayerView> {
  NextPlayerViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'nextplayer_view',
      creationParams: {'videoPath': widget.videoPath},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        final channel = MethodChannel('nextplayer_view_ $id');
        _controller = NextPlayerViewController._(channel);
        if (widget.onViewCreated != null) {
          widget.onViewCreated!(_controller!);
        }
      },
    );
  }
}

// Example usage in a video player screen:
//
// NextPlayerView(
//   videoPath: '/storage/emulated/0/Movies/my_video.mp4',
//   onViewCreated: (controller) {
//     // controller.play();
//     // controller.pause();
//     // controller.seekTo(Duration(seconds: 30));
//     controller.setEventHandler(
//       onPlay: () => print('Playing'),
//       onPause: () => print('Paused'),
//       onCompleted: () => print('Completed'),
//     );
//   },
// )
