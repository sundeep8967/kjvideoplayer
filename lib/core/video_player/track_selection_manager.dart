import 'dart:async';

/// Track Selection Manager for Audio and Subtitle tracks
/// Implements NextPlayer's advanced track management
class TrackSelectionManager {
  final List<AudioTrack> _audioTracks = [];
  final List<SubtitleTrack> _subtitleTracks = [];
  
  int _selectedAudioTrack = -1;
  int _selectedSubtitleTrack = -1;
  
  final StreamController<List<AudioTrack>> _audioTracksController = 
      StreamController<List<AudioTrack>>.broadcast();
  final StreamController<List<SubtitleTrack>> _subtitleTracksController = 
      StreamController<List<SubtitleTrack>>.broadcast();
  final StreamController<int> _selectedAudioTrackController = 
      StreamController<int>.broadcast();
  final StreamController<int> _selectedSubtitleTrackController = 
      StreamController<int>.broadcast();
  
  // Streams
  Stream<List<AudioTrack>> get audioTracks => _audioTracksController.stream;
  Stream<List<SubtitleTrack>> get subtitleTracks => _subtitleTracksController.stream;
  Stream<int> get selectedAudioTrack => _selectedAudioTrackController.stream;
  Stream<int> get selectedSubtitleTrack => _selectedSubtitleTrackController.stream;
  
  // Getters
  List<AudioTrack> get currentAudioTracks => List.unmodifiable(_audioTracks);
  List<SubtitleTrack> get currentSubtitleTracks => List.unmodifiable(_subtitleTracks);
  int get currentSelectedAudioTrack => _selectedAudioTrack;
  int get currentSelectedSubtitleTrack => _selectedSubtitleTrack;
  
  /// Update available audio tracks
  void updateAudioTracks(List<AudioTrack> tracks) {
    _audioTracks.clear();
    _audioTracks.addAll(tracks);
    _audioTracksController.add(currentAudioTracks);
  }
  
  /// Update available subtitle tracks
  void updateSubtitleTracks(List<SubtitleTrack> tracks) {
    _subtitleTracks.clear();
    _subtitleTracks.addAll(tracks);
    _subtitleTracksController.add(currentSubtitleTracks);
  }
  
  /// Select audio track by index
  void selectAudioTrack(int index) {
    if (index >= -1 && index < _audioTracks.length) {
      _selectedAudioTrack = index;
      _selectedAudioTrackController.add(_selectedAudioTrack);
    }
  }
  
  /// Select subtitle track by index
  void selectSubtitleTrack(int index) {
    if (index >= -1 && index < _subtitleTracks.length) {
      _selectedSubtitleTrack = index;
      _selectedSubtitleTrackController.add(_selectedSubtitleTrack);
    }
  }
  
  /// Add external subtitle track
  void addExternalSubtitle(String path, String name) {
    final track = SubtitleTrack(
      index: _subtitleTracks.length,
      name: name,
      language: 'external',
      isExternal: true,
      path: path,
    );
    _subtitleTracks.add(track);
    _subtitleTracksController.add(currentSubtitleTracks);
  }
  
  /// Get audio track by index
  AudioTrack? getAudioTrack(int index) {
    if (index >= 0 && index < _audioTracks.length) {
      return _audioTracks[index];
    }
    return null;
  }
  
  /// Get subtitle track by index
  SubtitleTrack? getSubtitleTrack(int index) {
    if (index >= 0 && index < _subtitleTracks.length) {
      return _subtitleTracks[index];
    }
    return null;
  }
  
  void dispose() {
    _audioTracksController.close();
    _subtitleTracksController.close();
    _selectedAudioTrackController.close();
    _selectedSubtitleTrackController.close();
  }
}

/// Audio Track Model
class AudioTrack {
  final int index;
  final String name;
  final String language;
  final String codec;
  final int bitrate;
  final int channels;
  final int sampleRate;
  
  const AudioTrack({
    required this.index,
    required this.name,
    required this.language,
    required this.codec,
    required this.bitrate,
    required this.channels,
    required this.sampleRate,
  });
  
  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      index: map['index'] ?? 0,
      name: map['name'] ?? 'Unknown',
      language: map['language'] ?? 'und',
      codec: map['codec'] ?? 'unknown',
      bitrate: map['bitrate'] ?? 0,
      channels: map['channels'] ?? 2,
      sampleRate: map['sampleRate'] ?? 44100,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'name': name,
      'language': language,
      'codec': codec,
      'bitrate': bitrate,
      'channels': channels,
      'sampleRate': sampleRate,
    };
  }
  
  @override
  String toString() => '$name ($language)';
}

/// Subtitle Track Model
class SubtitleTrack {
  final int index;
  final String name;
  final String language;
  final bool isExternal;
  final String? path;
  final String? format;
  
  const SubtitleTrack({
    required this.index,
    required this.name,
    required this.language,
    this.isExternal = false,
    this.path,
    this.format,
  });
  
  factory SubtitleTrack.fromMap(Map<String, dynamic> map) {
    return SubtitleTrack(
      index: map['index'] ?? 0,
      name: map['name'] ?? 'Unknown',
      language: map['language'] ?? 'und',
      isExternal: map['isExternal'] ?? false,
      path: map['path'],
      format: map['format'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'name': name,
      'language': language,
      'isExternal': isExternal,
      'path': path,
      'format': format,
    };
  }
  
  @override
  String toString() => '$name ($language)';
}