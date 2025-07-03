import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class PermissionRequestWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const PermissionRequestWidget({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppConstants.largePadding),
            
            Text(
              'Storage Permission Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppConstants.defaultPadding),
            
            Text(
              'KJ Video Player needs access to your device storage to find and play video files.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppConstants.largePadding),
            
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.largePadding,
                  vertical: AppConstants.defaultPadding,
                ),
              ),
            ),
            
            const SizedBox(height: AppConstants.defaultPadding),
            
            TextButton(
              onPressed: () {
                // Show permission help dialog
                _showPermissionHelpDialog(context);
              },
              child: const Text('Why do we need this permission?'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission'),
        content: const Text(
          'This permission allows the app to:\n\n'
          '• Find video files on your device\n'
          '• Create thumbnails for videos\n'
          '• Remember your playback progress\n'
          '• Organize videos by folders\n\n'
          'Your privacy is important to us. We only access video files and do not collect any personal data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}