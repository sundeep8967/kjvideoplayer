import 'dart:async';
import 'package:flutter/services.dart';

/// Audio Manager for advanced audio features
/// Implements NextPlayer's audio enhancements like volume boost and skip silence
class AudioManager {
  static const MethodChannel _channel = MethodChannel('audio_manager');
  
  // Audio state
  double _volume = 1.0;
  bool _volumeBoostEnabled = false;
  bool _skipSilenceEnabled = false;
  bool _pauseOnHeadsetDisconnect = true;
  bool _requireAudioFocus = true;
  bool _showSystemVolumePanel = true;
  String _preferredAudioLanguage = "";
  
  // Audio session
  int _audioSessionId = 0;
  
  // Event streams
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  final StreamController<bool> _volumeBoostController = StreamController<bool>.broadcast();
  final StreamController<bool> _skipSilenceController = StreamController<bool>.broadcast();
  final StreamController<AudioEvent> _audioEventController = StreamController<AudioEvent>.broadcast();
  
  // Streams
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<bool> get volumeBoostStream => _volumeBoostController.stream;
  Stream<bool> get skipSilenceStream => _skipSilenceController.stream;
  Stream<AudioEvent> get audioEvents => _audioEventController.stream;
  
  // Getters
  double get volume => _volume;
  bool get volumeBoostEnabled => _volumeBoostEnabled;
  bool get skipSilenceEnabled => _skipSilenceEnabled;
  bool get pauseOnHeadsetDisconnect => _pauseOnHeadsetDisconnect;
  bool get requireAudioFocus => _requireAudioFocus;
  bool get showSystemVolumePanel => _showSystemVolumePanel;
  String get preferredAudioLanguage => _preferredAudioLanguage;
  int get audioSessionId => _audioSessionId;
  
  AudioManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVolumeChanged':
        final volume = call.arguments['volume'] as double;
        _volume = volume;
        _volumeController.add(_volume);
        break;
      case 'onHeadsetDisconnected':
        _audioEventController.add(AudioEvent.headsetDisconnected);
        break;
      case 'onHeadsetConnected':
        _audioEventController.add(AudioEvent.headsetConnected);
        break;
      case 'onAudioFocusLost':
        _audioEventController.add(AudioEvent.audioFocusLost);
        break;
      case 'onAudioFocusGained':
        _audioEventController.add(AudioEvent.audioFocusGained);
        break;
      case 'onAudioSessionIdChanged':
        _audioSessionId = call.arguments['sessionId'] as int;
        break;
    }
  }
  
  /// Initialize audio manager with player
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize', {
        'pauseOnHeadsetDisconnect': _pauseOnHeadsetDisconnect,
        'requireAudioFocus': _requireAudioFocus,
        'showSystemVolumePanel': _showSystemVolumePanel,
        'preferredAudioLanguage': _preferredAudioLanguage,
      });
    } catch (e) {
      throw Exception('Failed to initialize audio manager: $e');
    }
  }
  
  /// Set volume (0.0 to 2.0, where >1.0 uses volume boost)
  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {
        'volume': volume.clamp(0.0, 2.0),
        'showVolumePanel': _showSystemVolumePanel,
      });
      _volume = volume;
      _volumeController.add(_volume);
    } catch (e) {
      throw Exception('Failed to set volume: $e');
    }
  }
  
  /// Enable/disable volume boost (allows volume >100%)
  Future<void> setVolumeBoostEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setVolumeBoostEnabled', {'enabled': enabled});
      _volumeBoostEnabled = enabled;
      _volumeBoostController.add(_volumeBoostEnabled);
    } catch (e) {
      throw Exception('Failed to set volume boost: $e');
    }
  }
  
  /// Enable/disable skip silence feature
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSkipSilenceEnabled', {'enabled': enabled});
      _skipSilenceEnabled = enabled;
      _skipSilenceController.add(_skipSilenceEnabled);
    } catch (e) {
      throw Exception('Failed to set skip silence: $e');
    }
  }
  
  /// Set preferred audio language
  Future<void> setPreferredAudioLanguage(String language) async {
    try {
      await _channel.invokeMethod('setPreferredAudioLanguage', {'language': language});
      _preferredAudioLanguage = language;
    } catch (e) {
      throw Exception('Failed to set preferred audio language: $e');
    }
  }
  
  /// Set pause on headset disconnect
  Future<void> setPauseOnHeadsetDisconnect(bool enabled) async {
    try {
      await _channel.invokeMethod('setPauseOnHeadsetDisconnect', {'enabled': enabled});
      _pauseOnHeadsetDisconnect = enabled;
    } catch (e) {
      throw Exception('Failed to set pause on headset disconnect: $e');
    }
  }
  
  /// Set require audio focus
  Future<void> setRequireAudioFocus(bool enabled) async {
    try {
      await _channel.invokeMethod('setRequireAudioFocus', {'enabled': enabled});
      _requireAudioFocus = enabled;
    } catch (e) {
      throw Exception('Failed to set require audio focus: $e');
    }
  }
  
  /// Set show system volume panel
  Future<void> setShowSystemVolumePanel(bool enabled) async {
    try {
      await _channel.invokeMethod('setShowSystemVolumePanel', {'enabled': enabled});
      _showSystemVolumePanel = enabled;
    } catch (e) {
      throw Exception('Failed to set show system volume panel: $e');
    }
  }
  
  /// Increase volume
  Future<void> increaseVolume() async {
    final newVolume = (_volume + 0.1).clamp(0.0, 2.0);
    await setVolume(newVolume);
  }
  
  /// Decrease volume
  Future<void> decreaseVolume() async {
    final newVolume = (_volume - 0.1).clamp(0.0, 2.0);
    await setVolume(newVolume);
  }
  
  /// Get current audio session ID
  Future<int> getAudioSessionId() async {
    try {
      final sessionId = await _channel.invokeMethod('getAudioSessionId');
      _audioSessionId = sessionId as int;
      return _audioSessionId;
    } catch (e) {
      return 0;
    }
  }
  
  /// Request audio focus
  Future<bool> requestAudioFocus() async {
    try {
      final result = await _channel.invokeMethod('requestAudioFocus');
      return result as bool;
    } catch (e) {
      return false;
    }
  }
  
  /// Abandon audio focus
  Future<void> abandonAudioFocus() async {
    try {
      await _channel.invokeMethod('abandonAudioFocus');
    } catch (e) {
      // Ignore errors when abandoning audio focus
    }
  }
  
  /// Switch audio track
  Future<void> switchAudioTrack(int trackIndex) async {
    await _channel.invokeMethod('switchAudioTrack', {
      'trackIndex': trackIndex,
    });
  }
  
  void dispose() {
    _volumeController.close();
    _volumeBoostController.close();
    _skipSilenceController.close();
    _audioEventController.close();
  }
}

/// Audio Events
enum AudioEvent {
  headsetConnected,
  headsetDisconnected,
  audioFocusGained,
  audioFocusLost,
  volumeChanged,
}