import 'package:flutter/material.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import 'ios_context_menu.dart';
import 'ios_action_sheet.dart';

class IOSFolderCard extends StatelessWidget {
  final String folderName;
  final int videoCount;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;

  const IOSFolderCard({
    super.key,
    required this.folderName,
    required this.videoCount,
    required this.onTap,
    this.onFavorite,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return IOSContextMenu(
      onTap: () {
        HapticFeedbackHelper.lightImpact();
        onTap();
      },
      actions: [
        IOSContextMenuAction(
          title: 'Open Folder',
          icon: Icons.folder_open,
          onPressed: onTap,
        ),
        if (onFavorite != null)
          IOSContextMenuAction(
            title: 'Add to Favorites',
            icon: Icons.favorite_outline,
            onPressed: onFavorite!,
          ),
        if (onShare != null)
          IOSContextMenuAction(
            title: 'Share Folder',
            icon: Icons.share,
            onPressed: onShare!,
          ),
        IOSContextMenuAction(
          title: 'Folder Info',
          icon: Icons.info_outline,
          onPressed: () => _showFolderInfo(context),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Folder Icon and Count
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.folder,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$videoCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Folder Name
              Expanded(
                flex: 2,
                child: Text(
                  folderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF000000),
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Video Count Text
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$videoCount video${videoCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderInfo(BuildContext context) {
    IOSActionSheet.show(
      context: context,
      title: folderName,
      message: 'Folder Information',
      actions: [
        IOSActionSheetAction(
          title: 'Videos: $videoCount',
          onPressed: () {},
        ),
        IOSActionSheetAction(
          title: 'Folder Name: $folderName',
          onPressed: () {},
        ),
      ],
    );
  }
}