import 'package:flutter/services.dart';

class HapticFeedbackHelper {
  /// Light haptic feedback for subtle interactions
  static void lightImpact() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }

  /// Medium haptic feedback for standard interactions
  static void mediumImpact() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }

  /// Heavy haptic feedback for important interactions
  static void heavyImpact() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }

  /// Selection feedback for picker/selector interactions
  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }

  /// Success feedback for positive actions
  static void success() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }

  /// Warning feedback for cautionary actions
  static void warning() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }

  /// Error feedback for negative actions
  static void error() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
    }
  }
}