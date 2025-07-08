import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/platform/media3_player_controller.dart';

/// Audio Tracks Selection Dialog Widget
class AudioTracksDialog {
  /// Show audio tracks selection dialog
  static Future<void> show(
    BuildContext context,
    Media3PlayerController controller, {
    String title = 'Select Audio Track',
  }) async {
    try {
      // Get available tracks
      final tracks = await controller.getTracks();
      final audioTracks = tracks?['audioTracks'] as List? ?? [];
      
      if (audioTracks.isEmpty) {
        // Show no tracks available dialog
        _showNoTracksDialog(context);
        return;
      }

      // Get current selected track
      final currentIndex = await controller.getCurrentAudioTrackIndex();
      
      // Show track selection dialog
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _AudioTracksList(
          title: title,
          audioTracks: audioTracks,
          currentIndex: currentIndex,
          controller: controller,
        ),
      );
    } catch (e) {
      debugPrint('Error showing audio tracks dialog: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  /// Show no tracks available dialog
  static void _showNoTracksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('No Audio Tracks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No audio tracks are available for this video.'),
            SizedBox(height: 16),
            Text('Possible reasons:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Video file has no audio'),
            Text('• Audio codec not supported'),
            Text('• Track detection timing issue'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text('Failed to load audio tracks:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Audio tracks list widget
class _AudioTracksList extends StatefulWidget {
  final String title;
  final List audioTracks;
  final int? currentIndex;
  final Media3PlayerController controller;

  const _AudioTracksList({
    required this.title,
    required this.audioTracks,
    required this.currentIndex,
    required this.controller,
  });

  @override
  State<_AudioTracksList> createState() => _AudioTracksListState();
}

class _AudioTracksListState extends State<_AudioTracksList> {
  int? _selectedIndex;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _refreshTracks(),
                  icon: Icon(Icons.refresh),
                  tooltip: 'Refresh tracks',
                ),
              ],
            ),
          ),
          
          // Tracks list
          Expanded(
            child: ListView.builder(
              itemCount: widget.audioTracks.length,
              itemBuilder: (context, index) {
                final track = widget.audioTracks[index];
                final isSelected = _selectedIndex == index;
                final isSupported = track['isSupported'] ?? true;
                
                return ListTile(
                  enabled: isSupported && !_isChanging,
                  leading: _isChanging && _selectedIndex == index
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? Theme.of(context).primaryColor : null,
                        ),
                  title: Text(
                    track['name'] ?? 'Track ${index + 1}',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSupported ? null : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (track['language'] != null && track['language'] != 'Unknown')
                        Text('Language: ${track['language']}', 
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (track['codec'] != null && track['codec'] != 'unknown')
                        Text('Codec: ${track['codec']}', 
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (track['bitrate'] != null && track['bitrate'] > 0)
                        Text('Bitrate: ${track['bitrate']} bps', 
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (!isSupported)
                        Text('Not supported', 
                          style: TextStyle(color: Colors.red),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  onTap: isSupported && !_isChanging ? () => _selectTrack(index) : null,
                );
              },
            ),
          ),
          
          // Debug info (only in debug mode)
          if (kDebugMode)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Debug: ${widget.audioTracks.length} tracks found',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectTrack(int index) async {
    if (_isChanging || _selectedIndex == index) return;

    setState(() {
      _isChanging = true;
      _selectedIndex = index;
    });

    try {
      debugPrint('Attempting to select track at index: $index');
      await widget.controller.selectAudioTrack(index);
      
      // Verify the change
      await Future.delayed(Duration(milliseconds: 300));
      final newIndex = await widget.controller.getCurrentAudioTrackIndex();
      
      if (newIndex == index) {
        // Success - close dialog
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio track selected successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Failed to apply
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to change audio track'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error selecting audio track: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChanging = false;
        });
      }
    }
  }

  Future<void> _refreshTracks() async {
    try {
      await widget.controller.refreshTracks();
      // Wait a bit for tracks to refresh
      await Future.delayed(Duration(milliseconds: 1000));
      
      if (mounted) {
        Navigator.pop(context);
        // Re-show dialog with refreshed tracks
        AudioTracksDialog.show(context, widget.controller, title: widget.title);
      }
    } catch (e) {
      debugPrint('Error refreshing tracks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh tracks')),
        );
      }
    }
  }
}