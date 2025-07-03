import 'package:flutter/material.dart';
import '../../data/models/folder_model.dart';
import '../../core/constants/app_constants.dart';
import 'folder_card.dart';

class FolderGrid extends StatelessWidget {
  final List<FolderModel> folders;
  final Function(FolderModel) onFolderTap;
  final VoidCallback? onRefresh;

  const FolderGrid({
    super.key,
    required this.folders,
    required this.onFolderTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: AppConstants.defaultPadding,
          mainAxisSpacing: AppConstants.defaultPadding,
        ),
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final folder = folders[index];
          return FolderCard(
            folder: folder,
            onTap: () => onFolderTap(folder),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Text(
            'No folders found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            'Videos will be organized into folders automatically',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}