import 'dart:io';
import 'package:flutter/services.dart';

class NextPlayerLauncher {
  static const MethodChannel _channel = MethodChannel('com.sundeep.kjvideoplayer/nextplayer');

  static Future<void> launch(String videoPath) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('launchNextPlayer', {'videoPath': videoPath});
    } else {
      throw UnsupportedError('NextPlayer is only available on Android');
    }
  }
}
