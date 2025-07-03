import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/utils/haptic_feedback_helper.dart';

class IOSActionSheet {
  static void show({
    required BuildContext context,
    required String title,
    String? message,
    required List<IOSActionSheetAction> actions,
    IOSActionSheetAction? cancelAction,
  }) {
    HapticFeedbackHelper.lightImpact();
    
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E93),
          ),
        ),
        message: message != null
            ? Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8E8E93),
                ),
              )
            : null,
        actions: actions.map((action) => CupertinoActionSheetAction(
          onPressed: () {
            if (action.isDestructive) {
              HapticFeedbackHelper.warning();
            } else {
              HapticFeedbackHelper.lightImpact();
            }
            Navigator.pop(context);
            action.onPressed();
          },
          isDestructiveAction: action.isDestructive,
          child: Text(
            action.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: action.isDestructive 
                  ? CupertinoColors.destructiveRed 
                  : const Color(0xFF007AFF),
            ),
          ),
        )).toList(),
        cancelButton: cancelAction != null
            ? CupertinoActionSheetAction(
                onPressed: () {
                  HapticFeedbackHelper.lightImpact();
                  Navigator.pop(context);
                  if (cancelAction.onPressed != null) {
                    cancelAction.onPressed!();
                  }
                },
                child: Text(
                  cancelAction.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              )
            : CupertinoActionSheetAction(
                onPressed: () {
                  HapticFeedbackHelper.lightImpact();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
      ),
    );
  }
}

class IOSActionSheetAction {
  final String title;
  final VoidCallback onPressed;
  final bool isDestructive;

  const IOSActionSheetAction({
    required this.title,
    required this.onPressed,
    this.isDestructive = false,
  });
}

// Cancel action with optional callback
class IOSActionSheetCancelAction extends IOSActionSheetAction {
  const IOSActionSheetCancelAction({
    String title = 'Cancel',
    VoidCallback? onPressed,
  }) : super(
          title: title,
          onPressed: onPressed ?? _defaultCancel,
        );

  static void _defaultCancel() {}
}