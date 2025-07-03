import 'package:flutter/material.dart';
import '../../data/models/video_model.dart';
import '../../core/constants/app_constants.dart';

class ErrorVideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final String? errorMessage;

  const ErrorVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConstants.borderRadius),
                  ),
                  color: Colors.red.withValues(alpha: 0.1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getErrorIcon(),
                      size: 32,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getErrorText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            // Video Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Name
                    Text(
                      video.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.red[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const Spacer(),
                    
                    // Error info
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 12,
                          color: Colors.red[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            errorMessage ?? 'File unavailable',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (errorMessage?.contains('corrupted') == true) {
      return Icons.broken_image;
    } else if (errorMessage?.contains('incomplete') == true) {
      return Icons.download;
    } else if (!video.exists) {
      return Icons.file_present;
    } else {
      return Icons.error_outline;
    }
  }

  String _getErrorText() {
    if (errorMessage?.contains('corrupted') == true) {
      return 'Corrupted\nFile';
    } else if (errorMessage?.contains('incomplete') == true) {
      return 'Incomplete\nDownload';
    } else if (!video.exists) {
      return 'File Not\nFound';
    } else {
      return 'Cannot\nPlay';
    }
  }
}