import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerGestureControls extends StatefulWidget {
  final Widget child;
  final double currentVolume;
  final double currentBrightness;
  final double currentScale;
  final Function(double volume) onVolumeChanged;
  final Function(double brightness) onBrightnessChanged;
  final Function(double scale, Offset pan) onZoomChanged;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  // Actually parent uses onTap for _toggleControls.

  const PlayerGestureControls({
    super.key,
    required this.child,
    required this.currentVolume,
    required this.currentBrightness,
    required this.currentScale,
    required this.onVolumeChanged,
    required this.onBrightnessChanged,
    required this.onZoomChanged,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  State<PlayerGestureControls> createState() => _PlayerGestureControlsState();
}

class _PlayerGestureControlsState extends State<PlayerGestureControls> {
  // Gesture state
  bool _isMultiFingerGesture = false;
  bool _isSingleFingerSwipe = false;
  Offset? _swipeStartPosition;
  
  // Zoom state
  double _baseScaleFactor = 1.0;
  Offset _panOffset = Offset.zero;
  bool _showZoomIndicator = false;
  Timer? _zoomIndicatorTimer;

  // Volume/Brightness state
  bool _isVolumeAdjusting = false;
  bool _isBrightnessAdjusting = false;
  
  // Local values to update UI immediately before parent updates
  late double _localVolume;
  late double _localBrightness;

  @override
  void initState() {
    super.initState();
    _localVolume = widget.currentVolume;
    _localBrightness = widget.currentBrightness;
  }

  @override
  void didUpdateWidget(PlayerGestureControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isVolumeAdjusting) {
      _localVolume = widget.currentVolume;
    }
    if (!_isBrightnessAdjusting) {
      _localBrightness = widget.currentBrightness;
    }
  }

  @override
  void dispose() {
    _zoomIndicatorTimer?.cancel();
    super.dispose();
  }

  void _onCombinedScaleStart(ScaleStartDetails details) {
    if (details.pointerCount > 1) {
      _isMultiFingerGesture = true;
      _isSingleFingerSwipe = false;
      _baseScaleFactor = widget.currentScale;
      _showZoomIndicatorWithTimer();
    } else {
      _isMultiFingerGesture = false;
      _isSingleFingerSwipe = false;
      _swipeStartPosition = details.focalPoint;
    }
  }

  void _onCombinedScaleUpdate(ScaleUpdateDetails details) {
    if (_isMultiFingerGesture && details.pointerCount > 1) {
      _handleZoomUpdate(details);
    } else if (!_isMultiFingerGesture && details.pointerCount == 1) {
      _handleSwipeUpdate(details);
    }
  }

  void _handleZoomUpdate(ScaleUpdateDetails details) {
    _showZoomIndicatorWithTimer();
    
    final newScale = (_baseScaleFactor * details.scale).clamp(0.5, 3.0);
    
    Offset newPan = _panOffset;
    if (newScale > 1.1) {
      final screenSize = MediaQuery.of(context).size;
      final scaleDifference = newScale - 1.0;
      final maxX = (screenSize.width * scaleDifference) / 2;
      final maxY = (screenSize.height * scaleDifference) / 2;
      
      newPan += details.focalPointDelta;
      newPan = Offset(
        newPan.dx.clamp(-maxX, maxX),
        newPan.dy.clamp(-maxY, maxY),
      );
    } else {
      newPan = Offset.zero;
    }
    
    _panOffset = newPan; // Update local pan
    widget.onZoomChanged(newScale, newPan);
  }

  void _handleSwipeUpdate(ScaleUpdateDetails details) {
    if (_swipeStartPosition != null) {
      final deltaY = (details.focalPoint.dy - _swipeStartPosition!.dy).abs();
      final deltaX = (details.focalPoint.dx - _swipeStartPosition!.dx).abs();
      
      if (deltaY > 10 && deltaY > deltaX) {
        _isSingleFingerSwipe = true;
        final isRightSide = _swipeStartPosition!.dx > MediaQuery.of(context).size.width / 2;
        
        if (isRightSide) {
          if (!_isVolumeAdjusting) {
            setState(() => _isVolumeAdjusting = true);
            HapticFeedback.selectionClick();
          }
        } else {
          if (!_isBrightnessAdjusting) {
            setState(() => _isBrightnessAdjusting = true);
            HapticFeedback.selectionClick();
          }
        }
        
        // Calculate delta
        final screenHeight = MediaQuery.of(context).size.height;
        final sensitivity = screenHeight * 0.4;
        final valueDelta = -details.focalPointDelta.dy / sensitivity;
        
        if (valueDelta.abs() < 0.005) return;
        
        if (_isVolumeAdjusting) {
          _adjustVolume(valueDelta);
        } else if (_isBrightnessAdjusting) {
          _adjustBrightness(valueDelta);
        }
      }
    }
  }

  void _adjustVolume(double delta) {
    final newVolume = (_localVolume + delta).clamp(0.0, 1.0);
    if ((newVolume - _localVolume).abs() < 0.01) return;
    
    setState(() => _localVolume = newVolume);
    widget.onVolumeChanged(newVolume);
  }

  void _adjustBrightness(double delta) {
    final newBrightness = (_localBrightness + delta).clamp(0.0, 1.0);
    if ((newBrightness - _localBrightness).abs() < 0.01) return;
    
    setState(() => _localBrightness = newBrightness);
    widget.onBrightnessChanged(newBrightness);
  }

  void _onCombinedScaleEnd(ScaleEndDetails details) {
    if (_isMultiFingerGesture) {
      // Handle zoom end logic if needed (e.g. snap back)
      // For now, we just reset flags. Parent handles snap back logic?
      // Actually parent has logic to reset if scale is near 1.0.
      // We might need to duplicate that or just let parent handle it via onZoomChanged.
      _showZoomIndicatorWithTimer();
    }
    
    setState(() {
      _isMultiFingerGesture = false;
      _isSingleFingerSwipe = false;
      _swipeStartPosition = null;
      _isVolumeAdjusting = false;
      _isBrightnessAdjusting = false;
    });
  }

  void _showZoomIndicatorWithTimer() {
    _zoomIndicatorTimer?.cancel();
    if (!_showZoomIndicator) setState(() => _showZoomIndicator = true);
    _zoomIndicatorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showZoomIndicator = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onScaleStart: _onCombinedScaleStart,
          onScaleUpdate: _onCombinedScaleUpdate,
          onScaleEnd: _onCombinedScaleEnd,
          behavior: HitTestBehavior.translucent, // Allow touches to pass if needed, but we want to capture them
          child: widget.child,
        ),
        
        if (_isVolumeAdjusting) _buildVolumeIndicator(),
        if (_isBrightnessAdjusting) _buildBrightnessIndicator(),
        if (_showZoomIndicator) _buildZoomIndicator(),
      ],
    );
  }

  Widget _buildVolumeIndicator() {
    return Positioned(
      right: MediaQuery.of(context).size.width * 0.25 - 40,
      top: MediaQuery.of(context).size.height * 0.5 - 50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getVolumeIcon(_localVolume),
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              '${(_localVolume * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _localVolume,
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
    );
  }

  Widget _buildBrightnessIndicator() {
    return Positioned(
      left: MediaQuery.of(context).size.width * 0.25 - 40,
      top: MediaQuery.of(context).size.height * 0.5 - 50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBrightnessIcon(_localBrightness),
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              '${(_localBrightness * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _localBrightness,
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
    );
  }

  Widget _buildZoomIndicator() {
    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(widget.currentScale * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0.0) {
      return Icons.volume_off;
    } else if (volume < 0.3) {
      return Icons.volume_down;
    } else if (volume < 0.7) {
      return Icons.volume_up;
    } else {
      return Icons.volume_up;
    }
  }

  IconData _getBrightnessIcon(double brightness) {
    if (brightness < 0.3) {
      return Icons.brightness_low;
    } else if (brightness < 0.7) {
      return Icons.brightness_medium;
    } else {
      return Icons.brightness_high;
    }
  }
}
