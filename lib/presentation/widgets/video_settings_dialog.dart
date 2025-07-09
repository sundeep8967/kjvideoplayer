import 'package:flutter/material.dart';
import '../../core/platform/media3_player_controller.dart';

/// Clean Video Player Settings Dialog
class VideoSettingsDialog {
  static Future<void> show(
    BuildContext context,
    Media3PlayerController? controller, {
    required double currentSpeed,
    required double currentVolume,
    required bool isMuted,
    required Function(double) onSpeedChanged,
    required Function(double) onVolumeChanged,
    required Function(bool) onMuteChanged,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VideoSettingsPanel(
        controller: controller,
        currentSpeed: currentSpeed,
        currentVolume: currentVolume,
        isMuted: isMuted,
        onSpeedChanged: onSpeedChanged,
        onVolumeChanged: onVolumeChanged,
        onMuteChanged: onMuteChanged,
      ),
    );
  }
}

class _VideoSettingsPanel extends StatefulWidget {
  final Media3PlayerController? controller;
  final double currentSpeed;
  final double currentVolume;
  final bool isMuted;
  final Function(double) onSpeedChanged;
  final Function(double) onVolumeChanged;
  final Function(bool) onMuteChanged;

  const _VideoSettingsPanel({
    required this.controller,
    required this.currentSpeed,
    required this.currentVolume,
    required this.isMuted,
    required this.onSpeedChanged,
    required this.onVolumeChanged,
    required this.onMuteChanged,
  });

  @override
  State<_VideoSettingsPanel> createState() => _VideoSettingsPanelState();
}

class _VideoSettingsPanelState extends State<_VideoSettingsPanel> {
  late double _speed;
  late double _volume;
  late bool _muted;

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
    _volume = widget.currentVolume;
    _muted = widget.isMuted;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
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
                  border: Border(bottom: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Video Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Settings content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildPlaybackSpeedSection(),
                    SizedBox(height: 24),
                    _buildAudioSection(),
                    SizedBox(height: 24),
                    _buildVideoQualitySection(),
                    SizedBox(height: 24),
                    _buildInterfaceSection(),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaybackSpeedSection() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Playback Speed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: speeds.map((speed) {
            final isSelected = (_speed - speed).abs() < 0.01;
            return ChoiceChip(
              label: Text('${speed}x'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _speed = speed;
                  });
                  widget.onSpeedChanged(speed);
                }
              },
              selectedColor: Colors.red,
              backgroundColor: Colors.grey[700],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        // Volume control
        Row(
          children: [
            Icon(
              _muted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: _muted ? 0 : _volume,
                onChanged: _muted ? null : (value) {
                  setState(() {
                    _volume = value;
                  });
                  widget.onVolumeChanged(value);
                },
                activeColor: Colors.red,
                inactiveColor: Colors.white30,
              ),
            ),
            SizedBox(width: 12),
            Text(
              '${(_muted ? 0 : _volume * 100).round()}%',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        
        // Mute toggle
        SwitchListTile(
          title: Text('Mute', style: TextStyle(color: Colors.white)),
          value: _muted,
          onChanged: (value) {
            setState(() {
              _muted = value;
            });
            widget.onMuteChanged(value);
          },
          activeColor: Colors.red,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildVideoQualitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video Quality',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        ListTile(
          leading: Icon(Icons.high_quality, color: Colors.white),
          title: Text('Auto Quality', style: TextStyle(color: Colors.white)),
          subtitle: Text('Adjust based on connection', style: TextStyle(color: Colors.white70)),
          trailing: Icon(Icons.chevron_right, color: Colors.white54),
          contentPadding: EdgeInsets.zero,
          onTap: () {
            // TODO: Implement quality selection
            _showSnackBar('Quality selection coming soon');
          },
        ),
        
        ListTile(
          leading: Icon(Icons.aspect_ratio, color: Colors.white),
          title: Text('Aspect Ratio', style: TextStyle(color: Colors.white)),
          subtitle: Text('Fit to screen', style: TextStyle(color: Colors.white70)),
          trailing: Icon(Icons.chevron_right, color: Colors.white54),
          contentPadding: EdgeInsets.zero,
          onTap: () {
            // TODO: Implement aspect ratio selection
            _showSnackBar('Aspect ratio options coming soon');
          },
        ),
      ],
    );
  }

  Widget _buildInterfaceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interface',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        ListTile(
          leading: Icon(Icons.touch_app, color: Colors.white),
          title: Text('Gesture Controls', style: TextStyle(color: Colors.white)),
          subtitle: Text('Swipe to adjust brightness/volume', style: TextStyle(color: Colors.white70)),
          trailing: Switch(
            value: true, // TODO: Make this configurable
            onChanged: (value) {
              _showSnackBar('Gesture controls ${value ? 'enabled' : 'disabled'}');
            },
            activeColor: Colors.red,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        
        ListTile(
          leading: Icon(Icons.timer, color: Colors.white),
          title: Text('Auto-hide Controls', style: TextStyle(color: Colors.white)),
          subtitle: Text('Hide after 3 seconds', style: TextStyle(color: Colors.white70)),
          trailing: Icon(Icons.chevron_right, color: Colors.white54),
          contentPadding: EdgeInsets.zero,
          onTap: () {
            _showSnackBar('Auto-hide timing options coming soon');
          },
        ),
        
        ListTile(
          leading: Icon(Icons.info_outline, color: Colors.white),
          title: Text('About Player', style: TextStyle(color: Colors.white)),
          subtitle: Text('Version info and credits', style: TextStyle(color: Colors.white70)),
          trailing: Icon(Icons.chevron_right, color: Colors.white54),
          contentPadding: EdgeInsets.zero,
          onTap: () {
            _showAboutDialog();
          },
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('About Video Player', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KJ Video Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Version: 1.0.0', style: TextStyle(color: Colors.white70)),
            Text('Built with Flutter & Media3', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text('Features:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('• Hardware acceleration', style: TextStyle(color: Colors.white70)),
            Text('• Multiple audio tracks', style: TextStyle(color: Colors.white70)),
            Text('• Subtitle support', style: TextStyle(color: Colors.white70)),
            Text('• AI speech recognition', style: TextStyle(color: Colors.white70)),
            Text('• Gesture controls', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}