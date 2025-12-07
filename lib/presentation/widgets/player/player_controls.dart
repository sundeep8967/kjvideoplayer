import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/platform/media3_player_controller.dart';
import '../subtitle_tracks_dialog.dart';
import '../video_settings_dialog.dart';

// Enum for Zoom Modes
enum ZoomMode { fit, stretch, zoomToFill, custom }

class PlayerTopControls extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final double currentSpeed;
  final bool showSpeedMenu;
  final VoidCallback onSpeedMenuToggle;
  final VoidCallback onRotate;
  final VoidCallback onSubtitles;
  final VoidCallback onAudioTracks;
  final VoidCallback onSettings;
  final VoidCallback onCycleZoom;
  final ZoomMode currentZoomMode;
  final VoidCallback onPip;

  const PlayerTopControls({
    super.key,
    required this.title,
    required this.onBack,
    required this.currentSpeed,
    required this.showSpeedMenu,
    required this.onSpeedMenuToggle,
    required this.onRotate,
    required this.onSubtitles,
    required this.onAudioTracks,
    required this.onSettings,
    required this.onCycleZoom,
    required this.currentZoomMode,
    required this.onPip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Left Grouped Pill (Close, Fit/Stretch, PiP, Rotate)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                      onPressed: onBack,
                      tooltip: 'Close',
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                    ),
                    // Divider
                    Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2)),
                    // Fit/Stretch Toggle
                    IconButton(
                      icon: Icon(_getZoomIcon(), color: Colors.white, size: 20),
                      onPressed: onCycleZoom,
                      tooltip: 'Zoom: ${_getZoomLabel()}',
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                    ),
                    // Divider
                    Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2)),
                    // PiP
                    IconButton(
                      icon: const Icon(CupertinoIcons.rectangle_on_rectangle, color: Colors.white, size: 20),
                      onPressed: onPip,
                      tooltip: 'Picture in Picture',
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                    ),
                    // Divider
                    Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2)),
                    // Rotate
                    IconButton(
                      icon: const Icon(CupertinoIcons.rotate_right, color: Colors.white, size: 20),
                      onPressed: onRotate,
                      tooltip: 'Rotate',
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Volume HUD (Floating Pill)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.volume_up, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.7, // Static 70% for UI match
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getZoomIcon() {
    switch (currentZoomMode) {
      case ZoomMode.fit:
        return CupertinoIcons.arrow_up_left_arrow_down_right; // Arrows pointing out (expand)
      case ZoomMode.stretch:
        return CupertinoIcons.arrow_down_right_arrow_up_left; // Arrows pointing in (compress) - or similar
      case ZoomMode.zoomToFill:
        return CupertinoIcons.crop;
      case ZoomMode.custom:
        return CupertinoIcons.zoom_in;
    }
  }

  String _getZoomLabel() {
    switch (currentZoomMode) {
      case ZoomMode.fit:
        return 'Fit';
      case ZoomMode.stretch:
        return 'Stretch';
      case ZoomMode.zoomToFill:
        return 'Crop';
      case ZoomMode.custom:
        return 'Custom';
    }
  }
}

class PlayerCenterControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekForward;
  final VoidCallback onSeekBackward;

  const PlayerCenterControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekForward,
    required this.onSeekBackward,
  });

  @override
  Widget build(BuildContext context) {
    // Hidden center controls as per reference image, but keeping gesture area if needed
    // or just return empty container since gestures are handled by the parent stack or PlayerGestureControls
    return const SizedBox.shrink();
  }
}

class PlayerBottomControls extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Function(Duration) onSeek;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekForward; // Added for skip button
  final VoidCallback onSettings; // Added for settings button

  const PlayerBottomControls({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekForward,
    required this.onSettings,
  });

  @override
  State<PlayerBottomControls> createState() => _PlayerBottomControlsState();
}

class _PlayerBottomControlsState extends State<PlayerBottomControls> {
  Duration? _draggingPosition;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _draggingPosition ?? widget.position;
    final duration = widget.duration;
    final remaining = duration - position;

    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: GestureDetector(
              onTap: () {}, // Consume taps on the background
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                // Skip Backward 15s
                GestureDetector(
                  onTap: () {
                    // Assuming onSeekForward is actually a generic seek or we need a backward callback
                    // Since we only have onSeekForward passed in the widget, we might need to update the widget definition
                    // But looking at previous code, we had onSeekBackward in CenterControls.
                    // Let's check if we can use onSeek with calculation or if we need to add onSeekBackward to this widget.
                    // For now, I'll use the onSeek callback with current position - 15s.
                    final newPos = position - const Duration(seconds: 15);
                    widget.onSeek(newPos < Duration.zero ? Duration.zero : newPos);
                  },
                  child: const Icon(
                    CupertinoIcons.gobackward_15,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 20),

                // Play/Pause
                GestureDetector(
                  onTap: widget.onPlayPause,
                  child: Icon(
                    widget.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                
                // Skip Forward 15s
                GestureDetector(
                  onTap: widget.onSeekForward,
                  child: const Icon(
                    CupertinoIcons.goforward_15,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 20),
                
                // Current Time
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: '.SF Pro Text',
                  ),
                ),
                const SizedBox(width: 12),
                
                // Slider
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbColor: Colors.white,
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                          elevation: 0,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: (duration.inMilliseconds > 0)
                            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (duration.inMilliseconds > 0)
                            ? (value) {
                                final newPos = Duration(milliseconds: (value * duration.inMilliseconds).round());
                                setState(() {
                                  _draggingPosition = newPos;
                                });
                                widget.onSeekStart();
                              }
                            : null,
                        onChangeEnd: (duration.inMilliseconds > 0)
                            ? (value) {
                                final seekTo = Duration(milliseconds: (value * duration.inMilliseconds).round());
                                widget.onSeek(seekTo);
                                setState(() {
                                  _draggingPosition = null;
                                });
                                widget.onSeekEnd();
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Remaining Time
                Text(
                  "-${_formatDuration(remaining)}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: '.SF Pro Text',
                  ),
                ),
                const SizedBox(width: 16),
                
                // Settings (Three Dots)
                GestureDetector(
                  onTap: widget.onSettings,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8), // Increase hit area
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class PlayerVolumeSlider extends StatelessWidget {
  final double currentVolume;
  final Function(double) onVolumeChanged;

  const PlayerVolumeSlider({
    super.key,
    required this.currentVolume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 20,
      child: Container(
        height: 180,
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                currentVolume > 0.5 ? Icons.volume_up_rounded :
                currentVolume > 0 ? Icons.volume_down_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbColor: const Color(0xFF007AFF),
                    activeTrackColor: const Color(0xFF007AFF),
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: currentVolume,
                    onChanged: onVolumeChanged,
                    min: 0.0,
                    max: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(currentVolume * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerSpeedMenu extends StatelessWidget {
  final double currentSpeed;
  final Function(double) onSpeedChanged;

  const PlayerSpeedMenu({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Playback Speed',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildSpeedOption(context, 0.5),
            _buildSpeedOption(context, 0.75),
            _buildSpeedOption(context, 1.0),
            _buildSpeedOption(context, 1.25),
            _buildSpeedOption(context, 1.5),
            _buildSpeedOption(context, 2.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(BuildContext context, double speed) {
    final isSelected = currentSpeed == speed;
    return GestureDetector(
      onTap: () => onSpeedChanged(speed),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              '${speed}x',
              style: TextStyle(
                color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(
                Icons.check,
                color: Color(0xFF007AFF),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
