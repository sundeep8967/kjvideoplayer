import 'package:flutter/services.dart';

class ScreenOnController {
  static const MethodChannel _channel = MethodChannel('my.channel/keep_screen_on');

  static Future<void> enableScreenOn() async {
    await _channel.invokeMethod('enableScreenOn');
  }

  static Future<void> disableScreenOn() async {
    await _channel.invokeMethod('disableScreenOn');
  }
}
