import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/utils/haptic_feedback_helper.dart';

class IOSContextMenu extends StatelessWidget {
  final Widget child;
  final List<IOSContextMenuAction> actions;
  final VoidCallback? onTap;

  const IOSContextMenu({
    super.key,
    required this.child,
    required this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        HapticFeedbackHelper.mediumImpact();
        _showContextMenu(context);
      },
      child: child,
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy + size.height + 200,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      elevation: 8,
      items: actions.map((action) => PopupMenuItem<void>(
        onTap: () {
          // Delay to allow menu to close
          Future.delayed(const Duration(milliseconds: 100), () {
            if (action.isDestructive) {
              HapticFeedbackHelper.warning();
            } else {
              HapticFeedbackHelper.lightImpact();
            }
            action.onPressed();
          });
        },
        child: Row(
          children: [
            Icon(
              action.icon,
              size: 20,
              color: action.isDestructive 
                  ? Colors.red 
                  : const Color(0xFF007AFF),
            ),
            const SizedBox(width: 12),
            Text(
              action.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: action.isDestructive 
                    ? Colors.red 
                    : const Color(0xFF000000),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class IOSContextMenuAction {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  const IOSContextMenuAction({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });
}