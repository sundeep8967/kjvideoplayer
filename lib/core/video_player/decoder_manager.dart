import 'dart:async';
import 'package:flutter/services.dart';

/// Decoder Manager for advanced video decoding
/// Implements NextPlayer's decoder priority and hardware acceleration
class DecoderManager {
  static const MethodChannel _channel = MethodChannel('decoder_manager');
  
  // Decoder settings
  DecoderPriority _decoderPriority = DecoderPriority.preferDevice;
  bool _useHardwareAcceleration = true;
  bool _allowFallback = true;
  
  // Supported formats
  List<String> _supportedVideoFormats = [];
  List<String> _supportedAudioFormats = [];
  List<String> _supportedSubtitleFormats = [];
  
  // Event streams
  final StreamController<DecoderEvent> _decoderEventController = 
      StreamController<DecoderEvent>.broadcast();
  
  Stream<DecoderEvent> get decoderEvents => _decoderEventController.stream;
  
  // Getters
  DecoderPriority get decoderPriority => _decoderPriority;
  bool get useHardwareAcceleration => _useHardwareAcceleration;
  bool get allowFallback => _allowFallback;
  List<String> get supportedVideoFormats => List.unmodifiable(_supportedVideoFormats);
  List<String> get supportedAudioFormats => List.unmodifiable(_supportedAudioFormats);
  List<String> get supportedSubtitleFormats => List.unmodifiable(_supportedSubtitleFormats);
  
  DecoderManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDecoderChanged':
        final event = DecoderEvent.fromMap(call.arguments);
        _decoderEventController.add(event);
        break;
      case 'onDecoderError':
        final error = call.arguments['error'] as String;
        _decoderEventController.add(DecoderEvent(
          type: DecoderEventType.error,
          message: error,
        ));
        break;
    }
  }
  
  /// Initialize decoder manager
  Future<void> initialize() async {
    try {
      final result = await _channel.invokeMethod('initialize');
      _supportedVideoFormats = List<String>.from(result['videoFormats'] ?? []);
      _supportedAudioFormats = List<String>.from(result['audioFormats'] ?? []);
      _supportedSubtitleFormats = List<String>.from(result['subtitleFormats'] ?? []);
    } catch (e) {
      throw Exception('Failed to initialize decoder manager: $e');
    }
  }
  
  /// Set decoder priority
  Future<void> setDecoderPriority(DecoderPriority priority) async {
    try {
      await _channel.invokeMethod('setDecoderPriority', {'priority': priority.name});
      _decoderPriority = priority;
      
      _decoderEventController.add(DecoderEvent(
        type: DecoderEventType.priorityChanged,
        message: 'Decoder priority changed to ${priority.name}',
        data: {'priority': priority.name},
      ));
    } catch (e) {
      throw Exception('Failed to set decoder priority: $e');
    }
  }
  
  /// Set hardware acceleration
  Future<void> setHardwareAcceleration(bool enabled) async {
    try {
      await _channel.invokeMethod('setHardwareAcceleration', {'enabled': enabled});
      _useHardwareAcceleration = enabled;
      
      _decoderEventController.add(DecoderEvent(
        type: DecoderEventType.hardwareAccelerationChanged,
        message: 'Hardware acceleration ${enabled ? 'enabled' : 'disabled'}',
        data: {'enabled': enabled},
      ));
    } catch (e) {
      throw Exception('Failed to set hardware acceleration: $e');
    }
  }
  
  /// Set decoder fallback
  Future<void> setAllowFallback(bool allow) async {
    try {
      await _channel.invokeMethod('setAllowFallback', {'allow': allow});
      _allowFallback = allow;
    } catch (e) {
      throw Exception('Failed to set decoder fallback: $e');
    }
  }
  
  /// Get decoder info for a video file
  Future<DecoderInfo> getDecoderInfo(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('getDecoderInfo', {'videoPath': videoPath});
      return DecoderInfo.fromMap(result);
    } catch (e) {
      throw Exception('Failed to get decoder info: $e');
    }
  }
  
  /// Check if format is supported
  bool isVideoFormatSupported(String format) {
    return _supportedVideoFormats.contains(format.toLowerCase());
  }
  
  bool isAudioFormatSupported(String format) {
    return _supportedAudioFormats.contains(format.toLowerCase());
  }
  
  bool isSubtitleFormatSupported(String format) {
    return _supportedSubtitleFormats.contains(format.toLowerCase());
  }
  
  /// Get recommended decoder for video
  Future<String> getRecommendedDecoder(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('getRecommendedDecoder', {'videoPath': videoPath});
      return result['decoder'] as String;
    } catch (e) {
      throw Exception('Failed to get recommended decoder: $e');
    }
  }
  
  void dispose() {
    _decoderEventController.close();
  }
}

/// Decoder Priority enum
enum DecoderPriority {
  preferDevice,
  preferSoftware,
  deviceOnly,
  softwareOnly;
  
  String get name => toString().split('.').last;
}

/// Decoder Event Types
enum DecoderEventType {
  priorityChanged,
  hardwareAccelerationChanged,
  decoderChanged,
  error,
}

/// Decoder Event
class DecoderEvent {
  final DecoderEventType type;
  final String message;
  final Map<String, dynamic>? data;
  
  const DecoderEvent({
    required this.type,
    required this.message,
    this.data,
  });
  
  factory DecoderEvent.fromMap(Map<String, dynamic> map) {
    return DecoderEvent(
      type: DecoderEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DecoderEventType.error,
      ),
      message: map['message'] ?? '',
      data: map['data'],
    );
  }
  
  @override
  String toString() => 'DecoderEvent(type: $type, message: $message, data: $data)';
}

/// Decoder Info
class DecoderInfo {
  final String videoDecoder;
  final String audioDecoder;
  final bool hardwareAccelerated;
  final String videoFormat;
  final String audioFormat;
  final Map<String, dynamic> capabilities;
  
  const DecoderInfo({
    required this.videoDecoder,
    required this.audioDecoder,
    required this.hardwareAccelerated,
    required this.videoFormat,
    required this.audioFormat,
    required this.capabilities,
  });
  
  factory DecoderInfo.fromMap(Map<String, dynamic> map) {
    return DecoderInfo(
      videoDecoder: map['videoDecoder'] ?? '',
      audioDecoder: map['audioDecoder'] ?? '',
      hardwareAccelerated: map['hardwareAccelerated'] ?? false,
      videoFormat: map['videoFormat'] ?? '',
      audioFormat: map['audioFormat'] ?? '',
      capabilities: Map<String, dynamic>.from(map['capabilities'] ?? {}),
    );
  }
  
  @override
  String toString() {
    return 'DecoderInfo(videoDecoder: $videoDecoder, audioDecoder: $audioDecoder, '
           'hardwareAccelerated: $hardwareAccelerated, videoFormat: $videoFormat, '
           'audioFormat: $audioFormat, capabilities: $capabilities)';
  }
}