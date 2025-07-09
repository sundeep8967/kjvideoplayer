import 'package:flutter/material.dart';
import '../../core/platform/media3_player_controller.dart';

/// Subtitle Tracks Selection Dialog Widget - Fixed Overflow
class SubtitleTracksDialog {
  /// Show subtitle tracks selection dialog
  static Future<void> show(
    BuildContext context,
    Media3PlayerController controller, {
    String title = 'Select Subtitle Track',
  }) async {
    try {
      // Get available tracks
      final tracks = await controller.getTracks();
      final subtitleTracks = tracks?['subtitleTracks'] as List? ?? [];
      
      // Show track selection dialog
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _SubtitleTracksList(
          title: title,
          subtitleTracks: subtitleTracks,
          controller: controller,
        ),
      );
    } catch (e) {
      debugPrint('Error showing subtitle tracks dialog: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text('Failed to load subtitle tracks:\n$error'),
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

/// Subtitle tracks list widget - Fixed for overflow
class _SubtitleTracksList extends StatefulWidget {
  final String title;
  final List subtitleTracks;
  final Media3PlayerController controller;

  const _SubtitleTracksList({
    required this.title,
    required this.subtitleTracks,
    required this.controller,
  });

  @override
  State<_SubtitleTracksList> createState() => _SubtitleTracksListState();
}

class _SubtitleTracksListState extends State<_SubtitleTracksList> {
  bool _isChanging = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
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
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.subtitles, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Subtitle tracks list
              Expanded(
                child: widget.subtitleTracks.isEmpty
                    ? _buildNoSubtitlesMessage()
                    : _buildSubtitlesList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoSubtitlesMessage() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subtitles_off,
            size: 64,
            color: Colors.white54,
          ),
          SizedBox(height: 16),
          Text(
            'No Subtitle Tracks Available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'This video does not contain any subtitle tracks.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          // Still show disable option even if no tracks
          _buildDisableOption(),
        ],
      ),
    );
  }

  Widget _buildSubtitlesList(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Disable subtitles option (always first)
        _buildDisableOption(),
        
        if (widget.subtitleTracks.isNotEmpty) ...[
          Divider(color: Colors.white24),
          
          // Available subtitle tracks
          ...widget.subtitleTracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            return _buildSubtitleTrackTile(index, track);
          }).toList(),
        ],
        
        SizedBox(height: 20), // Bottom padding
      ],
    );
  }

  Widget _buildDisableOption() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.subtitles_off, color: Colors.white),
        title: Text(
          'Disable Subtitles',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Turn off all subtitles',
          style: TextStyle(color: Colors.white70),
        ),
        trailing: _isChanging
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.chevron_right, color: Colors.white54),
        onTap: _isChanging ? null : () => _selectSubtitleTrack(-1),
      ),
    );
  }

  Widget _buildSubtitleTrackTile(int index, dynamic track) {
    final trackName = track['name'] ?? 'Subtitle ${index + 1}';
    final language = track['language'] ?? 'Unknown';
    final isSupported = track['isSupported'] ?? true;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSupported 
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.subtitles,
          color: isSupported ? Colors.white : Colors.white54,
        ),
        title: Text(
          trackName,
          style: TextStyle(
            color: isSupported ? Colors.white : Colors.white54,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          language,
          style: TextStyle(
            color: isSupported ? Colors.white70 : Colors.white38,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: _isChanging
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.chevron_right, 
                color: isSupported ? Colors.white54 : Colors.white24,
              ),
        onTap: _isChanging || !isSupported 
            ? null 
            : () => _selectSubtitleTrack(index),
      ),
    );
  }

  Future<void> _selectSubtitleTrack(int index) async {
    if (_isChanging) return;
    
    setState(() {
      _isChanging = true;
    });

    try {
      if (index == -1) {
        // Disable subtitles
        await widget.controller.disableSubtitle();
        debugPrint('Subtitles disabled');
      } else {
        // Select subtitle track
        await widget.controller.setSubtitleTrack(index);
        debugPrint('Selected subtitle track at index: $index');
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              index == -1 
                  ? 'Subtitles disabled' 
                  : 'Subtitle track selected'
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error selecting subtitle track: $e');
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
}