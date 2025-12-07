import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class PlayerSettingsPanel extends StatefulWidget {
  final Animation<double> animation;
  final List<Map<String, dynamic>> videoTracks;
  final List<Map<String, dynamic>> audioTracks;
  final List<Map<String, dynamic>> subtitleTracks;
  final VoidCallback onClose;
  final Function(int index) onAudioTrackSelected;
  final Function(int index) onSubtitleTrackSelected;
  final Function(int index)? onVideoTrackSelected;
  final double currentSpeed;
  final Function(double) onSpeedChanged;
  final VoidCallback onRotate;

  const PlayerSettingsPanel({
    super.key,
    required this.animation,
    required this.videoTracks,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.onClose,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
    this.onVideoTrackSelected,
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.onRotate,
  });

  @override
  State<PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

enum _SettingsView { main, audio, subtitles, speed }

class _PlayerSettingsPanelState extends State<PlayerSettingsPanel> {
  _SettingsView _currentView = _SettingsView.main;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return Stack(
          children: [
            // Transparent dismiss layer
            GestureDetector(
              onTap: () {
                // Debounce dismiss to prevent accidental immediate closing
                if (widget.animation.status == AnimationStatus.completed) {
                  widget.onClose();
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // Floating Menu
            Positioned(
              bottom: 80, // Anchored above the bottom bar
              right: 20,
              child: FadeTransition(
                opacity: widget.animation,
                child: ScaleTransition(
                  scale: widget.animation,
                  alignment: Alignment.bottomRight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 280,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                        ),
                        child: SingleChildScrollView(
                          child: _buildCurrentView(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case _SettingsView.main:
        return _buildMainMenu();
      case _SettingsView.audio:
        return _buildAudioMenu();
      case _SettingsView.subtitles:
        return _buildSubtitlesMenu();
      case _SettingsView.speed:
        return _buildSpeedMenu();
    }
  }

  Widget _buildMainMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuItem(
          title: 'Playback Speed',
          icon: CupertinoIcons.speedometer,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.currentSpeed}x', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
            ],
          ),
          onTap: () => setState(() => _currentView = _SettingsView.speed),
        ),
        _buildDivider(),
        _buildMenuItem(
          title: 'Subtitles',
          icon: CupertinoIcons.captions_bubble,
          trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
          onTap: () => setState(() => _currentView = _SettingsView.subtitles),
        ),
        _buildDivider(),
        _buildMenuItem(
          title: 'Audio Track',
          icon: CupertinoIcons.music_note_2,
          trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
          onTap: () => setState(() => _currentView = _SettingsView.audio),
        ),
      ],
    );
  }

  Widget _buildSpeedMenu() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader('Playback Speed'),
        ...speeds.map((speed) => _buildSelectionItem(
          title: '${speed}x',
          isSelected: widget.currentSpeed == speed,
          onTap: () {
            widget.onSpeedChanged(speed);
            setState(() => _currentView = _SettingsView.main);
          },
        )),
      ],
    );
  }

  Widget _buildSubtitlesMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader('Subtitles'),
        if (widget.subtitleTracks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No subtitles available', style: TextStyle(color: Colors.white54)),
          )
        else
          ...widget.subtitleTracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            final isSelected = track['isSelected'] == true;
            return _buildSelectionItem(
              title: track['name'] ?? 'Unknown',
              subtitle: track['language'],
              isSelected: isSelected,
              onTap: () {
                widget.onSubtitleTrackSelected(index);
                setState(() => _currentView = _SettingsView.main);
              },
            );
          }),
      ],
    );
  }

  Widget _buildAudioMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader('Audio Track'),
        if (widget.audioTracks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No audio tracks available', style: TextStyle(color: Colors.white54)),
          )
        else
          ...widget.audioTracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            final isSelected = track['isSelected'] == true;
            return _buildSelectionItem(
              title: track['name'] ?? 'Unknown',
              subtitle: track['language'],
              isSelected: isSelected,
              onTap: () {
                widget.onAudioTrackSelected(index);
                setState(() => _currentView = _SettingsView.main);
              },
            );
          }),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 20),
            onPressed: () => setState(() => _currentView = _SettingsView.main),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: '.SF Pro Text',
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionItem({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(CupertinoIcons.checkmark_alt, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(left: 48), // Indent divider
    );
  }
}
