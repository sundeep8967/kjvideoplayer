import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Subtitle Manager for advanced subtitle features
/// Implements NextPlayer's subtitle capabilities
class SubtitleManager {
  static const MethodChannel _channel = MethodChannel('subtitle_manager');
  
  // Subtitle state
  String _preferredSubtitleLanguage = "";
  bool _useSystemCaptionStyle = false;
  String _subtitleTextEncoding = "UTF-8";
  int _subtitleTextSize = 20;
  bool _subtitleBackground = false;
  SubtitleFont _subtitleFont = SubtitleFont.defaultFont;
  bool _subtitleTextBold = true;
  bool _applyEmbeddedStyles = true;
  
  // Current subtitle
  String _currentSubtitleText = "";
  Duration _currentSubtitleStart = Duration.zero;
  Duration _currentSubtitleEnd = Duration.zero;
  
  // Event streams
  final StreamController<String> _subtitleTextController = StreamController<String>.broadcast();
  final StreamController<SubtitleStyle> _subtitleStyleController = StreamController<SubtitleStyle>.broadcast();
  
  // Streams
  Stream<String> get subtitleText => _subtitleTextController.stream;
  Stream<SubtitleStyle> get subtitleStyle => _subtitleStyleController.stream;
  
  // Getters
  String get preferredSubtitleLanguage => _preferredSubtitleLanguage;
  bool get useSystemCaptionStyle => _useSystemCaptionStyle;
  String get subtitleTextEncoding => _subtitleTextEncoding;
  int get subtitleTextSize => _subtitleTextSize;
  bool get subtitleBackground => _subtitleBackground;
  SubtitleFont get subtitleFont => _subtitleFont;
  bool get subtitleTextBold => _subtitleTextBold;
  bool get applyEmbeddedStyles => _applyEmbeddedStyles;
  String get currentSubtitleText => _currentSubtitleText;
  
  SubtitleManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSubtitleTextChanged':
        _currentSubtitleText = call.arguments['text'] as String;
        _currentSubtitleStart = Duration(milliseconds: call.arguments['start'] as int);
        _currentSubtitleEnd = Duration(milliseconds: call.arguments['end'] as int);
        _subtitleTextController.add(_currentSubtitleText);
        break;
      case 'onSubtitleStyleChanged':
        final style = SubtitleStyle.fromMap(call.arguments);
        _subtitleStyleController.add(style);
        break;
    }
  }
  
  /// Initialize subtitle manager
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize', {
        'preferredSubtitleLanguage': _preferredSubtitleLanguage,
        'useSystemCaptionStyle': _useSystemCaptionStyle,
        'subtitleTextEncoding': _subtitleTextEncoding,
        'subtitleTextSize': _subtitleTextSize,
        'subtitleBackground': _subtitleBackground,
        'subtitleFont': _subtitleFont.name,
        'subtitleTextBold': _subtitleTextBold,
        'applyEmbeddedStyles': _applyEmbeddedStyles,
      });
    } catch (e) {
      throw Exception('Failed to initialize subtitle manager: $e');
    }
  }
  
  /// Set preferred subtitle language
  Future<void> setPreferredSubtitleLanguage(String language) async {
    try {
      await _channel.invokeMethod('setPreferredSubtitleLanguage', {'language': language});
      _preferredSubtitleLanguage = language;
    } catch (e) {
      throw Exception('Failed to set preferred subtitle language: $e');
    }
  }
  
  /// Set use system caption style
  Future<void> setUseSystemCaptionStyle(bool use) async {
    try {
      await _channel.invokeMethod('setUseSystemCaptionStyle', {'use': use});
      _useSystemCaptionStyle = use;
    } catch (e) {
      throw Exception('Failed to set use system caption style: $e');
    }
  }
  
  /// Set subtitle text encoding
  Future<void> setSubtitleTextEncoding(String encoding) async {
    try {
      await _channel.invokeMethod('setSubtitleTextEncoding', {'encoding': encoding});
      _subtitleTextEncoding = encoding;
    } catch (e) {
      throw Exception('Failed to set subtitle text encoding: $e');
    }
  }
  
  /// Set subtitle text size
  Future<void> setSubtitleTextSize(int size) async {
    try {
      await _channel.invokeMethod('setSubtitleTextSize', {'size': size});
      _subtitleTextSize = size;
    } catch (e) {
      throw Exception('Failed to set subtitle text size: $e');
    }
  }
  
  /// Set subtitle background
  Future<void> setSubtitleBackground(bool enabled) async {
    try {
      await _channel.invokeMethod('setSubtitleBackground', {'enabled': enabled});
      _subtitleBackground = enabled;
    } catch (e) {
      throw Exception('Failed to set subtitle background: $e');
    }
  }
  
  /// Set subtitle font
  Future<void> setSubtitleFont(SubtitleFont font) async {
    try {
      await _channel.invokeMethod('setSubtitleFont', {'font': font.name});
      _subtitleFont = font;
    } catch (e) {
      throw Exception('Failed to set subtitle font: $e');
    }
  }
  
  /// Set subtitle text bold
  Future<void> setSubtitleTextBold(bool bold) async {
    try {
      await _channel.invokeMethod('setSubtitleTextBold', {'bold': bold});
      _subtitleTextBold = bold;
    } catch (e) {
      throw Exception('Failed to set subtitle text bold: $e');
    }
  }
  
  /// Set apply embedded styles
  Future<void> setApplyEmbeddedStyles(bool apply) async {
    try {
      await _channel.invokeMethod('setApplyEmbeddedStyles', {'apply': apply});
      _applyEmbeddedStyles = apply;
    } catch (e) {
      throw Exception('Failed to set apply embedded styles: $e');
    }
  }
  
  /// Add external subtitle file
  Future<bool> addExternalSubtitle(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Subtitle file does not exist: $filePath');
      }
      
      final result = await _channel.invokeMethod('addExternalSubtitle', {
        'filePath': filePath,
        'encoding': _subtitleTextEncoding,
      });
      return result as bool;
    } catch (e) {
      throw Exception('Failed to add external subtitle: $e');
    }
  }
  
  /// Remove external subtitle
  Future<void> removeExternalSubtitle(String filePath) async {
    try {
      await _channel.invokeMethod('removeExternalSubtitle', {'filePath': filePath});
    } catch (e) {
      throw Exception('Failed to remove external subtitle: $e');
    }
  }
  
  /// Get supported subtitle formats
  Future<List<String>> getSupportedFormats() async {
    try {
      final result = await _channel.invokeMethod('getSupportedFormats');
      return List<String>.from(result);
    } catch (e) {
      return ['srt', 'ass', 'ssa', 'vtt', 'ttml'];
    }
  }
  
  /// Search for local subtitle files
  Future<List<String>> findLocalSubtitles(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('findLocalSubtitles', {'videoPath': videoPath});
      return List<String>.from(result);
    } catch (e) {
      return [];
    }
  }
  
  void dispose() {
    _subtitleTextController.close();
    _subtitleStyleController.close();
  }
}

/// Subtitle Font enum
enum SubtitleFont {
  defaultFont('DEFAULT'),
  serif('SERIF'),
  sansSerif('SANS_SERIF'),
  monospace('MONOSPACE');
  
  const SubtitleFont(this.name);
  final String name;
}

/// Subtitle Style model
class SubtitleStyle {
  final int textSize;
  final String textColor;
  final String backgroundColor;
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool hasBackground;
  
  const SubtitleStyle({
    required this.textSize,
    required this.textColor,
    required this.backgroundColor,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.hasBackground,
  });
  
  factory SubtitleStyle.fromMap(Map<String, dynamic> map) {
    return SubtitleStyle(
      textSize: map['textSize'] ?? 20,
      textColor: map['textColor'] ?? '#FFFFFF',
      backgroundColor: map['backgroundColor'] ?? '#000000',
      fontFamily: map['fontFamily'] ?? 'DEFAULT',
      isBold: map['isBold'] ?? true,
      isItalic: map['isItalic'] ?? false,
      hasBackground: map['hasBackground'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'textSize': textSize,
      'textColor': textColor,
      'backgroundColor': backgroundColor,
      'fontFamily': fontFamily,
      'isBold': isBold,
      'isItalic': isItalic,
      'hasBackground': hasBackground,
    };
  }
}

/// Extension to add missing method to SubtitleManager
extension SubtitleManagerExtension on SubtitleManager {
  /// Switch subtitle track
  Future<void> switchSubtitleTrack(int trackIndex) async {
    await SubtitleManager._channel.invokeMethod('switchSubtitleTrack', {
      'trackIndex': trackIndex,
    });
  }
}